//
//  FlashcardsStudyView.swift
//  Study Appp
//
//  Created by Sreeyuth Jakka on 11/23/25.
//

internal import SwiftUI

struct FlashcardsStudyView: View {
    @EnvironmentObject var store: FlashcardStore

    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack {
                    if store.flashcards.isEmpty {
                        Spacer()
                        Text("No flashcards yet.\nGo to Upload to create some.")
                            .multilineTextAlignment(.center)
                            .font(.appBody)
                            .foregroundColor(.black.opacity(0.7))
                            .padding()
                        Spacer()
                    } else {
                        let card = store.flashcards[currentIndex]

                        Spacer()

                        FlashcardView(card: card, isFlipped: $isFlipped)

                        Spacer()

                        HStack {
                            Button("Previous") {
                                if currentIndex > 0 {
                                    currentIndex -= 1
                                    isFlipped = false
                                }
                            }
                            .disabled(currentIndex == 0)

                            Spacer()

                            Text("Card \(currentIndex + 1) of \(store.flashcards.count)")
                                .font(.appCaption)
                                .foregroundColor(.black.opacity(0.7))

                            Spacer()

                            Button("Next") {
                                if currentIndex < store.flashcards.count - 1 {
                                    currentIndex += 1
                                    isFlipped = false
                                }
                            }
                            .disabled(currentIndex == store.flashcards.count - 1)
                        }
                        .font(.appBody)
                        .foregroundColor(.black) // button labels dark
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                .foregroundColor(.black) // default text color for this screen
            }
            .navigationTitle("Flashcards")
            .preferredColorScheme(.light) // force light mode so nothing turns white
        }
        .onChange(of: store.flashcards.count) { _ in
            // Reset index if cards were cleared
            if currentIndex >= store.flashcards.count {
                currentIndex = max(0, store.flashcards.count - 1)
                isFlipped = false
            }
        }
    }
}

// MARK: - FlashcardView

struct FlashcardView: View {
    let card: Flashcard
    @Binding var isFlipped: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(isFlipped ? AppTheme.cardBack : AppTheme.cardFront)
                .shadow(color: .black.opacity(0.20), radius: 22, x: 0, y: 14)

            ZStack {
                // Front
                Text(card.question)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white) // stays white on the colorful card
                    .padding(40)
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0),
                                      axis: (x: 0, y: 1, z: 0))

                // Back
                Text(card.answer)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white) // stays white on the colorful card
                    .padding(40)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180),
                                      axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(height: 290)
        .padding(.horizontal, 24)
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                isFlipped.toggle()
            }
        }
    }
}

#Preview {
    FlashcardsStudyView()
        .environmentObject(FlashcardStore())
}
