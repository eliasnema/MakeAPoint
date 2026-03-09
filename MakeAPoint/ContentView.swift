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

    private let colorColumns = Array(repeating: GridItem(.fixed(24), spacing: 8), count: 4)

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

            VStack(alignment: .leading, spacing: 8) {
                Text("Tool")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Menu {
                    ForEach(AppController.DrawingTool.allCases) { tool in
                        Button {
                            appController.selectTool(tool)
                        } label: {
                            Label(tool.title, systemImage: tool.systemImage)
                        }
                    }
                } label: {
                    HStack {
                        Label(appController.selectedTool.title, systemImage: appController.selectedTool.systemImage)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: colorColumns, alignment: .leading, spacing: 8) {
                    ForEach(AppController.DrawingColor.allCases) { color in
                        Button {
                            appController.selectColor(color)
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white.opacity(color == .white ? 0.4 : 0.8), lineWidth: 1)
                                }
                                .overlay {
                                    if color == appController.selectedColor {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(color == .yellow || color == .white ? .black : .white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(color.title)
                    }
                }
            }

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
