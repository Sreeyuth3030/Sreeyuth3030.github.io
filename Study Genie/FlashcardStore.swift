//
//  FlashcardStore.swift
//  Study Appp
//
//  Created by Sreeyuth Jakka on 11/23/25.
//

import Foundation
import Combine
internal import SwiftUI

// MARK: - Card Types

enum CardType: String, Codable, CaseIterable {
    case definition
    case qa
    case fact
    case explain
}

// MARK: - Flashcard Model

struct Flashcard: Identifiable, Equatable, Codable {
    let id: UUID
    var type: CardType
    var question: String
    var answer: String
    var choices: [String]   // used for quizzes (optional)

    // ✅ Default type fixes "Missing argument for parameter 'type'"
    // ✅ Default choices fixes quiz-building calls
    init(type: CardType = .qa,
         question: String,
         answer: String,
         choices: [String] = []) {
        self.id = UUID()
        self.type = type
        self.question = question
        self.answer = answer
        self.choices = choices
    }
}

// MARK: - Store

final class FlashcardStore: ObservableObject {
    @Published var flashcards: [Flashcard] = []

    func add(_ card: Flashcard) {
        flashcards.append(card)
    }

    func add(contentsOf cards: [Flashcard]) {
        flashcards.append(contentsOf: cards)
    }

    func remove(at offsets: IndexSet) {
        flashcards.remove(atOffsets: offsets)
    }

    func removeAll() {
        flashcards.removeAll()
    }
}
