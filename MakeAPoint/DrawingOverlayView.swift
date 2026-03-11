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
    @State private var sparkles: [Sparkle] = []
    @State private var lastDragSample: DragSample?

    private let paletteSize = CGSize(width: 232, height: 148)

    let screenFrame: CGRect
    let showsFloatingPalette: Bool

    var body: some View {
        let completedElements = drawingStore.renderedElements(for: screenFrame)
        let currentElement = drawingStore.currentRenderedElement(for: screenFrame)

        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.black.opacity(0.001))

                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, _ in
                        let now = timeline.date.timeIntervalSinceReferenceDate

                        for element in completedElements {
                            element.draw(in: &context)
                        }

                        if let currentElement {
                            currentElement.draw(in: &context)
                        }

                        drawSparkles(in: &context, now: now)
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
            Text("\(drawingStore.selectedTool.title) selected. 1-6 switch tools, Cmd+Shift+C clears, Cmd+Shift+E exports, Esc exits.")
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
                emitSparklesIfNeeded(for: value)
                if value.translation == .zero {
                    drawingStore.beginStroke(at: value.location, in: screenFrame)
                } else {
                    drawingStore.updateStroke(at: value.location, in: screenFrame)
                }
            }
            .onEnded { _ in
                drawingStore.endStroke()
                lastDragSample = nil
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

    private func emitSparklesIfNeeded(for value: DragGesture.Value) {
        let now = value.time.timeIntervalSinceReferenceDate
        sparkles.removeAll { $0.isExpired(at: now) }

        let currentSample = DragSample(location: value.location, timestamp: now)
        defer { lastDragSample = currentSample }

        guard drawingStore.selectedTool != .objectEraser else {
            return
        }

        guard let lastDragSample else {
            return
        }

        let deltaTime = currentSample.timestamp - lastDragSample.timestamp
        guard deltaTime > 0 else {
            return
        }

        let distance = currentSample.location.distance(to: lastDragSample.location)
        let speed = distance / CGFloat(deltaTime)
        guard speed > 1400 else {
            return
        }

        let sparkleColor = drawingStore.sparkleColor(for: drawingStore.selectedTool, using: drawingStore.selectedColor)
        let intensity = min(max((speed - 1400) / 1200, 0.3), 1)
        let sparkleCount = Int(3 + round(intensity * 3))

        for index in 0..<sparkleCount {
            let progress = CGFloat(index + 1) / CGFloat(sparkleCount + 1)
            let anchor = CGPoint(
                x: lastDragSample.location.x + (currentSample.location.x - lastDragSample.location.x) * progress,
                y: lastDragSample.location.y + (currentSample.location.y - lastDragSample.location.y) * progress
            )
            sparkles.append(Sparkle(
                point: anchor.jittered(maxOffset: 12),
                bornAt: now,
                lifetime: 0.34 + (Double(index) * 0.03),
                scale: 0.8 + intensity + CGFloat(index) * 0.08,
                color: sparkleColor
            ))
        }
    }

    private func drawSparkles(in context: inout GraphicsContext, now: TimeInterval) {
        for sparkle in sparkles {
            let progress = sparkle.progress(at: now)
            guard progress < 1 else {
                continue
            }

            let opacity = 1 - progress
            let scale = sparkle.scale * (0.65 + progress * 0.7)
            let sparklePath = sparkle.path(in: CGRect(
                x: sparkle.point.x - (16 * scale),
                y: sparkle.point.y - (16 * scale),
                width: 32 * scale,
                height: 32 * scale
            ))

            context.opacity = opacity
            context.fill(sparklePath, with: .color(sparkle.color))
            context.addFilter(.shadow(color: sparkle.color.opacity(0.45 * opacity), radius: 8 * scale, x: 0, y: 0))
            context.fill(sparklePath, with: .color(sparkle.color.opacity(0.45)))
        }
    }
}

private struct DragSample {
    let location: CGPoint
    let timestamp: TimeInterval
}

private struct Sparkle: Identifiable {
    let id = UUID()
    let point: CGPoint
    let bornAt: TimeInterval
    let lifetime: TimeInterval
    let scale: CGFloat
    let color: Color

    func isExpired(at now: TimeInterval) -> Bool {
        now - bornAt >= lifetime
    }

    func progress(at now: TimeInterval) -> CGFloat {
        CGFloat(min(max((now - bornAt) / lifetime, 0), 1))
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = rect.width / 2
        let innerRadius = outerRadius * 0.38

        for index in 0..<8 {
            let angle = (CGFloat(index) * (.pi / 4)) - (.pi / 2)
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let deltaX = x - point.x
        let deltaY = y - point.y
        return sqrt((deltaX * deltaX) + (deltaY * deltaY))
    }

    func jittered(maxOffset: CGFloat) -> CGPoint {
        CGPoint(
            x: x + CGFloat.random(in: -maxOffset...maxOffset),
            y: y + CGFloat.random(in: -maxOffset...maxOffset)
        )
    }
}
