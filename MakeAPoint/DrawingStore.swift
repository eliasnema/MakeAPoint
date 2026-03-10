//
//  DrawingStore.swift
//  MakeAPoint
//
//  Created by Codex on 3/10/26.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class DrawingStore {
    private enum PaletteDefaultsKey {
        static let x = "palettePositionX"
        static let y = "palettePositionY"
    }

    enum DrawingTool: String, CaseIterable, Identifiable {
        case freehand
        case line
        case rectangle
        case ellipse
        case arrow

        var id: String { rawValue }

        var title: String {
            switch self {
            case .freehand: "Freehand"
            case .line: "Line"
            case .rectangle: "Rectangle"
            case .ellipse: "Ellipse"
            case .arrow: "Arrow"
            }
        }

        var systemImage: String {
            switch self {
            case .freehand: "scribble"
            case .line: "line.diagonal"
            case .rectangle: "rectangle"
            case .ellipse: "circle"
            case .arrow: "arrow.up.right"
            }
        }

        var shortcutLabel: String {
            switch self {
            case .freehand: "1"
            case .line: "2"
            case .rectangle: "3"
            case .ellipse: "4"
            case .arrow: "5"
            }
        }
    }

    enum DrawingColor: String, CaseIterable, Identifiable {
        case red
        case orange
        case yellow
        case green
        case blue
        case pink
        case white

        var id: String { rawValue }

        var title: String { rawValue.capitalized }

        var color: Color {
            switch self {
            case .red: .red
            case .orange: .orange
            case .yellow: .yellow
            case .green: .green
            case .blue: .blue
            case .pink: .pink
            case .white: .white
            }
        }
    }

    private let minimumCoalescedPointDistance: CGFloat = 3
    private let defaults: UserDefaults

    private(set) var hasDrawings = false
    private(set) var palettePosition: CGPoint?
    private(set) var selectedTool: DrawingTool = .freehand
    private(set) var selectedColor: DrawingColor = .red

    private var completedElements: [DrawingElement] = []
    private var currentElement: DrawingElement?
    private var renderedCompletedElementsByScreen: [CGRect: [RenderedDrawingElement]] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            defaults.object(forKey: PaletteDefaultsKey.x) != nil,
            defaults.object(forKey: PaletteDefaultsKey.y) != nil
        {
            palettePosition = CGPoint(
                x: defaults.double(forKey: PaletteDefaultsKey.x),
                y: defaults.double(forKey: PaletteDefaultsKey.y)
            )
        }
    }

    func clear() {
        completedElements.removeAll()
        currentElement = nil
        renderedCompletedElementsByScreen.removeAll()
        hasDrawings = false
    }

    func cancelCurrentStroke() {
        currentElement = nil
        hasDrawings = !completedElements.isEmpty
    }

    func beginStroke(at location: CGPoint, in screenFrame: CGRect) {
        let startPoint = screenFrame.globalPoint(from: location)
        currentElement = DrawingElement(
            tool: selectedTool,
            color: selectedColor,
            points: [startPoint]
        )
        hasDrawings = true
    }

    func updateStroke(at location: CGPoint, in screenFrame: CGRect) {
        let point = screenFrame.globalPoint(from: location)

        if currentElement == nil {
            currentElement = DrawingElement(
                tool: selectedTool,
                color: selectedColor,
                points: [point]
            )
        } else {
            guard var currentElement else {
                return
            }

            switch currentElement.tool {
            case .freehand:
                if currentElement.points.shouldAppend(point, minimumDistance: minimumCoalescedPointDistance) {
                    currentElement.points.append(point)
                }
            case .line, .rectangle, .ellipse, .arrow:
                if currentElement.points.count == 1 {
                    currentElement.points.append(point)
                } else {
                    currentElement.points[1] = point
                }
            }

            self.currentElement = currentElement
        }

        hasDrawings = true
    }

    func endStroke() {
        guard let currentElement, currentElement.isValid else {
            self.currentElement = nil
            return
        }

        completedElements.append(currentElement)
        let cachedScreenFrames = Array(renderedCompletedElementsByScreen.keys)
        for screenFrame in cachedScreenFrames {
            guard let renderedElement = currentElement.renderedElement(for: screenFrame) else {
                continue
            }
            renderedCompletedElementsByScreen[screenFrame, default: []].append(renderedElement)
        }
        self.currentElement = nil
        hasDrawings = !completedElements.isEmpty
    }

    func selectTool(_ tool: DrawingTool) {
        selectedTool = tool
    }

    func selectColor(_ color: DrawingColor) {
        selectedColor = color
    }

    func renderedElements(for screenFrame: CGRect) -> [RenderedDrawingElement] {
        if let renderedElements = renderedCompletedElementsByScreen[screenFrame] {
            return renderedElements
        }

        let renderedElements = completedElements.compactMap { element in
            element.renderedElement(for: screenFrame)
        }
        renderedCompletedElementsByScreen[screenFrame] = renderedElements
        return renderedElements
    }

    func currentRenderedElement(for screenFrame: CGRect) -> RenderedDrawingElement? {
        currentElement?.renderedElement(for: screenFrame)
    }

    func palettePosition(in screenFrame: CGRect, paletteSize: CGSize) -> CGPoint {
        let fallbackPosition = CGPoint(
            x: max(paletteSize.width / 2 + 24, screenFrame.width - paletteSize.width / 2 - 24),
            y: min(
                max(paletteSize.height / 2 + 24, screenFrame.height - paletteSize.height / 2 - 28),
                screenFrame.height - paletteSize.height / 2 - 24
            )
        )

        return clampedPalettePosition(palettePosition ?? fallbackPosition, in: screenFrame, paletteSize: paletteSize)
    }

    func clampedPalettePosition(for position: CGPoint, in screenFrame: CGRect, paletteSize: CGSize) -> CGPoint {
        clampedPalettePosition(position, in: screenFrame, paletteSize: paletteSize)
    }

    func updatePalettePosition(_ position: CGPoint, in screenFrame: CGRect, paletteSize: CGSize) {
        let clampedPosition = clampedPalettePosition(position, in: screenFrame, paletteSize: paletteSize)
        palettePosition = clampedPosition
        defaults.set(clampedPosition.x, forKey: PaletteDefaultsKey.x)
        defaults.set(clampedPosition.y, forKey: PaletteDefaultsKey.y)
    }

    private func clampedPalettePosition(_ position: CGPoint, in screenFrame: CGRect, paletteSize: CGSize) -> CGPoint {
        let halfWidth = paletteSize.width / 2
        let halfHeight = paletteSize.height / 2

        return CGPoint(
            x: min(max(position.x, halfWidth + 16), screenFrame.width - halfWidth - 16),
            y: min(max(position.y, halfHeight + 16), screenFrame.height - halfHeight - 16)
        )
    }
}

