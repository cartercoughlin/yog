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
                    Label("Injuries", systemImage: "bandage.fill")
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
