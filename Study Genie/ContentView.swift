//
//  ContentView.swift
//  Study Appp
//
//  Created by Sreeyuth Jakka on 11/23/25.
//

//
//  ContentView.swift
//  Study Appp
//

internal import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            TabView {
                UploadView()
                    .tabItem {
                        Label("Upload", systemImage: "doc.text")
                    }

                FlashcardsStudyView()
                    .tabItem {
                        Label("Cards", systemImage: "rectangle.on.rectangle")
                    }

                QuizView()
                    .tabItem {
                        Label("Quiz", systemImage: "questionmark.circle")
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FlashcardStore())
}