struct DrawingElement {
    let tool: DrawingStore.DrawingTool
    let color: DrawingStore.DrawingColor
    var points: [CGPoint]

    var isValid: Bool {
        switch tool {
        case .freehand:
            !points.isEmpty
        case .line, .rectangle, .ellipse, .arrow:
            points.count >= 2
        }
    }

    func renderedElement(for screenFrame: CGRect) -> RenderedDrawingElement? {
        let localPoints = points
            .filter { screenFrame.contains($0) }
            .map { screenFrame.localPoint(from: $0) }

        guard !localPoints.isEmpty else {
            return nil
        }

        return RenderedDrawingElement(
            tool: tool,
            color: color.color.opacity(0.95),
            points: localPoints
        )
    }
}

struct RenderedDrawingElement {
    enum Mode {
        case fill
        case stroke
    }

    static let strokeStyle = StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)

    let path: Path
    let color: Color
    let mode: Mode

    init?(tool: DrawingStore.DrawingTool, color: Color, points: [CGPoint]) {
        guard let firstPoint = points.first else {
            return nil
        }

        self.color = color

        if points.count == 1 {
            let dotRect = CGRect(x: firstPoint.x - 7, y: firstPoint.y - 7, width: 14, height: 14)
            self.path = Path(ellipseIn: dotRect)
            self.mode = .fill
            return
        }

        var path = Path()

        switch tool {
        case .freehand:
            path.move(to: firstPoint)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        case .line:
            guard let endPoint = points.last else {
                return nil
            }
            path.move(to: firstPoint)
            path.addLine(to: endPoint)
        case .rectangle:
            guard let endPoint = points.last else {
                return nil
            }
            path.addRect(CGRect(origin: firstPoint, size: .zero).standardized.union(CGRect(origin: endPoint, size: .zero)))
        case .ellipse:
            guard let endPoint = points.last else {
                return nil
            }
            path.addEllipse(in: CGRect(origin: firstPoint, size: .zero).standardized.union(CGRect(origin: endPoint, size: .zero)))
        case .arrow:
            guard let endPoint = points.last else {
                return nil
            }

            path.move(to: firstPoint)
            path.addLine(to: endPoint)

            let angle = atan2(endPoint.y - firstPoint.y, endPoint.x - firstPoint.x)
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
        }

        self.path = path
        self.mode = .stroke
    }

    func draw(in context: inout GraphicsContext) {
        switch mode {
        case .fill:
            context.fill(path, with: .color(color))
        case .stroke:
            context.stroke(path, with: .color(color), style: Self.strokeStyle)
        }
    }
}

private extension Array where Element == CGPoint {
    func shouldAppend(_ point: CGPoint, minimumDistance: CGFloat) -> Bool {
        guard let lastPoint = last else {
            return true
        }

        return lastPoint.distanceSquared(to: point) >= minimumDistance * minimumDistance
    }
}

private extension CGPoint {
    func distanceSquared(to point: CGPoint) -> CGFloat {
        let deltaX = x - point.x
        let deltaY = y - point.y
        return (deltaX * deltaX) + (deltaY * deltaY)
    }
}

extension CGRect {
    func globalPoint(from localPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: minX + localPoint.x,
            y: maxY - localPoint.y
        )
    }

    func localPoint(from globalPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: globalPoint.x - minX,
            y: maxY - globalPoint.y
        )
    }
}
