from concurrent.futures import process

import pygame
import time
import asyncio
import json
import subprocess
import tempfile
import re
import urllib.parse
import base64
from datetime import datetime
from pathlib import Path

import requests
import speech_recognition as sr
import edge_tts
import pyautogui



pygame.mixer.pre_init(44100, -16, 2, 2048)
pygame.mixer.init()

STATUS_FILE = Path.home() / "jarvis_status.json"
LOG_FILE = Path.home() / "jarvis_log.json"
MEMORY_FILE = Path.home() / "jarvis_memory.json"
CAMERA_JPG_FILE = Path.home() / "jarvis_camera_snapshot.jpg"
CAMERA_META_FILE = Path.home() / "jarvis_camera_meta.json"
SCREEN_JPG_FILE = Path.home() / "jarvis_screen_snapshot.jpg"

USER_NAME = "Sreeyuth"
WAKE_PHRASES = ["hey jarvis", "jarvis"]

ANTHROPIC_API_KEY = ""
CLAUDE_MODEL = "claude-opus-4-7"

MEMORY_ENABLED = True
CONVERSATION_MEMORY = [] 
MAX_MEMORY_TURNS = 6

VOICE_CHANNEL = None

SESSION_ACTIVE = False
SESSION_TIMEOUT_SECONDS = 30
LAST_ACTIVE_TIME = 0


def set_status(state: str, text: str = ""):
    STATUS_FILE.write_text(
        json.dumps({"state": state, "text": text}),
        encoding="utf-8"
    )


def append_log(role: str, text: str):
    try:
        logs = []
        if LOG_FILE.exists():
            logs = json.loads(LOG_FILE.read_text(encoding="utf-8"))

        logs.append({
            "role": role,
            "text": text,
            "time": datetime.now().strftime("%I:%M:%S %p")
        })

        logs = logs[-12:]
        LOG_FILE.write_text(json.dumps(logs, indent=2), encoding="utf-8")
    except Exception as e:
        print("Log error:", repr(e))


def write_memory_state():
    try:
        MEMORY_FILE.write_text(
            json.dumps({"enabled": MEMORY_ENABLED}),
            encoding="utf-8"
        )
    except Exception as e:
        print("Memory file error:", repr(e))


def add_memory_turn(user_text: str, assistant_text: str):
    global CONVERSATION_MEMORY
    CONVERSATION_MEMORY.append({"role": "user", "content": user_text})
    CONVERSATION_MEMORY.append({"role": "assistant", "content": assistant_text})
    CONVERSATION_MEMORY = CONVERSATION_MEMORY[-MAX_MEMORY_TURNS * 2:]


def clear_memory():
    global CONVERSATION_MEMORY
    CONVERSATION_MEMORY = []


def build_claude_messages(prompt: str):
    messages = []
    if MEMORY_ENABLED and CONVERSATION_MEMORY:
        messages.extend(CONVERSATION_MEMORY)
    messages.append({"role": "user", "content": prompt})
    return messages


