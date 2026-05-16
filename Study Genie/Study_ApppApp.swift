//
//  Study_ApppApp.swift
//  Study Appp
//
//  Created by Sreeyuth Jakka on 10/26/25.
//

 internal import SwiftUI

@main
struct Study_ApppApp: App {
    @StateObject private var store = FlashcardStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
