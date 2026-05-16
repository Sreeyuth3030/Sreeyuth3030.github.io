//
//  Theme.swift
//  Study Appp
//
//  Created by Sreeyuth Jakka on 11/23/25.
//

internal import SwiftUI

enum AppTheme {
    // Light blue background used across the app
    static let background = Color(red: 0.90, green: 0.95, blue: 1.0)

    // Accent color (buttons, icons, etc.)
    static let accent = Color(.systemBlue)

    // Flashcard gradients
    static let cardFront = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.55, blue: 1.0),
            Color(red: 0.10, green: 0.70, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBack = LinearGradient(
        colors: [
            Color(red: 0.70, green: 0.30, blue: 0.90),
            Color(red: 0.90, green: 0.40, blue: 0.70)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Fonts

extension Font {
    static var appTitle: Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }

    static var appSection: Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }

    static var appBody: Font {
        .system(size: 16, weight: .regular, design: .rounded)
    }

    static var appCaption: Font {
        .system(size: 13, weight: .regular, design: .rounded)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBody)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.accent)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
