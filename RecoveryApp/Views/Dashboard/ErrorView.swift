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
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            VStack(spacing: 12) {
                Text("Unable to Load Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
}

#Preview {
    HealthDataErrorView(message: "Failed to load health data. Please check your HealthKit permissions.") {
        // Preview action
    }
}