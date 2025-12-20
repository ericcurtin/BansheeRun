import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

    @State private var isRunning = false
    @State private var startTime: Date?
    @State private var totalDistance: Double = 0
    @State private var lastLocation: CLLocation?
    @State private var pacingStatus: BansheeLib.PacingStatus = .unknown
    @State private var timeDifferenceMs: Int64 = 0

    @State private var timer: Timer?
    @State private var elapsedMs: Int64 = 0

    var body: some View {
        VStack(spacing: 16) {
            // Status text
            Text(statusText)
                .font(.system(size: 24, weight: .bold))

            // Distance
            Text(String(format: "Distance: %.2f km", totalDistance / 1000.0))
                .font(.system(size: 18))

            // Time
            Text(timeText)
                .font(.system(size: 18))

            // Time difference
            Text(timeDiffText)
                .font(.system(size: 18))

            Spacer().frame(height: 32)

            // Start/Stop button
            Button(action: toggleRun) {
                Text(isRunning ? "Stop Run" : "Start Run")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)

            // Select Best Run button
            Button(action: loadSampleBestRun) {
                Text("Select Best Run")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)

            // Status messages
            if let error = locationManager.locationError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if locationManager.authorizationStatus == .denied {
                Text("Location access denied. Please enable in System Preferences.")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(minWidth: 300, minHeight: 400)
        .onReceive(locationManager.$currentLocation) { location in
            guard let location = location, isRunning else { return }
            updateWithLocation(location)
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }

    private var statusText: String {
        switch pacingStatus {
        case .ahead: return "AHEAD"
        case .behind: return "BEHIND"
        case .unknown: return "---"
        }
    }

    private var timeText: String {
        let seconds = elapsedMs / 1000
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "Time: %02d:%02d", minutes, secs)
    }

    private var timeDiffText: String {
        guard pacingStatus != .unknown else { return "" }
        let diffSeconds = abs(timeDifferenceMs) / 1000
        let sign = timeDifferenceMs >= 0 ? "+" : "-"
        return String(format: "%@%d seconds", sign, diffSeconds)
    }

    private func toggleRun() {
        if isRunning {
            stopRun()
        } else {
            startRun()
        }
    }

    private func startRun() {
        // macOS only has authorizedAlways (not authorizedWhenInUse)
        guard locationManager.authorizationStatus == .authorizedAlways ||
              locationManager.authorizationStatus == .authorized else {
            locationManager.requestPermission()
            return
        }

        isRunning = true
        startTime = Date()
        totalDistance = 0
        lastLocation = nil
        elapsedMs = 0
        pacingStatus = .unknown
        timeDifferenceMs = 0

        locationManager.startTracking()

        // Start timer to update elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let start = startTime else { return }
            elapsedMs = Int64(Date().timeIntervalSince(start) * 1000)
        }
    }

    private func stopRun() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        locationManager.stopTracking()
    }

    private func updateWithLocation(_ location: CLLocation) {
        // Calculate distance from last location
        if let last = lastLocation {
            let delta = location.distance(from: last)
            totalDistance += delta
        }
        lastLocation = location

        // Get pacing info from Rust library
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        pacingStatus = BansheeLib.getPacingStatus(lat: lat, lon: lon, elapsedMs: elapsedMs)
        timeDifferenceMs = BansheeLib.getTimeDifferenceMs(lat: lat, lon: lon, elapsedMs: elapsedMs)
    }

    private func loadSampleBestRun() {
        // Sample run record JSON for testing (same as Android)
        let sampleJson = """
        {
            "id": "sample-run-1",
            "name": "Sample 5K",
            "coordinates": [
                {"lat": 40.7128, "lon": -74.0060, "timestamp_ms": 0},
                {"lat": 40.7135, "lon": -74.0055, "timestamp_ms": 60000},
                {"lat": 40.7142, "lon": -74.0050, "timestamp_ms": 120000},
                {"lat": 40.7149, "lon": -74.0045, "timestamp_ms": 180000},
                {"lat": 40.7156, "lon": -74.0040, "timestamp_ms": 240000}
            ],
            "total_distance_meters": 500.0,
            "duration_ms": 240000,
            "recorded_at": 1700000000000
        }
        """

        let result = BansheeLib.initSession(json: sampleJson)
        if result == 0 {
            print("Best run loaded!")
        } else {
            print("Failed to load best run: \(result)")
        }
    }
}
