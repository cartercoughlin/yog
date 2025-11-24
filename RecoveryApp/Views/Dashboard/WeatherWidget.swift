//
//  WeatherWidget.swift
//  RecoveryApp
//
//  Created on 2025-11-24
//

import SwiftUI

struct WeatherWidget: View {
    @StateObject private var weatherService = WeatherService()
    @State private var showingPermissionAlert = false

    var body: some View {
        HStack(spacing: 5) {
            if weatherService.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let weather = weatherService.currentWeather {
                Image(systemName: weather.condition.icon)
                    .font(.callout)
                    .foregroundStyle(.blue)

                Text("\(Int(weather.temperature))°")
                    .font(.callout)
                    .fontWeight(.semibold)
            } else if let error = weatherService.errorMessage {
                Button {
                    if error.contains("permission") {
                        showingPermissionAlert = true
                    } else {
                        weatherService.fetchWeather()
                    }
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "cloud.fill")
                    .font(.callout)
                    .foregroundStyle(.gray)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            weatherService.fetchWeather()
        }
        .alert("Location Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable location access in Settings to see local weather.")
        }
    }
}

#Preview {
    WeatherWidget()
}
