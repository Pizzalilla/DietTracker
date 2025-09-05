//
//  DietTrackerApp.swift
//  DietTracker
//
//  Created by Kartikay Singh on 27/8/2025.
//

import SwiftUI

//App entry point
//We instaniate a single AppViewModel and inject it into the evironment
//so all screens shares the same state

@main
struct DietTrackerApp: App {
    @StateObject private var appVM = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appVM)
        }
    }
}
