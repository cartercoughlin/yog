//
//  ContentView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var injuryViewModel = InjuryTrackerViewModel()
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .environmentObject(injuryViewModel)
                .environmentObject(themeManager)
                .tabItem {
                    Label("Recovery", systemImage: "heart.fill")
                }
                .tag(0)

            TrainingPlanView()
                .environmentObject(themeManager)
                .tabItem {
                    Label("Training", systemImage: "figure.run")
                }
                .tag(1)

            InjuryTrackerView()
                .environmentObject(injuryViewModel)
                .environmentObject(themeManager)
                .tabItem {
                    Label("Injuries", systemImage: "bandage.fill")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
