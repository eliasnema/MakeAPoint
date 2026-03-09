//
//  MakeAPointApp.swift
//  MakeAPoint
//
//  Created by ls nm on 3/9/26.
//

import SwiftUI

@main
struct MakeAPointApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appController = AppController.shared

    var body: some Scene {
        MenuBarExtra(
            "Make a Point",
            systemImage: appController.isDrawingEnabled ? "pencil.tip.crop.circle.badge.plus" : "cursorarrow"
        ) {
            ContentView()
                .environment(appController)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppController.shared.configure()
    }
}
