//
//  DrawingOverlayView.swift
//  MakeAPoint
//
//  Created by Codex on 3/9/26.
//

import SwiftUI

struct DrawingOverlayView: View {
    @Environment(AppController.self) private var appController
    @Environment(DrawingStore.self) private var drawingStore

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
                FloatingPaletteView()
                    .position(x: initialPaletteOrigin.x, y: initialPaletteOrigin.y)
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

    private var initialPaletteOrigin: CGPoint {
        CGPoint(
            x: max(148, screenFrame.width - 170),
            y: min(max(96, screenFrame.height - 120), screenFrame.height - 96)
        )
    }
}
