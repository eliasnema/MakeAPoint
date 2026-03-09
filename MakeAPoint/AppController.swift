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

    private var completedElements: [DrawingElement] = []
    private var currentElement: DrawingElement?
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
            switch currentElement?.tool {
            case .freehand:
                currentElement?.points.append(point)
            case .line, .rectangle, .ellipse, .arrow:
                if currentElement?.points.count == 1 {
                    currentElement?.points.append(point)
                } else {
                    currentElement?.points[1] = point
                }
            case .none:
                break
            }
        }

        hasDrawings = true
    }

    func endStroke() {
        guard let currentElement, currentElement.isValid else {
            self.currentElement = nil
            return
        }

        completedElements.append(currentElement)
        self.currentElement = nil
        hasDrawings = !completedElements.isEmpty
    }

    func selectTool(_ tool: DrawingTool) {
        selectedTool = tool
    }

    func selectColor(_ color: DrawingColor) {
        selectedColor = color
    }

    func elements(for screenFrame: CGRect) -> [DrawingElement] {
        completedElements.compactMap { element in
            element.localElement(for: screenFrame)
        }
    }

    func currentElement(for screenFrame: CGRect) -> DrawingElement? {
        currentElement?.localElement(for: screenFrame)
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

    func localElement(for screenFrame: CGRect) -> DrawingElement? {
        let localPoints = points
            .filter { screenFrame.contains($0) }
            .map { screenFrame.localPoint(from: $0) }

        guard !localPoints.isEmpty else {
            return nil
        }

        return DrawingElement(tool: tool, color: color, points: localPoints)
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
