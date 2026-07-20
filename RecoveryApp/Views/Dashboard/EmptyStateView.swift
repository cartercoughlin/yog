//
//  EmptyStateView.swift
//  RecoveryApp
//
//  Created on 2025-12-03
//

import SwiftUI

struct HealthDataEmptyStateView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Health data unavailable")
                    .font(.headline)
                Text("Check Apple Health permissions and sync status.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
    HealthDataEmptyStateView()
}
