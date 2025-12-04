//
//  PlantVisualization.swift
//  RecoveryApp
//
//  Created on 2025-12-01
//

import SwiftUI

struct PlantVisualization: View {
    let score: Int
    let theme: RecoveryTheme
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = -10
    @State private var opacity: Double = 0
    @State private var glowPulse: Bool = false

    var body: some View {
        ZStack {
            // Glow effect behind plant with pulsing animation
            plantStage.plantImage
                .font(.system(size: plantStage.size))
                .foregroundStyle(theme.accentGradient)
                .blur(radius: glowPulse ? 25 : 20)
                .opacity(glowPulse ? 0.6 : 0.4)
                .scaleEffect(glowPulse ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowPulse)

            // Main plant with realistic growth animation
            plantStage.plantImage
                .font(.system(size: plantStage.size))
                .foregroundStyle(theme.accentGradient)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .opacity(opacity)
        }
        .frame(height: 180)
        .accessibilityLabel("Recovery plant at \(plantStage.description). Score: \(score) out of 100")
        .onAppear {
            // Realistic growth: start small, grow upward, then settle
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.3)) {
                scale = 1.0
                rotation = 0
                opacity = 1.0
            }

            // Start glow pulse after growth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                glowPulse = true
            }
        }
        .onChange(of: score) { oldScore, newScore in
            // Animate growth/shrinkage when score changes
            let growing = newScore > oldScore

            // Quick spring back effect
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                scale = growing ? 1.1 : 0.95
                rotation = growing ? 3 : -3
            }

            // Settle back to normal
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                scale = 1.0
                rotation = 0
            }
        }
    }

    private var plantStage: PlantStage {
        PlantStage.from(score: score)
    }
}

enum PlantStage {
    case seed          // 0-15: Starting point
    case sprout        // 16-35: First growth
    case seedling      // 36-55: Small plant
    case youngPlant    // 56-75: Developing
    case matureTree    // 76-89: Strong tree
    case blooming      // 90-100: Full bloom

    static func from(score: Int) -> PlantStage {
        switch score {
        case 0...15: return .seed
        case 16...35: return .sprout
        case 36...55: return .seedling
        case 56...75: return .youngPlant
        case 76...89: return .matureTree
        default: return .blooming
        }
    }

    var plantImage: Image {
        switch self {
        case .seed:
            return Image(systemName: "circlebadge.fill")
        case .sprout:
            return Image(systemName: "leaf.fill")
        case .seedling:
            return Image(systemName: "leaf.circle.fill")
        case .youngPlant:
            return Image(systemName: "tree.fill")
        case .matureTree:
            return Image(systemName: "tree.circle.fill")
        case .blooming:
            return Image(systemName: "sparkles")
        }
    }

    var size: CGFloat {
        switch self {
        case .seed: return 40
        case .sprout: return 60
        case .seedling: return 80
        case .youngPlant: return 100
        case .matureTree: return 120
        case .blooming: return 140
        }
    }

    var description: String {
        switch self {
        case .seed: return "Resting seed, gathering energy"
        case .sprout: return "First signs of growth"
        case .seedling: return "Small but growing steady"
        case .youngPlant: return "Building strength"
        case .matureTree: return "Strong and resilient"
        case .blooming: return "Peak performance, full bloom!"
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ForEach([10, 25, 45, 65, 80, 95], id: \.self) { score in
            PlantVisualization(
                score: score,
                theme: RecoveryTheme(score: score, activityLevel: nil, timeOfDay: .init())
            )
        }
    }
    .padding()
}
