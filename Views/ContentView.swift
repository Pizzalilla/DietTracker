//
//  ContentView.swift
//  DietTracker
//
//  Created by Kartikay Singh on 27/8/2025.
//

import SwiftUI

/// Simple TabView that switches between the main screens.
/// Each child screen gets access to the shared AppViewModel from the environment.
struct ContentView: View {
    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        TabView {
            DailyLogView(appVM: appVM)
                .tabItem { Label("Home", systemImage: "house.fill") }

            AddFoodView(appVM: appVM)
                .tabItem { Label("Food", systemImage: "fork.knife") }

            GoalsView(appVM: appVM)
                .tabItem { Label("Goals", systemImage: "target") }
        }
    }
}
#Preview {
    ContentView()
}
