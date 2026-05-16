import Foundation

struct AIFlashcard: Codable {
    let question: String
    let answer: String
}

class AIGenerator {
    private let apiKey: String

    init() {
        // Load key from Secrets.plist
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["OPENAI_API_KEY"] as? String {
            self.apiKey = key
        } else {
            self.apiKey = ""
            print("❌ No API key found in Secrets.plist")
        }
    }

    // AI request
    func generateFlashcards(from text: String) async throws -> [Flashcard] {

        let prompt = """
        Create flashcards from the following text.
        Return ONLY a JSON array of objects like:
        [
          {"question": "...", "answer": "..."},
          {"question": "...", "answer": "..."}
        ]

        Text:
        \(text)
        """

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.4
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let choices = json["choices"] as! [[String: Any]]
        let content = choices.first!["message"] as! [String: Any]
        let textResponse = content["content"] as! String

        // Convert response → Flashcard[]
        let decoder = JSONDecoder()
        let cardData = textResponse.data(using: .utf8)!
        let aiCards = try decoder.decode([AIFlashcard].self, from: cardData)

        return aiCards.map { Flashcard(question: $0.question, answer: $0.answer) }
    }
}