def clean_for_speech(text: str) -> str:
    if not text:
        return "I couldn't generate a response."

    text = text.replace("**", "")
    text = text.replace("*", "")
    text = text.replace("`", "")
    text = text.replace("#", "")
    text = re.sub(r"\[(.*?)\]\((.*?)\)", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip()

    if len(text) > 700:
        text = text[:700].rsplit(" ", 1)[0] + "."

    return text


async def speak(text: str):
    global VOICE_CHANNEL
    text = clean_for_speech(text)

    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
        temp_path = f.name

    communicate = edge_tts.Communicate(
        text=text,
        voice="en-GB-RyanNeural",
        rate="-8%",
        pitch="-8Hz"
    )
    await communicate.save(temp_path)

    try:
        sound = pygame.mixer.Sound(temp_path)
        VOICE_CHANNEL = pygame.mixer.Channel(1)
        VOICE_CHANNEL.play(sound)

        while VOICE_CHANNEL.get_busy():
            time.sleep(0.01)
    finally:
        try:
            Path(temp_path).unlink(missing_ok=True)
        except Exception:
            pass


def recognize_audio(recognizer, audio):
    try:
        return recognizer.recognize_google(audio)
    except sr.UnknownValueError:
        return None
    except sr.RequestError:
        return None
    except Exception:
        return None


def listen_for_wake_word():
    recognizer = sr.Recognizer()
    recognizer.energy_threshold = 160
    recognizer.dynamic_energy_threshold = True
    recognizer.pause_threshold = 0.55

    with sr.Microphone() as source:
        try:
            audio = recognizer.listen(source, timeout=1.5, phrase_time_limit=2.0)
        except sr.WaitTimeoutError:
            return False

    text = recognize_audio(recognizer, audio)
    if not text:
        return False

    heard = text.lower().strip()
    print("Wake check heard:", heard)
    return ("hey jarvis" in heard) or (heard == "jarvis")


def listen_command(timeout=10, phrase_time_limit=18):
    recognizer = sr.Recognizer()
    recognizer.energy_threshold = 130
    recognizer.dynamic_energy_threshold = True
    recognizer.pause_threshold = 1.6
    recognizer.non_speaking_duration = 0.8
    recognizer.phrase_threshold = 0.35

    with sr.Microphone() as source:
        set_status("listening", "Listening...")
        print("Listening...")
        recognizer.adjust_for_ambient_noise(source, duration=0.2)
        audio = recognizer.listen(
            source,
            timeout=timeout,
            phrase_time_limit=phrase_time_limit
        )

    return recognize_audio(recognizer, audio)


def ask_claude_text(prompt: str) -> str:
    try:
        response = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": ANTHROPIC_API_KEY,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": CLAUDE_MODEL,
                "max_tokens": 180,
                "system": (
                    "You are Jarvis, a calm futuristic desktop assistant. "
                    "Reply naturally for speech. "
                    "Be brief, smooth, and direct. "
                    "Use 1 to 3 short sentences. "
                    "Do not use markdown, bullets, or asterisks."
                ),
                "messages": build_claude_messages(prompt),
            },
            timeout=45,
        )
        response.raise_for_status()
        data = response.json()

        parts = data.get("content", [])
        text_chunks = [
            part.get("text", "")
            for part in parts
            if part.get("type") == "text"
        ]
        answer = " ".join(chunk.strip() for chunk in text_chunks if chunk.strip()).strip()
        answer = clean_for_speech(answer or "I couldn't generate a response.")

        if MEMORY_ENABLED:
            add_memory_turn(prompt, answer)

        return answer
    except Exception as e:
        print("Claude API error:", repr(e))
        return "Sorry, I couldn't reach Claude right now."


def ask_claude_vision(prompt: str, image_path: Path) -> str:
    if not image_path.exists():
        return "I don't have an image to analyze yet."

    try:
        image_b64 = base64.b64encode(image_path.read_bytes()).decode("utf-8")

        response = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": ANTHROPIC_API_KEY,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": CLAUDE_MODEL,
                "max_tokens": 220,
                "system": (
                    "You are Jarvis, a calm desktop AI assistant. "
                    "Analyze the provided image only. "
                    "Do not claim you cannot see the image if one is attached. "
                    "If the image is dark, unclear, empty, or partially visible, say that plainly. "
                    "Be direct, concise, and useful. "
                    "Do not use markdown, bullets, or asterisks."
                ),
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": image_b64
                                }
                            },
                            {
                                "type": "text",
                                "text": prompt
                            }
                        ]
                    }
                ],
            },
            timeout=60,
        )
        response.raise_for_status()
        data = response.json()

        parts = data.get("content", [])
        text_chunks = [
            part.get("text", "")
            for part in parts
            if part.get("type") == "text"
        ]
        answer = " ".join(chunk.strip() for chunk in text_chunks if chunk.strip()).strip()
        return clean_for_speech(answer or "I couldn't analyze the image.")
    except Exception as e:
        print("Claude vision error:", repr(e))
        return "Sorry, I couldn't analyze that right now."


def camera_frame_is_fresh(max_age_seconds=2.0):
    try:
        if not CAMERA_META_FILE.exists():
            return False

        meta = json.loads(CAMERA_META_FILE.read_text(encoding="utf-8"))
        updated_at = meta.get("updated_at", 0)
        age_ms = int(time.time() * 1000) - int(updated_at)
        age_seconds = age_ms / 1000.0
        print("Camera frame age:", age_seconds)
        return age_seconds <= max_age_seconds
    except Exception as e:
        print("Camera freshness check error:", repr(e))
        return False


def use_saved_camera_frame():
    if not CAMERA_JPG_FILE.exists():
        return "I don't have a live camera image yet."

    if not camera_frame_is_fresh():
        return "The live camera frame is stale. Please wait a moment and try again."

    return None


def capture_screen_frame():
    try:
        screenshot = pyautogui.screenshot()
        screenshot.save(str(SCREEN_JPG_FILE))
        if not SCREEN_JPG_FILE.exists() or SCREEN_JPG_FILE.stat().st_size == 0:
            return None, "I couldn't capture the screen."
        return SCREEN_JPG_FILE, None
    except Exception as e:
        return None, f"Screen capture error: {e}"


def open_url(url: str, spoken: str) -> str:
    subprocess.run(["cmd.exe", "/c", "start", url], check=False)
    return spoken


