//
//  ErrorView.swift
//  RecoveryApp
//
//  Created on 2025-12-03
//

import SwiftUI

struct HealthDataErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Health data unavailable")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Retry") {
                onRetry()
            }
            .font(.subheadline)
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}

#Preview {
    HealthDataErrorView(message: "Failed to load health data. Please check your HealthKit permissions.") {
        // Preview action
    }
}
