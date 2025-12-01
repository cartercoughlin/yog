//
//  View+Gradient.swift
//  RecoveryApp
//
//  Created on 2025-12-01
//

import SwiftUI

extension View {
    /// Applies a subtle card background
    func subtleCard(theme: RecoveryTheme) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    /// Applies a clean background
    func cleanBackground() -> some View {
        self.background(
            Color(.systemBackground)
                .ignoresSafeArea()
        )
    }
}
