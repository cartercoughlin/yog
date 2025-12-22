//
//  EmptyStateView.swift
//  RecoveryApp
//
//  Created on 2025-12-03
//

import SwiftUI

struct HealthDataEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                Text("No Health Data Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("To get started, make sure your health data is syncing to Apple Health.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Setup Instructions:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Sync Device to Apple Health")
                    Text("• Wear your Device during sleep")
                    Text("• Allow HealthKit permissions when prompted")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
}

#Preview {
    HealthDataEmptyStateView()
}