//
//  AdaptiveCard.swift
//  RecoveryApp
//
//  Created on 2025-12-01
//

import SwiftUI

struct AdaptiveCard<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
    }
}
