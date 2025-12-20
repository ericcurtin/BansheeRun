import Foundation

/// Repository for storing and loading activities and personal bests.
class ActivityRepository: ObservableObject {
    static let shared = ActivityRepository()

    @Published var activities: [ActivitySummary] = []
    @Published var personalBests: String = "{\"records\":[]}"

    private let fileManager = FileManager.default

    private var baseURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bansheeDir = appSupport.appendingPathComponent("BansheeRun", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: bansheeDir.path) {
            try? fileManager.createDirectory(at: bansheeDir, withIntermediateDirectories: true)
        }

        return bansheeDir
    }

    private var activitiesDir: URL {
        let dir = baseURL.appendingPathComponent("activities", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var indexURL: URL {
        activitiesDir.appendingPathComponent("index.json")
    }

    private var personalBestsURL: URL {
        baseURL.appendingPathComponent("personal_bests.json")
    }

    init() {
        loadAll()
    }

    // MARK: - Load Operations

    func loadAll() {
        loadActivityIndex()
        loadPersonalBests()
    }

    private func loadActivityIndex() {
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let _ = String(data: data, encoding: .utf8) else {
            activities = []
            return
        }

        // Parse JSON into ActivitySummary array
        if let decoded = try? JSONDecoder().decode(ActivityIndex.self, from: data) {
            activities = decoded.activities
        }
    }

    private func loadPersonalBests() {
        guard fileManager.fileExists(atPath: personalBestsURL.path),
              let data = try? Data(contentsOf: personalBestsURL),
              let json = String(data: data, encoding: .utf8) else {
            personalBests = "{\"records\":[]}"
            return
        }
        personalBests = json
    }

    // MARK: - Save Operations

    func saveActivity(activityJson: String) {
        guard let activityData = activityJson.data(using: .utf8),
              let activity = try? JSONDecoder().decode(Activity.self, from: activityData) else {
            return
        }

        // Save full activity to individual file
        let activityURL = activitiesDir.appendingPathComponent("\(activity.id).json")
        try? activityData.write(to: activityURL)

        // Get summary and add to index
        if let summaryJson = BansheeLib.getActivitySummary(activityJson: activityJson),
           let summaryData = summaryJson.data(using: .utf8),
           let summary = try? JSONDecoder().decode(ActivitySummary.self, from: summaryData) {
            activities.insert(summary, at: 0)
            saveActivityIndex()
        }

        // Update PBs
        if let updatedPbs = BansheeLib.updatePbs(existingPbsJson: personalBests, activityJson: activityJson) {
            personalBests = updatedPbs
            savePersonalBests()
        }
    }

    private func saveActivityIndex() {
        let index = ActivityIndex(activities: activities)
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: indexURL)
        }
    }

    private func savePersonalBests() {
        if let data = personalBests.data(using: .utf8) {
            try? data.write(to: personalBestsURL)
        }
    }

    // MARK: - Load Single Activity

    func loadActivity(id: String) -> String? {
        let activityURL = activitiesDir.appendingPathComponent("\(id).json")
        guard let data = try? Data(contentsOf: activityURL),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    // MARK: - Delete Activity

    func deleteActivity(id: String) {
        // Remove from index
        activities.removeAll { $0.id == id }
        saveActivityIndex()

        // Delete file
        let activityURL = activitiesDir.appendingPathComponent("\(id).json")
        try? fileManager.removeItem(at: activityURL)
    }

    // MARK: - Filter & Sort

    func getActivities(type: BansheeLib.ActivityType?) -> [ActivitySummary] {
        if let type = type {
            return activities.filter { $0.activityType == type.rawValue }
        }
        return activities
    }

    func getPersonalBests(type: BansheeLib.ActivityType) -> [PersonalBest] {
        guard let filtered = BansheeLib.getPbsForType(pbsJson: personalBests, activityType: type),
              let data = filtered.data(using: .utf8),
              let pbs = try? JSONDecoder().decode([PersonalBest].self, from: data) else {
            return []
        }
        return pbs
    }

    func getNewPBs(activityJson: String) -> [PersonalBest] {
        guard let newPbsJson = BansheeLib.getNewPbs(existingPbsJson: personalBests, activityJson: activityJson),
              let data = newPbsJson.data(using: .utf8),
              let pbs = try? JSONDecoder().decode([PersonalBest].self, from: data) else {
            return []
        }
        return pbs
    }
}

// MARK: - Codable Models

struct ActivityIndex: Codable {
    var activities: [ActivitySummary]
}

struct ActivitySummary: Codable, Identifiable {
    let id: String
    let name: String
    let activityType: Int
    let totalDistanceMeters: Double
    let durationMs: Int64
    let recordedAt: Int64
    let paceMinPerKm: Double

    enum CodingKeys: String, CodingKey {
        case id, name
        case activityType = "activity_type"
        case totalDistanceMeters = "total_distance_meters"
        case durationMs = "duration_ms"
        case recordedAt = "recorded_at"
        case paceMinPerKm = "pace_min_per_km"
    }

    var type: BansheeLib.ActivityType {
        BansheeLib.ActivityType(rawValue: Int32(activityType)) ?? .run
    }
}

struct Activity: Codable {
    let id: String
    let name: String
    let activityType: String
    let coordinates: [Coordinate]
    let totalDistanceMeters: Double
    let durationMs: Int64
    let recordedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, coordinates
        case activityType = "activity_type"
        case totalDistanceMeters = "total_distance_meters"
        case durationMs = "duration_ms"
        case recordedAt = "recorded_at"
    }
}

struct Coordinate: Codable {
    let lat: Double
    let lon: Double
    let timestampMs: Int64

    enum CodingKeys: String, CodingKey {
        case lat, lon
        case timestampMs = "timestamp_ms"
    }
}

struct PersonalBest: Codable, Identifiable {
    let activityType: String
    let distanceMeters: Double
    let timeMs: Int64
    let activityId: String
    let achievedAt: Int64
    let paceMinPerKm: Double

    var id: String { "\(activityType)_\(distanceMeters)" }

    enum CodingKeys: String, CodingKey {
        case activityType = "activity_type"
        case distanceMeters = "distance_meters"
        case timeMs = "time_ms"
        case activityId = "activity_id"
        case achievedAt = "achieved_at"
        case paceMinPerKm = "pace_min_per_km"
    }

    var distanceName: String {
        BansheeLib.getDistanceName(distanceMeters: distanceMeters)
    }

    var formattedTime: String {
        BansheeLib.formatDuration(durationMs: timeMs)
    }

    var formattedPace: String {
        BansheeLib.formatPace(distanceMeters: distanceMeters, durationMs: timeMs)
    }
}
