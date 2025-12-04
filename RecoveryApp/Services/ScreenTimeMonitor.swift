import Foundation

/// Monitors and tracks screen time data
/// NOTE: In production, this requires DeviceActivity framework (iOS 15+) and proper entitlements
/// For development, this uses simulated realistic data
class ScreenTimeMonitor {

    // MARK: - Singleton

    static let shared = ScreenTimeMonitor()
    private init() {}

    // MARK: - Screen Time Fetching

    /// Fetches screen time data for a specific date
    /// - Parameter date: The date to fetch data for
    /// - Returns: Screen time data for that date, or nil if unavailable
    func fetchScreenTime(for date: Date) async throws -> ScreenTimeData? {
        // In production, this would use DeviceActivity framework:
        // 1. Request authorization with DeviceActivityCenter
        // 2. Query app usage with DeviceActivityReport
        // 3. Aggregate usage data excluding navigation/music apps

        // For development, return simulated data
        return generateSimulatedScreenTime(for: date)
    }

    /// Fetches screen time data for multiple days
    /// - Parameter days: Number of days to fetch (going backwards from today)
    /// - Returns: Array of screen time data
    func fetchHistoricalScreenTime(days: Int) async throws -> [ScreenTimeData] {
        var results: [ScreenTimeData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                continue
            }

            let startOfDay = calendar.startOfDay(for: date)
            if let screenTime = try await fetchScreenTime(for: startOfDay) {
                results.append(screenTime)
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    // MARK: - Simulated Data (for development)

    private func generateSimulatedScreenTime(for date: Date) -> ScreenTimeData {
        // Generate realistic varying screen time (2-8 hours per day)
        let baseHours = 4.5
        let variation = Double.random(in: -2.0...3.5)
        let totalHours = max(1.5, min(9.0, baseHours + variation))
        let totalSeconds = totalHours * 3600

        // Generate app usages
        let appUsages = generateSimulatedAppUsages(totalSeconds: totalSeconds)

        return ScreenTimeData(
            date: date,
            totalScreenTimeSeconds: totalSeconds,
            appUsages: appUsages
        )
    }

    private func generateSimulatedAppUsages(totalSeconds: TimeInterval) -> [AppUsage] {
        var usages: [AppUsage] = []
        var remainingTime = totalSeconds

        // Common apps with realistic distribution
        let appTemplates: [(name: String, bundle: String, category: AppCategory, weight: Double)] = [
            ("Instagram", "com.burbn.instagram", .social, 0.15),
            ("Twitter", "com.atebits.tweetie2", .social, 0.10),
            ("Messages", "com.apple.mobilesms", .communication, 0.12),
            ("Safari", "com.apple.mobilesafari", .productivity, 0.12),
            ("YouTube", "com.google.ios.youtube", .entertainment, 0.10),
            ("Spotify", "com.spotify.client", .music, 0.08), // Will be excluded
            ("Apple Maps", "com.apple.Maps", .navigation, 0.05), // Will be excluded
            ("Mail", "com.apple.mobilemail", .productivity, 0.08),
            ("Reddit", "com.reddit.Reddit", .social, 0.07),
            ("Netflix", "com.netflix.Netflix", .entertainment, 0.06),
            ("Slack", "com.tinyspeck.chatlyio", .communication, 0.04),
            ("News", "com.apple.news", .news, 0.03)
        ]

        for template in appTemplates {
            let variation = Double.random(in: 0.7...1.3)
            let usageTime = totalSeconds * template.weight * variation
            let finalTime = min(usageTime, remainingTime)

            if finalTime > 60 { // Only include if > 1 minute
                usages.append(AppUsage(
                    id: template.bundle,
                    name: template.name,
                    category: template.category,
                    usageSeconds: finalTime
                ))

                remainingTime -= finalTime
            }
        }

        return usages.sorted { $0.usageSeconds > $1.usageSeconds }
    }

    // MARK: - Authorization (Placeholder)

    /// Requests screen time authorization
    /// In production, this would request DeviceActivity permissions
    func requestAuthorization() async -> Bool {
        // Production implementation:
        // import FamilyControls
        // let center = AuthorizationCenter.shared
        // try await center.requestAuthorization(for: .individual)

        // For development, simulate approval
        return true
    }

    /// Checks if screen time access is authorized
    var isAuthorized: Bool {
        // Production: check AuthorizationCenter.shared.authorizationStatus
        // For development, return true
        return true
    }
}

// MARK: - Production Implementation Notes

/*
 To implement actual screen time tracking in production:

 1. Add Required Capabilities:
    - In Xcode project settings, add "Family Controls" capability
    - Add privacy usage description in Info.plist:
      <key>NSFamilyControlsUsageDescription</key>
      <string>This app needs access to screen time data to help you maintain healthy digital habits and optimize recovery.</string>

 2. Import Required Frameworks:
    import FamilyControls
    import DeviceActivity
    import ManagedSettings

 3. Request Authorization:
    let center = AuthorizationCenter.shared
    do {
        try await center.requestAuthorization(for: .individual)
    } catch {
        print("Failed to authorize: \(error)")
    }

 4. Monitor Device Activity:
    let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true
    )

    let center = DeviceActivityCenter()
    try center.startMonitoring(
        .daily,
        during: schedule
    )

 5. Fetch Usage Data:
    Use DeviceActivityReport to query app usage
    Filter out navigation and music categories
    Aggregate total screen time

 6. Privacy Considerations:
    - Clearly communicate why screen time data is needed
    - Allow users to opt-out
    - Don't share screen time data with third parties
    - Use data only for recovery score calculations
 */
