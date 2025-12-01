//
//  RecoveryTheme.swift
//  RecoveryApp
//
//  Created on 2025-12-01
//

import SwiftUI

/// Dynamic gradient theme based on recovery score and activity level
struct RecoveryTheme {
    let score: Int
    let activityLevel: ActivityLevel?
    let timeOfDay: TimeOfDay

    enum ActivityLevel {
        case sedentary, light, moderate, vigorous, intense

        init(from workouts: [WorkoutData]) {
            // Calculate from recent workout intensity
            // For now, default to moderate
            self = .moderate
        }
    }

    enum TimeOfDay {
        case morning, afternoon, evening, night

        init(from date: Date = Date()) {
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 5..<12: self = .morning
            case 12..<17: self = .afternoon
            case 17..<21: self = .evening
            default: self = .night
            }
        }
    }

    /// Subtle header gradient - only used in navigation/header area
    var headerGradient: LinearGradient {
        LinearGradient(
            colors: [
                gradientColors[0].opacity(0.15),
                gradientColors[1].opacity(0.08),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Accent color for highlights and important elements
    var accentColor: Color {
        gradientColors[0]
    }

    /// Card background with subtle tint
    var cardBackground: Color {
        Color(.secondarySystemBackground)
    }

    /// Translucent card background for layering
    var translucentCardBackground: some View {
        ZStack {
            Color(.secondarySystemBackground)
            gradientColors[0].opacity(0.05)
        }
    }

    /// Accent gradient for highlights
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: accentColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Core gradient calculation based on score
    private var gradientColors: [Color] {
        switch score {
        case 0..<20: // Very Low - Deep sunset tones
            return [
                Color(red: 0.40, green: 0.20, blue: 0.40), // Deep purple
                Color(red: 0.25, green: 0.15, blue: 0.35)  // Deep navy
            ]

        case 20..<40: // Low - Sunset transition
            return [
                Color(red: 0.90, green: 0.40, blue: 0.30), // Orange-red
                Color(red: 0.60, green: 0.30, blue: 0.50)  // Purple
            ]

        case 40..<60: // Moderate - Golden hour
            return [
                Color(red: 0.95, green: 0.70, blue: 0.30), // Bright gold
                Color(red: 0.95, green: 0.50, blue: 0.25)  // Orange
            ]

        case 60..<80: // Good - Sunrise warmth
            return [
                Color(red: 1.0, green: 0.85, blue: 0.40),  // Bright yellow
                Color(red: 0.95, green: 0.65, blue: 0.35)  // Gold-orange
            ]

        default: // 80-100: Peak - Dawn light
            return [
                Color(red: 1.0, green: 0.95, blue: 0.75),  // Soft cream
                Color(red: 1.0, green: 0.80, blue: 0.50)   // Peachy-pink
            ]
        }
    }

    /// Accent colors for plant and UI elements
    private var accentColors: [Color] {
        switch score {
        case 0..<40:
            return [Color(red: 0.80, green: 0.30, blue: 0.30), Color(red: 0.50, green: 0.20, blue: 0.50)]
        case 40..<60:
            return [Color(red: 0.95, green: 0.60, blue: 0.25), Color(red: 0.90, green: 0.50, blue: 0.30)]
        case 60..<80:
            return [Color(red: 1.0, green: 0.75, blue: 0.30), Color(red: 0.90, green: 0.65, blue: 0.35)]
        default:
            return [Color(red: 1.0, green: 0.85, blue: 0.50), Color(red: 0.95, green: 0.75, blue: 0.45)]
        }
    }

    /// Text color optimized for contrast
    var primaryTextColor: Color {
        score >= 70 ? .black : .white
    }

    var secondaryTextColor: Color {
        score >= 70 ? Color.black.opacity(0.6) : Color.white.opacity(0.7)
    }
}
