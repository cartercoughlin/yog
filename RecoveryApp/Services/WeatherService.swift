//
//  WeatherService.swift
//  RecoveryApp
//
//  Created on 2025-11-24
//

import Foundation
import CoreLocation
import Combine

class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let apiKey = "f94236cc25f11bbe640ad9db6c35fccd" // Replace with your API key

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetchWeather() {
        errorMessage = nil

        let authStatus = locationManager.authorizationStatus
        print("Current location authorization status: \(authStatus.rawValue)")

        switch authStatus {
        case .notDetermined:
            isLoading = true
            print("Requesting location authorization...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLoading = true
            print("Location authorized, requesting location...")
            locationManager.requestLocation()
        case .denied, .restricted:
            print("Location permission denied or restricted")
            DispatchQueue.main.async {
                self.errorMessage = "Location permission denied"
                self.isLoading = false
            }
        @unknown default:
            DispatchQueue.main.async {
                self.errorMessage = "Location unavailable"
                self.isLoading = false
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("Authorization changed to: \(status.rawValue)")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Permission granted, requesting location...")
            DispatchQueue.main.async {
                self.isLoading = true
            }
            locationManager.requestLocation()
        case .denied, .restricted:
            print("Permission denied or restricted")
            DispatchQueue.main.async {
                self.errorMessage = "Location permission denied"
                self.isLoading = false
            }
        case .notDetermined:
            print("Authorization still not determined")
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        Task {
            await fetchWeatherData(for: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.errorMessage = "Location unavailable"
            self.isLoading = false
        }
    }

    private func fetchWeatherData(for location: CLLocation) async {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&units=imperial&appid=\(apiKey)"

        guard let url = URL(string: urlString) else {
            await MainActor.run {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)

            let condition = WeatherData.WeatherCondition(rawValue: response.weather.first?.main ?? "Clear") ?? .clear

            await MainActor.run {
                self.currentWeather = WeatherData(
                    temperature: response.main.temp,
                    condition: condition,
                    location: response.name
                )
                self.errorMessage = nil
                self.isLoading = false
            }
        } catch {
            print("Weather fetch error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("Decoding error details: \(decodingError)")
            }
            await MainActor.run {
                self.errorMessage = "Weather unavailable"
                self.isLoading = false
            }
        }
    }
}
