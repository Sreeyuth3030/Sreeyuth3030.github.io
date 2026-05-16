 internal import SwiftUI

struct QuizView: View {
    @EnvironmentObject var store: FlashcardStore

    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var score = 0
    @State private var finished = false

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    if store.flashcards.isEmpty {
                        Spacer()
                        Text("No quiz available.\nAdd some flashcards first.")
                            .multilineTextAlignment(.center)
                            .font(.appBody)
                            .foregroundColor(.black.opacity(0.7))
                            .padding()
                        Spacer()
                    } else if finished {
                        Spacer()
                        Text("Quiz Finished!")
                            .font(.appSection)
                            .foregroundColor(.black)

                        Text("Score: \(score) / \(store.flashcards.count)")
                            .font(.appBody)
                            .foregroundColor(.black.opacity(0.8))

                        Button("Restart Quiz") {
                            resetQuiz()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Spacer()
                    } else {
                        let card = store.flashcards[currentIndex]

                        Text(card.question)
                            .font(.appSection)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding()

                        TextField("Your answer…", text: $userAnswer)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        Button("Submit") {
                            checkAnswer()
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Text("Score: \(score)")
                            .font(.appBody)
                            .foregroundColor(.black.opacity(0.8))
                            .padding(.top)

                        Spacer()
                    }
                }
                .foregroundColor(.black) // default text color for this screen
            }
            .navigationTitle("Quiz")
            .preferredColorScheme(.light) // keep it light so text doesn't flip to white
        }
        .onChange(of: store.flashcards.count) { _ in
            resetQuiz()
        }
    }

    private func checkAnswer() {
        let correct = store.flashcards[currentIndex].answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let typed = userAnswer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !typed.isEmpty && !correct.isEmpty && typed == correct {
            score += 1
        }

        if currentIndex < store.flashcards.count - 1 {
            currentIndex += 1
            userAnswer = ""
        } else {
            finished = true
        }
    }

    private func resetQuiz() {
        currentIndex = 0
        score = 0
        userAnswer = ""
        finished = false
    }
}

#Preview {
    QuizView()
        .environmentObject(FlashcardStore())
}
