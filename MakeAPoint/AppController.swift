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

    private(set) var isDrawingEnabled = false
    private(set) var hasDrawings = false

    let shortcutDescription = "Shift-Command-D"

    private var completedStrokes: [Stroke] = []
    private var currentStroke: Stroke?
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
        completedStrokes.removeAll()
        currentStroke = nil
        hasDrawings = false
    }

    func beginStroke(at location: CGPoint, in screenFrame: CGRect) {
        currentStroke = Stroke(points: [screenFrame.globalPoint(from: location)])
        hasDrawings = true
    }

    func updateStroke(at location: CGPoint, in screenFrame: CGRect) {
        let point = screenFrame.globalPoint(from: location)

        if currentStroke == nil {
            currentStroke = Stroke(points: [point])
        } else {
            currentStroke?.points.append(point)
        }

        hasDrawings = true
    }

    func endStroke() {
        guard let currentStroke else {
            return
        }

        completedStrokes.append(currentStroke)
        self.currentStroke = nil
        hasDrawings = !completedStrokes.isEmpty
    }

    func strokePoints(for screenFrame: CGRect) -> [[CGPoint]] {
        completedStrokes.compactMap { stroke in
            stroke.localPoints(for: screenFrame)
        }
    }

    func currentStrokePoints(for screenFrame: CGRect) -> [CGPoint]? {
        currentStroke?.localPoints(for: screenFrame)
    }

    private func enableDrawingMode() {
        clearKeyMonitor()
        overlayController = OverlayWindowController(appController: self)
        overlayController?.show()
        installEscapeMonitor()
        isDrawingEnabled = true
        NSApp.activate(ignoringOtherApps: true)
    }

    private func disableDrawingMode() {
        clearKeyMonitor()
        overlayController?.hide()
        overlayController = nil
        currentStroke = nil
        isDrawingEnabled = false
        NSCursor.arrow.set()
    }

    private func installEscapeMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else {
                return event
            }

            self?.toggleDrawingMode()
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
}

private struct Stroke {
    var points: [CGPoint]

    func localPoints(for screenFrame: CGRect) -> [CGPoint]? {
        let localPoints = points
            .filter { screenFrame.contains($0) }
            .map { screenFrame.localPoint(from: $0) }

        guard !localPoints.isEmpty else {
            return nil
        }

        return localPoints
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

        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(contentRect: screen.frame, screen: screen)
            window.contentView = NSHostingView(
                rootView: DrawingOverlayView(screenFrame: screen.frame)
                    .environment(appController)
            )
            window.makeKeyAndOrderFront(nil)
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
        level = .screenSaver
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
