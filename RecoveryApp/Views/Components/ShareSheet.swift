import SwiftUI
import UIKit

/// Wraps UIActivityViewController so SwiftUI views can present the system
/// share sheet for exported files (CSV, PDF, etc).
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so a generated export file can drive a `.sheet(item:)` presentation.
struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}
