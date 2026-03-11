//
//  FloatingPaletteView.swift
//  MakeAPoint
//
//  Created by Codex on 3/9/26.
//

import AppKit
import SwiftUI

struct FloatingPaletteView: View {
    @Environment(AppController.self) private var appController
    @Environment(DrawingStore.self) private var drawingStore

    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    private let colorColumns = Array(repeating: GridItem(.flexible(minimum: 30, maximum: 40), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbar
            toolGrid
            colorGrid
        }
        .padding(12)
        .frame(width: 232)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.11, blue: 0.18),
                            Color(red: 0.16, green: 0.08, blue: 0.18),
                            Color(red: 0.08, green: 0.14, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.78))
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 92, height: 92)
                        .blur(radius: 24)
                        .offset(x: 26, y: -16)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 10)
    }

    private var toolColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0, maximum: 60), spacing: 8), count: 3)
    }

    private var selectedToolTint: Color {
        drawingStore.selectedTool == .objectEraser ? .white : drawingStore.selectedColor.color
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: drawingStore.selectedTool.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedToolTint)
                Text(drawingStore.selectedTool.shortcutLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Text(drawingStore.selectedTool.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            paletteButton(systemImage: "square.and.arrow.down", help: "Export picture") {
                appController.exportPicture()
            }
            .disabled(!drawingStore.hasDrawings || !appController.hasExportFolder)
            paletteButton(systemImage: "trash", help: "Clear drawings") {
                appController.clearDrawings()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(PalettePanGesture(onChanged: onDragChanged, onEnded: onDragEnded))
    }

    private var toolGrid: some View {
        LazyVGrid(columns: toolColumns, alignment: .leading, spacing: 8) {
            ForEach(DrawingStore.DrawingTool.allCases) { tool in
                Button {
                    drawingStore.selectTool(tool)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(tool.shortcutLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .foregroundStyle(drawingStore.selectedTool == tool ? .black : .white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.vertical, 8)
                    .background(
                        drawingStore.selectedTool == tool ? toolBackground(for: tool) : AnyShapeStyle(.white.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .help("\(tool.title) (\(tool.shortcutLabel))")
            }
        }
    }

    private func toolBackground(for tool: DrawingStore.DrawingTool) -> AnyShapeStyle {
        if tool == .objectEraser {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.white.opacity(0.98), .white.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [drawingStore.selectedColor.color.opacity(0.98), .white.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var colorGrid: some View {
        LazyVGrid(columns: colorColumns, alignment: .leading, spacing: 8) {
            ForEach(DrawingStore.DrawingColor.allCases) { color in
                Button {
                    drawingStore.selectColor(color)
                } label: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.color.gradient)
                        .frame(height: 30)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(drawingStore.selectedColor == color ? 0.9 : 0.18), lineWidth: drawingStore.selectedColor == color ? 2 : 1)
                        }
                        .overlay {
                            if drawingStore.selectedColor == color {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(color.color.accessibleSelectionForeground)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(color.title)
            }
        }
        .padding(10)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func paletteButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    FloatingPaletteView(onDragChanged: { _ in }, onDragEnded: { _ in })
        .environment(AppController.shared)
        .environment(AppController.shared.drawingStore)
}

private struct PalettePanGesture: NSGestureRecognizerRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void

    func makeNSGestureRecognizer(context: Context) -> NSPanGestureRecognizer {
        let recognizer = NSPanGestureRecognizer()
        recognizer.delaysPrimaryMouseButtonEvents = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func updateNSGestureRecognizer(_ recognizer: NSPanGestureRecognizer, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func handleNSGestureRecognizerAction(_ recognizer: NSPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view)
        let offset = CGSize(width: translation.x, height: translation.y)

        switch recognizer.state {
        case .began, .changed:
            context.coordinator.onChanged(offset)
        case .ended, .cancelled, .failed:
            context.coordinator.onEnded(offset)
            recognizer.setTranslation(.zero, in: recognizer.view)
        default:
            break
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var onChanged: (CGSize) -> Void = { _ in }
        var onEnded: (CGSize) -> Void = { _ in }

        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith eventGestureRecognizer: NSGestureRecognizer) -> Bool {
            false
        }
    }
}