def handle_command(command: str):
    global MEMORY_ENABLED, SESSION_ACTIVE, LAST_ACTIVE_TIME

    original = command.strip()
    cmd = original.lower().strip()

    for phrase in WAKE_PHRASES:
        if cmd.startswith(phrase):
            cmd = cmd[len(phrase):].strip()

    if not cmd:
        return "Yes?"

    if "go to sleep" in cmd or "sleep now" in cmd:
        SESSION_ACTIVE = False
        return "Going to sleep."

    if "stay awake" in cmd or "keep listening" in cmd:
        SESSION_ACTIVE = True
        LAST_ACTIVE_TIME = time.time()
        return "I'll stay awake."

    if "turn memory on" in cmd or "enable memory" in cmd:
        MEMORY_ENABLED = True
        write_memory_state()
        return "Conversation memory is now on."

    if "turn memory off" in cmd or "disable memory" in cmd:
        MEMORY_ENABLED = False
        write_memory_state()
        return "Conversation memory is now off."

    if "clear memory" in cmd or "reset memory" in cmd:
        clear_memory()
        write_memory_state()
        return "Conversation memory cleared."

    if (
        "scan my screen" in cmd or
        "what's on my screen" in cmd or
        "what is on my screen" in cmd or
        "analyze my screen" in cmd or
        "look at my screen" in cmd
    ):
        _, error = capture_screen_frame()
        if error:
            append_log("system", error)
            return error
        return ask_claude_vision(
            "Describe exactly what is visible on this computer screen right now. Mention any visible app, windows, text, or media.",
            SCREEN_JPG_FILE
        )

    if "describe my screen" in cmd:
        _, error = capture_screen_frame()
        if error:
            append_log("system", error)
            return error
        return ask_claude_vision(
            "Describe exactly what is visible on this computer screen right now. Mention any visible app, windows, text, or media.",
            SCREEN_JPG_FILE
        )

    if (
        "what do you see" in cmd or
        "what's on camera" in cmd or
        "look at the camera" in cmd or
        "see on the camera" in cmd or
        cmd == "camera"
    ):
        error = use_saved_camera_frame()
        if error:
            append_log("system", error)
            return error
        return ask_claude_vision(
            "Describe exactly what is visible in this live camera image. Do not speculate. If a person is visible, say that clearly.",
            CAMERA_JPG_FILE
        )

    if "describe the camera" in cmd or "analyze the camera" in cmd:
        error = use_saved_camera_frame()
        if error:
            append_log("system", error)
            return error
        return ask_claude_vision(
            "Describe exactly what is visible in this live camera image. Do not speculate. If a person is visible, say that clearly.",
            CAMERA_JPG_FILE
        )

    if "do you see me" in cmd or "do you see a person" in cmd:
        error = use_saved_camera_frame()
        if error:
            append_log("system", error)
            return error
        return ask_claude_vision(
            "Answer in one short sentence whether a person is visible in this camera image.",
            CAMERA_JPG_FILE
        )

    if "open google" in cmd or "go to google" in cmd:
        return open_url("https://www.google.com", "Opening Google.")

    if "open youtube" in cmd or "go to youtube" in cmd:
        return open_url("https://www.youtube.com", "Opening YouTube.")

    if "open chatgpt" in cmd or "go to chatgpt" in cmd:
        return open_url("https://chatgpt.com", "Opening ChatGPT.")

    if "open spotify" in cmd:
        return open_url("https://open.spotify.com", "Opening Spotify.")

    if "open gmail" in cmd:
        return open_url("https://mail.google.com", "Opening Gmail.")

    if "open calendar" in cmd:
        return open_url("https://calendar.google.com", "Opening Calendar.")

    if "open github" in cmd:
        return open_url("https://github.com", "Opening GitHub.")

    if "open downloads" in cmd:
        subprocess.run(["explorer.exe", "shell:Downloads"], check=False)
        return "Opening Downloads."

    if "open documents" in cmd:
        subprocess.run(["explorer.exe", "shell:Personal"], check=False)
        return "Opening Documents."

    if "open desktop folder" in cmd:
        subprocess.run(["explorer.exe", str(Path.home() / "Desktop")], check=False)
        return "Opening Desktop."

    if "open task manager" in cmd:
        subprocess.run(["taskmgr.exe"], check=False)
        return "Opening Task Manager."

    if "open settings" in cmd:
        subprocess.run(["cmd.exe", "/c", "start", "ms-settings:"], check=False)
        return "Opening Settings."

    if "open control panel" in cmd:
        subprocess.run(["control.exe"], check=False)
        return "Opening Control Panel."

    if "open vscode" in cmd or "open vs code" in cmd or "go to vscode" in cmd:
        subprocess.run(["cmd.exe", "/c", "code"], check=False)
        return "Opening VS Code."

    if "open notepad" in cmd:
        subprocess.run(["notepad.exe"], check=False)
        return "Opening Notepad."

    if "open calculator" in cmd:
        subprocess.run(["calc.exe"], check=False)
        return "Opening Calculator."

    if "open explorer" in cmd or "open file explorer" in cmd:
        subprocess.run(["explorer.exe"], check=False)
        return "Opening File Explorer."

    if "open paint" in cmd:
        subprocess.run(["mspaint.exe"], check=False)
        return "Opening Paint."

    if "open command prompt" in cmd:
        subprocess.run(["cmd.exe"], check=False)
        return "Opening Command Prompt."

    if "open powershell" in cmd:
        subprocess.run(["powershell.exe"], check=False)
        return "Opening PowerShell."

    if "lock my computer" in cmd or "lock the computer" in cmd:
        subprocess.run(["rundll32.exe", "user32.dll,LockWorkStation"], check=False)
        return "Locking your computer."

    if "take a screenshot" in cmd:
        screenshot_path = Path.home() / "Desktop" / f"jarvis_screenshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        pyautogui.screenshot().save(str(screenshot_path))
        return "I took a screenshot and saved it to your desktop."

    if cmd.startswith("search for "):
        query = urllib.parse.quote(cmd.replace("search for ", "", 1).strip())
        return open_url(f"https://www.google.com/search?q={query}", "Searching Google.")

    if cmd.startswith("google "):
        query = urllib.parse.quote(cmd.replace("google ", "", 1).strip())
        return open_url(f"https://www.google.com/search?q={query}", "Searching Google.")

    if "search youtube for " in cmd:
        query = urllib.parse.quote(cmd.replace("search youtube for ", "", 1).strip())
        return open_url(f"https://www.youtube.com/results?search_query={query}", "Searching YouTube.")

    if "search spotify for " in cmd:
        query = urllib.parse.quote(cmd.replace("search spotify for ", "", 1).strip())
        return open_url(f"https://open.spotify.com/search/{query}", "Searching Spotify.")

    if "what time is it" in cmd or "what's the time" in cmd:
        return f"It is {datetime.now().strftime('%I:%M %p')}."

    if "what day is it" in cmd or "what's the date" in cmd:
        return datetime.now().strftime("Today is %A, %B %d.")

    if "stop" in cmd or "exit" in cmd or "quit" in cmd:
        return "__EXIT__"

    LAST_ACTIVE_TIME = time.time()
    return ask_claude_text(original)


