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
    @Environment(DrawingStore.self) private var drawingStore

    private let colorColumns = Array(repeating: GridItem(.fixed(24), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Button(appController.isDrawingEnabled ? "Stop Session" : "Start Session") {
                appController.toggleDrawingMode()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 10) {
                toolMenu
                colorPicker
            }

            HStack(spacing: 8) {
                actionButton("Export", systemImage: "square.and.arrow.down") {
                    appController.exportPicture()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!drawingStore.hasDrawings || !appController.hasExportFolder)

                actionButton("Clear", systemImage: "trash") {
                    appController.clearDrawings()
                }
                .disabled(!drawingStore.hasDrawings)
            }

            exportFooter

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(width: 236)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Make a Point")
                    .font(.headline)
                Spacer()
                Text(appController.shortcutDescription)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(appController.isDrawingEnabled ? "Live on screen" : "Ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var toolMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tool")
                .font(.caption)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(DrawingStore.DrawingTool.allCases) { tool in
                    Button {
                        drawingStore.selectTool(tool)
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: drawingStore.selectedTool.systemImage)
                    Text(drawingStore.selectedTool.shortcutLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Color")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: colorColumns, alignment: .leading, spacing: 8) {
                ForEach(DrawingStore.DrawingColor.allCases) { color in
                    Button {
                        drawingStore.selectColor(color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle()
                                    .strokeBorder(.white.opacity(0.8), lineWidth: 1)
                            }
                            .overlay {
                                if color == drawingStore.selectedColor {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(color.color.accessibleSelectionForeground)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(color.title)
                }
            }
        }
    }

    private var exportFooter: some View {
        HStack(spacing: 8) {
            Button(appController.hasExportFolder ? "Folder" : "Set Folder") {
                appController.chooseExportFolder()
            }

            if appController.hasExportFolder {
                Button {
                    appController.clearExportFolder()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Clear export folder")
            }

            Spacer()

            Text(appController.hasExportFolder ? "Saved" : "No folder")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppController.shared)
        .environment(AppController.shared.drawingStore)
}
