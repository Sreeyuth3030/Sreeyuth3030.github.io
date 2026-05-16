const { app, BrowserWindow, session } = require("electron");
const path = require("path");

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    frame: false,
    transparent: false,
    alwaysOnTop: false,
    resizable: true,
    backgroundColor: "#090612",
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      media: true
    }
  });

  win.center();
  win.loadFile(path.join(__dirname, "index.html"));

  win.webContents.on("before-input-event", (event, input) => {
    if (input.key === "Escape") {
      win.close();
    }
  });
}

app.whenReady().then(() => {
  session.defaultSession.setPermissionRequestHandler((webContents, permission, callback) => {
    console.log("Permission requested:", permission);

    if (
      permission === "media" ||
      permission === "camera" ||
      permission === "microphone" ||
      permission === "display-capture"
    ) {
      callback(true);
    } else {
      callback(false);
    }
  });

  createWindow();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});