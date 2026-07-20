//
//  ContentView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showPlanBuilder = false
    @StateObject private var injuryViewModel = InjuryTrackerViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var trainingPlanViewModel = TrainingPlanViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView {
                selectedTab = 1
                showPlanBuilder = true
            }
                .environmentObject(injuryViewModel)
                .environmentObject(themeManager)
                .environmentObject(trainingPlanViewModel)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            TrainingPlanView(showSetup: $showPlanBuilder)
                .environmentObject(themeManager)
                .environmentObject(trainingPlanViewModel)
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
