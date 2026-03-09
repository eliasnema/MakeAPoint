//
//  AppController.swift
//  MakeAPoint
//
//  Created by Codex on 3/9/26.
//

import AppKit
import Carbon
import Observation
import SwiftUI

@MainActor
@Observable
final class AppController {
    static let shared = AppController()

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

        var shortcutLabel: String {
            switch self {
            case .red: ""
            case .orange: ""
            case .yellow: ""
            case .green: ""
            case .blue: ""
            case .pink: ""
            case .white: ""
            }
        }
    }

    private(set) var isDrawingEnabled = false
    private(set) var hasDrawings = false
    private(set) var selectedTool: DrawingTool = .freehand
    private(set) var selectedColor: DrawingColor = .red

    let shortcutDescription = "Shift-Command-D"
    private let minimumCoalescedPointDistance: CGFloat = 3

    private var completedElements: [DrawingElement] = []
    private var currentElement: DrawingElement?
    private var renderedCompletedElementsByScreen: [CGRect: [RenderedDrawingElement]] = [:]
    private var overlayController: OverlayWindowController?
    private var hotKeyMonitor: HotKeyMonitor?
    private var localKeyMonitor: Any?

    private init() {}

    func configure() {
        NSApp.setActivationPolicy(.accessory)

        guard hotKeyMonitor == nil else {
            return
        }

        hotKeyMonitor = HotKeyMonitor { [weak self] in
            Task { @MainActor in
                self?.toggleDrawingMode()
            }
        }
        hotKeyMonitor?.register()
    }

    func toggleDrawingMode() {
        if isDrawingEnabled {
            disableDrawingMode()
        } else {
            enableDrawingMode()
        }
    }

    func clearDrawings() {
        completedElements.removeAll()
        currentElement = nil
        renderedCompletedElementsByScreen.removeAll()
        hasDrawings = false
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

    private func enableDrawingMode() {
        clearKeyMonitor()
        isDrawingEnabled = true
        NSApp.activate(ignoringOtherApps: true)
        overlayController = OverlayWindowController(appController: self)
        overlayController?.show()
        installEscapeMonitor()
    }

    private func disableDrawingMode() {
        clearKeyMonitor()
        overlayController?.hide()
        overlayController = nil
        currentElement = nil
        isDrawingEnabled = false
        NSCursor.arrow.set()
    }

    private func installEscapeMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            guard event.keyCode == 53 else {
                return self.handleDrawingShortcut(event) ? nil : event
            }

            self.toggleDrawingMode()
            return nil
        }
    }

    private func clearKeyMonitor() {
        guard let localKeyMonitor else {
            return
        }

        NSEvent.removeMonitor(localKeyMonitor)
        self.localKeyMonitor = nil
    }

    private func handleDrawingShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = event.charactersIgnoringModifiers?.first else {
            return false
        }

        if modifiers == [.command, .shift] {
            if key == "c" || key == "C" {
                clearDrawings()
                return true
            }
            return false
        }

        if modifiers.intersection([.command, .control, .option]).isEmpty == false {
            return false
        }

        guard modifiers.isEmpty || modifiers == [.capsLock] else {
            return false
        }

        guard let index = key.wholeNumberValue, (1...DrawingTool.allCases.count).contains(index) else {
            return false
        }

        selectTool(DrawingTool.allCases[index - 1])
        return true
    }
}

struct DrawingElement {
    let tool: AppController.DrawingTool
    let color: AppController.DrawingColor
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

    init?(tool: AppController.DrawingTool, color: Color, points: [CGPoint]) {
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

private extension CGRect {
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

private final class OverlayWindowController {
    private let appController: AppController
    private var windows: [OverlayWindow] = []

    init(appController: AppController) {
        self.appController = appController
    }

    func show() {
        hide()

        let primaryScreenFrame = NSScreen.main?.frame ?? NSScreen.screens.first?.frame

        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(contentRect: screen.frame, screen: screen)
            window.contentView = NSHostingView(
                rootView: DrawingOverlayView(
                    screenFrame: screen.frame,
                    showsFloatingPalette: primaryScreenFrame == screen.frame
                )
                    .environment(appController)
            )
            window.orderFront(nil)
            return window
        }

        NSCursor.crosshair.set()
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

private final class OverlayWindow: NSWindow {
    init(contentRect: CGRect, screen: NSScreen) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class HotKeyMonitor {
    private let callback: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    func register() {
        guard hotKeyRef == nil else {
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard
                    let userData,
                    let event
                else {
                    return noErr
                }

                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                return monitor.handle(event: event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D415054), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == OSType(0x4D415054), hotKeyID.id == 1 else {
            return noErr
        }

        callback()
        return noErr
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
