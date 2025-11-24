//
//  WeatherData.swift
//  RecoveryApp
//
//  Created on 2025-11-24
//

import Foundation

struct WeatherData: Codable {
    let temperature: Double
    let condition: WeatherCondition
    let location: String

    enum WeatherCondition: String, Codable {
        case clear = "Clear"
        case cloudy = "Clouds"
        case rain = "Rain"
        case drizzle = "Drizzle"
        case thunderstorm = "Thunderstorm"
        case snow = "Snow"
        case mist = "Mist"
        case fog = "Fog"
        case smoke = "Smoke"
        case haze = "Haze"
        case dust = "Dust"

        var icon: String {
            switch self {
            case .clear:
                return "sun.max.fill"
            case .cloudy:
                return "cloud.fill"
            case .rain:
                return "cloud.rain.fill"
            case .drizzle:
                return "cloud.drizzle.fill"
            case .thunderstorm:
                return "cloud.bolt.fill"
            case .snow:
                return "snowflake"
            case .mist, .fog:
                return "cloud.fog.fill"
            case .smoke, .haze, .dust:
                return "smoke.fill"
            }
        }
    }
}

struct OpenWeatherResponse: Codable {
    let main: Main
    let weather: [Weather]
    let name: String

    struct Main: Codable {
        let temp: Double
    }

    struct Weather: Codable {
        let main: String
    }
}
