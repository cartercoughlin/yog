import Foundation

// MARK: - Screen Time Data Models

/// Represents daily screen time data with app-level breakdown
struct ScreenTimeData: Codable {
    let date: Date
    let totalScreenTimeSeconds: TimeInterval
    let appUsages: [AppUsage]

    init(date: Date, totalScreenTimeSeconds: TimeInterval, appUsages: [AppUsage] = []) {
        self.date = date
        self.totalScreenTimeSeconds = totalScreenTimeSeconds
        self.appUsages = appUsages
    }

    /// Total screen time in hours
    var totalHours: Double {
        totalScreenTimeSeconds / 3600.0
    }

    /// Screen time excluding navigation and music apps
    var filteredScreenTimeSeconds: TimeInterval {
        let excludedTime = appUsages
            .filter { $0.category == .navigation || $0.category == .music }
            .map { $0.usageSeconds }
            .reduce(0, +)

        return max(0, totalScreenTimeSeconds - excludedTime)
    }

    /// Filtered screen time in hours
    var filteredHours: Double {
        filteredScreenTimeSeconds / 3600.0
    }

    /// Top apps by usage time
    func topApps(limit: Int = 5) -> [AppUsage] {
        Array(appUsages
            .filter { $0.category != .navigation && $0.category != .music }
            .sorted { $0.usageSeconds > $1.usageSeconds }
            .prefix(limit))
    }

    /// Screen time by category
    var categoryBreakdown: [AppCategory: TimeInterval] {
        Dictionary(grouping: appUsages, by: { $0.category })
            .mapValues { $0.map { $0.usageSeconds }.reduce(0, +) }
    }
}

/// Represents usage data for a specific app
struct AppUsage: Codable, Identifiable {
    let id: String // Bundle identifier
    let name: String
    let category: AppCategory
    let usageSeconds: TimeInterval

    var usageHours: Double {
        usageSeconds / 3600.0
    }

    var formattedDuration: String {
        let hours = Int(usageSeconds / 3600)
        let minutes = Int((usageSeconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// App categories for filtering and analytics
enum AppCategory: String, Codable, CaseIterable {
    case social = "Social"
    case productivity = "Productivity"
    case entertainment = "Entertainment"
    case music = "Music"
    case navigation = "Navigation"
    case communication = "Communication"
    case health = "Health & Fitness"
    case shopping = "Shopping"
    case news = "News"
    case games = "Games"
    case utilities = "Utilities"
    case other = "Other"

    var icon: String {
        switch self {
        case .social: return "person.2.fill"
        case .productivity: return "checklist"
        case .entertainment: return "play.rectangle.fill"
        case .music: return "music.note"
        case .navigation: return "map.fill"
        case .communication: return "message.fill"
        case .health: return "heart.fill"
        case .shopping: return "cart.fill"
        case .news: return "newspaper.fill"
        case .games: return "gamecontroller.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .other: return "app.fill"
        }
    }

    var color: String {
        switch self {
        case .social: return "blue"
        case .productivity: return "green"
        case .entertainment: return "purple"
        case .music: return "pink"
        case .navigation: return "orange"
        case .communication: return "cyan"
        case .health: return "red"
        case .shopping: return "yellow"
        case .news: return "gray"
        case .games: return "indigo"
        case .utilities: return "brown"
        case .other: return "secondary"
        }
    }

    /// Categorize app based on bundle ID
    static func categorize(bundleId: String, appName: String) -> AppCategory {
        let id = bundleId.lowercased()
        let name = appName.lowercased()

        // Navigation apps
        if id.contains("maps") || id.contains("navigation") || id.contains("waze") ||
           name.contains("maps") || name.contains("navigation") {
            return .navigation
        }

        // Music apps
        if id.contains("music") || id.contains("spotify") || id.contains("pandora") ||
           id.contains("podcasts") || name.contains("music") || name.contains("spotify") {
            return .music
        }

        // Social apps
        if id.contains("facebook") || id.contains("instagram") || id.contains("twitter") ||
           id.contains("tiktok") || id.contains("snapchat") || id.contains("linkedin") {
            return .social
        }

        // Communication
        if id.contains("messages") || id.contains("whatsapp") || id.contains("telegram") ||
           id.contains("slack") || id.contains("discord") || name.contains("message") {
            return .communication
        }

        // Productivity
        if id.contains("notes") || id.contains("calendar") || id.contains("mail") ||
           id.contains("office") || id.contains("docs") || id.contains("sheets") {
            return .productivity
        }

        // Entertainment
        if id.contains("youtube") || id.contains("netflix") || id.contains("video") ||
           id.contains("tv") || name.contains("video") {
            return .entertainment
        }

        // Games
        if id.contains("game") || name.contains("game") {
            return .games
        }

        // Shopping
        if id.contains("amazon") || id.contains("shop") || id.contains("store") {
            return .shopping
        }

        // News
        if id.contains("news") || name.contains("news") {
            return .news
        }

        // Health & Fitness
        if id.contains("health") || id.contains("fitness") || id.contains("workout") {
            return .health
        }

        return .other
    }
}

/// Screen time statistics for a given period
struct ScreenTimeStatistics {
    let averageHours: Double
    let minimumHours: Double
    let maximumHours: Double
    let medianHours: Double
    let percentile25: Double
    let percentile75: Double
    let totalDays: Int
    let mostUsedCategory: AppCategory?
    let categoryAverages: [AppCategory: Double]

    init(screenTimeData: [ScreenTimeData]) {
        guard !screenTimeData.isEmpty else {
            self.averageHours = 0
            self.minimumHours = 0
            self.maximumHours = 0
            self.medianHours = 0
            self.percentile25 = 0
            self.percentile75 = 0
            self.totalDays = 0
            self.mostUsedCategory = nil
            self.categoryAverages = [:]
            return
        }

        let hours = screenTimeData.map { $0.filteredHours }.sorted()

        self.totalDays = hours.count
        self.averageHours = hours.reduce(0, +) / Double(hours.count)
        self.minimumHours = hours.first ?? 0
        self.maximumHours = hours.last ?? 0

        let mid = hours.count / 2
        self.medianHours = hours.count % 2 == 0 ?
            (hours[mid - 1] + hours[mid]) / 2.0 : hours[mid]

        let p25Index = Int(Double(hours.count) * 0.25)
        let p75Index = Int(Double(hours.count) * 0.75)
        self.percentile25 = hours[p25Index]
        self.percentile75 = hours[p75Index]

        // Calculate category statistics
        var categoryTotals: [AppCategory: TimeInterval] = [:]
        for data in screenTimeData {
            for (category, time) in data.categoryBreakdown {
                categoryTotals[category, default: 0] += time
            }
        }

        self.categoryAverages = categoryTotals.mapValues { $0 / 3600.0 / Double(screenTimeData.count) }
        self.mostUsedCategory = categoryAverages
            .filter { $0.key != .navigation && $0.key != .music }
            .max(by: { $0.value < $1.value })?.key
    }
}