def main():
    global SESSION_ACTIVE, LAST_ACTIVE_TIME

    subprocess.Popen(
        ["cmd", "/c", "cd /d C:\\Users\\sivan\\JarvisVoice\\overlay && npm start"],
        shell=True
    )

    time.sleep(1.0)
    write_memory_state()

    greeting = f"Hello, {USER_NAME}."
    set_status("speaking", greeting)
    append_log("assistant", greeting)
    asyncio.run(speak(greeting))
    set_status("idle", 'Say "Hey Jarvis"')

    print("Jarvis is ready.")
    print('Say "Hey Jarvis" once to activate. Then ask follow-up questions normally.')
    print('Say "go to sleep" when you want Jarvis to stop listening.')

    while True:
        try:
            if SESSION_ACTIVE:
                if time.time() - LAST_ACTIVE_TIME > SESSION_TIMEOUT_SECONDS:
                    SESSION_ACTIVE = False
                    set_status("idle", 'Say "Hey Jarvis"')
                    continue

                set_status("listening", "Listening for follow-up...")
                try:
                    command = listen_command(timeout=10, phrase_time_limit=18)
                except Exception:
                    command = None

                if not command:
                    continue

            else:
                set_status("idle", 'Say "Hey Jarvis"')
                woke = listen_for_wake_word()

                if not woke:
                    continue

                SESSION_ACTIVE = True
                LAST_ACTIVE_TIME = time.time()

                set_status("listening", "Listening...")
                print("Wake word detected.")
                command = listen_command(timeout=10, phrase_time_limit=18)

                if not command:
                    response = "I did not catch that."
                    append_log("assistant", response)
                    asyncio.run(speak(response))
                    continue

            print("You said:", command)
            append_log("user", command)
            set_status("thinking", command)

            response = handle_command(command)

            if response == "__EXIT__":
                farewell = "Goodbye."
                set_status("speaking", farewell)
                append_log("assistant", farewell)
                asyncio.run(speak(farewell))
                break

            append_log("assistant", response)
            set_status("speaking", response)
            asyncio.run(speak(response))
            set_status("idle", 'Ask another question or say "go to sleep"')
            LAST_ACTIVE_TIME = time.time()

        except KeyboardInterrupt:
            print("\nStopped.")
            break
        except Exception as e:
            print("Error:", repr(e))
            set_status("idle", 'Say "Hey Jarvis"')
            time.sleep(0.2)


if __name__ == "__main__":
    main()