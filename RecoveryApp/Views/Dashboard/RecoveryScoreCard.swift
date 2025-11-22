//
//  RecoveryScoreCard.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct RecoveryScoreCard: View {
    let recovery: RecoveryData

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: recovery.category.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(recovery.category.color)

                Text("\(recovery.overallScore)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(recovery.category.color)

                Text(recovery.category.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(recovery.category.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 30)

            Divider()

            VStack(spacing: 12) {
                Text("Score Breakdown")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(recovery.scoreBreakdown, id: \.0) { item in
                    ScoreBreakdownRow(
                        label: item.0,
                        score: item.1,
                        icon: item.2,
                        color: recovery.category.color
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding()
    }
}

struct ScoreBreakdownRow: View {
    let label: String
    let score: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
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
