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
        VStack(spacing: 20) {
            // Plant visualization section
            VStack(spacing: 12) {
                PlantVisualization(
                    score: recovery.overallScore,
                    theme: themeManager.currentTheme
                )

                Text("\(recovery.overallScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(recovery.category.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(PlantStage.from(score: recovery.overallScore).description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 30)

            Divider()

            // Score breakdown with glass effect background
            VStack(spacing: 12) {
                Text("Score Breakdown")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(recovery.scoreBreakdown, id: \.0) { item in
                    ScoreBreakdownRow(
                        label: item.0,
                        score: item.1,
                        icon: item.2,
                        theme: themeManager.currentTheme
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(
            ZStack {
                // Main card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))

                // Subtle accent gradient overlay at top
                VStack {
                    themeManager.currentTheme.headerGradient
                        .frame(height: 200)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding()
    }
}

struct ScoreBreakdownRow: View {
    let label: String
    let score: Double
    let icon: String
    let theme: RecoveryTheme

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(theme.accentGradient)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 100, height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.accentGradient)
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
