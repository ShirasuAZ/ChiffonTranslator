//
//  ChiffonTranslatorApp.swift
//  ChiffonTranslator
//
//  Created by chiffon on 2026/1/4.
//

import SwiftUI

@main
struct ChiffonTranslatorApp: App {
    var body: some Scene {
        // Main Control Center Window
        WindowGroup {
            ControlCenterView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Add custom commands if needed
        }
    }
}
