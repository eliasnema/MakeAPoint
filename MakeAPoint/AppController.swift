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
    let shortcutDescription = "Shift-Command-D"
    let drawingStore = DrawingStore()

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
        drawingStore.clear()
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
        drawingStore.cancelCurrentStroke()
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

        guard let index = key.wholeNumberValue, (1...DrawingStore.DrawingTool.allCases.count).contains(index) else {
            return false
        }

        drawingStore.selectTool(DrawingStore.DrawingTool.allCases[index - 1])
        return true
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
                    .environment(appController.drawingStore)
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
