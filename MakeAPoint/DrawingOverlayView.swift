//
//  DrawingOverlayView.swift
//  MakeAPoint
//
//  Created by Codex on 3/9/26.
//

import SwiftUI

struct DrawingOverlayView: View {
    @Environment(DrawingStore.self) private var drawingStore
    @State private var paletteDragTranslation: CGSize = .zero

    private let paletteSize = CGSize(width: 248, height: 128)

    let screenFrame: CGRect
    let showsFloatingPalette: Bool

    var body: some View {
        let completedElements = drawingStore.renderedElements(for: screenFrame)
        let currentElement = drawingStore.currentRenderedElement(for: screenFrame)

        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.black.opacity(0.001))

                Canvas { context, _ in
                    for element in completedElements {
                        element.draw(in: &context)
                    }

                    if let currentElement {
                        currentElement.draw(in: &context)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)

            if showsFloatingPalette {
                FloatingPaletteView(
                    onDragChanged: handlePaletteDragChanged,
                    onDragEnded: handlePaletteDragEnded
                )
                    .offset(x: displayedPaletteOrigin.x, y: displayedPaletteOrigin.y)
            }
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .top) {
            HStack {
                instructionPanel
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    private var instructionPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Make a Point")
                .font(.headline)
            Text("\(drawingStore.selectedTool.title) in \(drawingStore.selectedColor.title). 1-5 switch tools, Cmd+Shift+C clears, Esc exits.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if value.translation == .zero {
                    drawingStore.beginStroke(at: value.location, in: screenFrame)
                } else {
                    drawingStore.updateStroke(at: value.location, in: screenFrame)
                }
            }
            .onEnded { _ in
                drawingStore.endStroke()
            }
    }

    private var displayedPalettePosition: CGPoint {
        let storedPosition = drawingStore.palettePosition(in: screenFrame, paletteSize: paletteSize)
        let translatedPosition = CGPoint(
            x: storedPosition.x + paletteDragTranslation.width,
            y: storedPosition.y + paletteDragTranslation.height
        )
        return drawingStore.clampedPalettePosition(for: translatedPosition, in: screenFrame, paletteSize: paletteSize)
    }

    private var displayedPaletteOrigin: CGPoint {
        CGPoint(
            x: displayedPalettePosition.x - (paletteSize.width / 2),
            y: displayedPalettePosition.y - (paletteSize.height / 2)
        )
    }

    private func handlePaletteDragChanged(_ translation: CGSize) {
        paletteDragTranslation = translation
    }

    private func handlePaletteDragEnded(_ translation: CGSize) {
        paletteDragTranslation = translation
        drawingStore.updatePalettePosition(displayedPalettePosition, in: screenFrame, paletteSize: paletteSize)
        paletteDragTranslation = .zero
    }
}
