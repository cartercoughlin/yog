//
//  SettingsView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var healthKitManager = HealthKitManager()

    var body: some View {
        NavigationStack {
            List {
                Section("Health Data") {
                    HStack {
                        Text("HealthKit Access")
                        Spacer()
                        if healthKitManager.isAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Grant Access") {
                                Task {
                                    try? await healthKitManager.requestAuthorization()
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    // Refresh authorization status when view appears
                    healthKitManager.checkAuthorizationStatus()
                }

                Section("Baseline Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Historic Data Range")
                            .font(.subheadline)
                        Text("The app uses your last 90 days of HealthKit data to calculate personalized baselines for HRV, Resting HR, and Training Load.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com")!)
                }

                Section("Recovery Score") {
                    Text("The recovery score is calculated based on HRV, resting heart rate, sleep quality, and training load.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
