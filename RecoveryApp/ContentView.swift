//
//  ContentView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Recovery", systemImage: "heart.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            TrainingPlanView()
                .tabItem {
                    Label("Training", systemImage: "figure.run")
                }
                .tag(2)

            InjuryTrackerView()
                .tabItem {
<<<<<<< HEAD
                    Label("Injuries", systemImage: "bandage.fill")
=======
                    Label("Injuries", systemImage: "bandage")
>>>>>>> c52ee1dfa8183110fe7c1274683153a5dfa8b653
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
}
