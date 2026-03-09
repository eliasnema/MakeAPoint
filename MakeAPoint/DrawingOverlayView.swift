//
//  DrawingOverlayView.swift
//  MakeAPoint
//
//  Created by Codex on 3/9/26.
//

import SwiftUI

struct DrawingOverlayView: View {
    @Environment(AppController.self) private var appController

    let screenFrame: CGRect

    var body: some View {
        let completedStrokePoints = appController.strokePoints(for: screenFrame)
        let currentStrokePoints = appController.currentStrokePoints(for: screenFrame)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.black.opacity(0.001))

            Canvas { context, _ in
                for points in completedStrokePoints {
                    draw(points: points, in: &context)
                }

                if let currentPoints = currentStrokePoints {
                    draw(points: currentPoints, in: &context)
                }
            }

            instructionPanel
                .padding(24)
        }
        .ignoresSafeArea()
        .gesture(dragGesture)
    }

    private var instructionPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Make a Point")
                .font(.headline)
            Text("Drag to draw. Press Esc or \(appController.shortcutDescription) to exit.")
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
                    appController.beginStroke(at: value.location, in: screenFrame)
                } else {
                    appController.updateStroke(at: value.location, in: screenFrame)
                }
            }
            .onEnded { _ in
                appController.endStroke()
            }
    }

    private func draw(points: [CGPoint], in context: inout GraphicsContext) {
        guard let firstPoint = points.first else {
            return
        }

        var path = Path()

        if points.count == 1 {
            let dotRect = CGRect(x: firstPoint.x - 7, y: firstPoint.y - 7, width: 14, height: 14)
            path.addEllipse(in: dotRect)
            context.fill(path, with: .color(.red.opacity(0.9)))
            return
        }

        path.move(to: firstPoint)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        context.stroke(
            path,
            with: .color(.red.opacity(0.9)),
            style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
        )
    }
}
