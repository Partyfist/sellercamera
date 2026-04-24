//
//  SellerCameraApp.swift
//  SellerCamera
//
//  Created by Sungning on 2026/3/29.
//

import SwiftUI

@main
struct SellerCameraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    WhiteBackgroundBaselineAutorun.triggerIfNeeded()
                }
        }
    }
}
