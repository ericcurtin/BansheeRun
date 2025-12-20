import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @ObservedObject var repository = ActivityRepository.shared

    @State private var isRunning = false
    @State private var startTime: Date?
    @State private var totalDistance: Double = 0
    @State private var lastLocation: CLLocation?
    @State private var pacingStatus: BansheeLib.PacingStatus = .unknown
    @State private var timeDifferenceMs: Int64 = 0

    @State private var timer: Timer?
    @State private var elapsedMs: Int64 = 0

    // Activity tracking
    @State private var selectedActivityType: BansheeLib.ActivityType = .run
    @State private var recordedCoordinates: [(lat: Double, lon: Double, timestamp: Int64)] = []

    // Navigation
    @State private var showingActivityList = false
    @State private var showingPersonalBests = false
    @State private var showingNewPBAlert = false
    @State private var newPBs: [PersonalBest] = []
    @State private var showingBansheeSelector = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Activity type picker
                Picker("Activity Type", selection: $selectedActivityType) {
                    ForEach(BansheeLib.ActivityType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isRunning)
                .padding(.horizontal)

                Divider()

                // Status text
                Text(statusText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(pacingStatusColor)

                // Distance
                Text(BansheeLib.formatDistance(distanceMeters: totalDistance))
                    .font(.system(size: 32, weight: .bold))

                // Time
                Text(timeText)
                    .font(.system(size: 18))

                // Pace
                if totalDistance > 0 && elapsedMs > 0 {
                    Text(BansheeLib.formatPace(distanceMeters: totalDistance, durationMs: elapsedMs))
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }

                // Time difference
                if pacingStatus != .unknown {
                    Text(timeDiffText)
                        .font(.system(size: 18))
                        .foregroundColor(timeDifferenceMs >= 0 ? .green : .red)
                }

                Spacer().frame(height: 32)

                // Start/Stop button
                Button(action: toggleRun) {
                    HStack {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        Text(isRunning ? "Stop" : startButtonText)
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .green)

                // Select Banshee button
                Button(action: { showingBansheeSelector = true }) {
                    Text("Select Banshee")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .disabled(isRunning)

                Spacer()

                // Navigation buttons
                HStack(spacing: 20) {
                    Button(action: { showingActivityList = true }) {
                        VStack {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                            Text("Activities")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showingPersonalBests = true }) {
                        VStack {
                            Image(systemName: "trophy")
                                .font(.title2)
                            Text("PBs")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                }

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
            .frame(minWidth: 350, minHeight: 500)
            .navigationTitle("BansheeRun")
            .sheet(isPresented: $showingActivityList) {
                NavigationStack {
                    ActivityListView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingActivityList = false }
                            }
                        }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
            .sheet(isPresented: $showingPersonalBests) {
                NavigationStack {
                    PersonalBestsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingPersonalBests = false }
                            }
                        }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
            .sheet(isPresented: $showingBansheeSelector) {
                NavigationStack {
                    BansheeSelectorView { activityId in
                        showingBansheeSelector = false
                        loadActivityAsBanshee(id: activityId)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingBansheeSelector = false }
                        }
                    }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
            .alert("New Personal Best!", isPresented: $showingNewPBAlert) {
                Button("OK") { }
            } message: {
                Text(newPBAlertMessage)
            }
        }
        .onReceive(locationManager.$currentLocation) { location in
            guard let location = location, isRunning else { return }
            updateWithLocation(location)
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }

    private var pacingStatusColor: Color {
        switch pacingStatus {
        case .ahead: return .green
        case .behind: return .red
        case .unknown: return .primary
        }
    }

    private var newPBAlertMessage: String {
        newPBs.map { "\($0.distanceName): \($0.formattedTime)" }.joined(separator: "\n")
    }

    private var statusText: String {
        switch pacingStatus {
        case .ahead: return "AHEAD"
        case .behind: return "BEHIND"
        case .unknown: return "---"
        }
    }

    private var startButtonText: String {
        "Start \(selectedActivityType.displayName)"
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
        recordedCoordinates = []

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

        // Save activity if we have coordinates
        if recordedCoordinates.count >= 2 {
            saveActivity()
        }
    }

    private func saveActivity() {
        // Build coordinates JSON
        let coordsArray = recordedCoordinates.map { coord in
            """
            {"lat":\(coord.lat),"lon":\(coord.lon),"timestamp_ms":\(coord.timestamp)}
            """
        }
        let coordsJson = "[\(coordsArray.joined(separator: ","))]"

        // Generate activity ID and name
        let id = UUID().uuidString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d 'at' h:mm a"
        let name = "\(selectedActivityType.displayName) - \(dateFormatter.string(from: Date()))"
        let recordedAt = Int64(Date().timeIntervalSince1970 * 1000)

        // Create activity JSON via Rust
        guard let activityJson = BansheeLib.createActivityJson(
            id: id,
            name: name,
            activityType: selectedActivityType,
            coordsJson: coordsJson,
            recordedAt: recordedAt
        ) else {
            print("Failed to create activity")
            return
        }

        // Check for new PBs before saving
        let achievedPBs = repository.getNewPBs(activityJson: activityJson)

        // Save activity
        repository.saveActivity(activityJson: activityJson)

        // Show PB alert if any new records
        if !achievedPBs.isEmpty {
            newPBs = achievedPBs
            showingNewPBAlert = true
        }
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

        // Record coordinate for saving
        recordedCoordinates.append((lat: lat, lon: lon, timestamp: elapsedMs))
    }

    private func loadActivityAsBanshee(id: String) {
        guard let activityJson = repository.loadActivity(id: id) else {
            print("Failed to load activity")
            return
        }

        let result = BansheeLib.initSession(json: activityJson)
        if result == 0 {
            print("Banshee loaded!")
        } else {
            print("Failed to load banshee: \(result)")
        }
    }
}
