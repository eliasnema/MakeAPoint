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
    let showsFloatingPalette: Bool

    var body: some View {
        let completedElements = appController.elements(for: screenFrame)
        let currentElement = appController.currentElement(for: screenFrame)

        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.black.opacity(0.001))

                Canvas { context, _ in
                    for element in completedElements {
                        draw(element: element, in: &context)
                    }

                    if let currentElement {
                        draw(element: currentElement, in: &context)
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
            Text("\(appController.selectedTool.title) in \(appController.selectedColor.title). 1-5 switch tools, Cmd+Shift+C clears, Esc exits.")
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

    private var initialPaletteOrigin: CGPoint {
        CGPoint(
            x: max(148, screenFrame.width - 170),
            y: min(max(96, screenFrame.height - 120), screenFrame.height - 96)
        )
    }

    private func draw(element: DrawingElement, in context: inout GraphicsContext) {
        guard let firstPoint = element.points.first else {
            return
        }

        var path = Path()
        let color = element.color.color.opacity(0.95)
        let strokeStyle = StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)

        if element.points.count == 1 {
            let dotRect = CGRect(x: firstPoint.x - 7, y: firstPoint.y - 7, width: 14, height: 14)
            path.addEllipse(in: dotRect)
            context.fill(path, with: .color(color))
            return
        }

        switch element.tool {
        case .freehand:
            path.move(to: firstPoint)
            for point in element.points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(color), style: strokeStyle)
        case .line:
            guard let endPoint = element.points.last else {
                return
            }
            path.move(to: firstPoint)
            path.addLine(to: endPoint)
            context.stroke(path, with: .color(color), style: strokeStyle)
        case .rectangle:
            guard let endPoint = element.points.last else {
                return
            }
            path.addRect(CGRect(origin: firstPoint, size: .zero).standardized.union(CGRect(origin: endPoint, size: .zero)))
            context.stroke(path, with: .color(color), style: strokeStyle)
        case .ellipse:
            guard let endPoint = element.points.last else {
                return
            }
            path.addEllipse(in: CGRect(origin: firstPoint, size: .zero).standardized.union(CGRect(origin: endPoint, size: .zero)))
            context.stroke(path, with: .color(color), style: strokeStyle)
        case .arrow:
            guard let endPoint = element.points.last else {
                return
            }
            drawArrow(from: firstPoint, to: endPoint, color: color, context: &context, style: strokeStyle)
        }
    }

    private func drawArrow(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        color: Color,
        context: inout GraphicsContext,
        style: StrokeStyle
    ) {
        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength: CGFloat = 24
        let arrowSpread: CGFloat = .pi / 7
        let leftPoint = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowSpread),
            y: endPoint.y - arrowLength * sin(angle - arrowSpread)
        )
        let rightPoint = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowSpread),
            y: endPoint.y - arrowLength * sin(angle + arrowSpread)
        )

        path.move(to: endPoint)
        path.addLine(to: leftPoint)
        path.move(to: endPoint)
        path.addLine(to: rightPoint)

        context.stroke(path, with: .color(color), style: style)
    }
}
