//
//  RecoveryScoreCard.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct RecoveryScoreCard: View {
    let recovery: RecoveryData
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 24) {
            // Score visualization section
            VStack(spacing: 20) {
                // Circular progress ring
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                        .frame(width: 160, height: 160)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(recovery.overallScore) / 100.0)
                        .stroke(
                            recovery.category.color.gradient,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: recovery.overallScore)

                    // Score text in center
                    VStack(spacing: 4) {
                        Text("\(recovery.overallScore)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(recovery.category.color.gradient)
                    }
                }

                Text(recovery.category.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(recovery.category.color.gradient)

                Text(recovery.category.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Score breakdown
            VStack(alignment: .leading, spacing: 16) {
                Text("Score Breakdown")
                    .font(.headline)

                ForEach(recovery.scoreBreakdown, id: \.0) { item in
                    ScoreBreakdownRow(
                        label: item.0,
                        score: item.1,
                        icon: item.2,
                        recovery: recovery,
                        theme: themeManager.currentTheme
                    )
                }
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
            )
        }
        .padding()
    }
}

struct ScoreBreakdownRow: View {
    let label: String
    let score: Double
    let icon: String
    let recovery: RecoveryData
    let theme: RecoveryTheme

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(recovery.category.color.gradient)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 100, height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(recovery.category.color)
                    .frame(width: max(0, min(100, CGFloat(score))), height: 8)
            }

            Text("\(Int(score))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

#Preview {
    RecoveryScoreCard(recovery: .sample)
}
