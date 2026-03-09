//
//  FloatingPaletteView.swift
//  MakeAPoint
//
//  Created by Codex on 3/9/26.
//

import SwiftUI

struct FloatingPaletteView: View {
    @Environment(AppController.self) private var appController

    private let colorColumns = Array(repeating: GridItem(.fixed(26), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Palette", systemImage: "paintpalette")
                    .font(.headline)
                Spacer()
                Button {
                    appController.clearDrawings()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear drawings")
            }

            toolRow
            colorGrid
        }
        .padding(14)
        .frame(width: 248)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            ForEach(AppController.DrawingTool.allCases) { tool in
                Button {
                    appController.selectTool(tool)
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(
                            appController.selectedTool == tool
                                ? AnyShapeStyle(.tint.opacity(0.95))
                                : AnyShapeStyle(.white.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .foregroundStyle(appController.selectedTool == tool ? .black : .white)
                }
                .buttonStyle(.plain)
                .help("\(tool.title) (\(tool.shortcutLabel))")
            }
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: colorColumns, alignment: .leading, spacing: 8) {
            ForEach(AppController.DrawingColor.allCases) { color in
                Button {
                    appController.selectColor(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 26, height: 26)
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(color == .white ? 0.35 : 0.8), lineWidth: 1)
                        }
                        .overlay {
                            if appController.selectedColor == color {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(color == .yellow || color == .white ? .black : .white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(color.title)
            }
        }
    }
}

#Preview {
    FloatingPaletteView()
        .environment(AppController.shared)
}
