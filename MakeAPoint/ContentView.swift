//
//  ContentView.swift
//  MakeAPoint
//
//  Created by ls nm on 3/9/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(AppController.self) private var appController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                appController.isDrawingEnabled ? "Drawing mode is active" : "Ready to draw on screen",
                systemImage: appController.isDrawingEnabled ? "pencil.tip.crop.circle.badge.plus" : "cursorarrow"
            )
            .font(.headline)

            Text("Use \(appController.shortcutDescription) to toggle a full-screen annotation layer while you present.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(appController.isDrawingEnabled ? "Stop Drawing" : "Start Drawing") {
                appController.toggleDrawingMode()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Clear Current Markup") {
                appController.clearDrawings()
            }
            .disabled(!appController.hasDrawings)

            Divider()

            Button("Quit Make a Point") {
                NSApp.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

#Preview {
    ContentView()
        .environment(AppController.shared)
}
