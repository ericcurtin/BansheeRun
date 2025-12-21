import SwiftUI

struct ActivityListView: View {
    @ObservedObject var repository = ActivityRepository.shared
    @State private var selectedType: BansheeLib.ActivityType? = nil
    let onStartBansheeMode: (String) -> Void

    var filteredActivities: [ActivitySummary] {
        repository.getActivities(type: selectedType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Activity Type", selection: $selectedType) {
                Text("All").tag(nil as BansheeLib.ActivityType?)
                ForEach(BansheeLib.ActivityType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type as BansheeLib.ActivityType?)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Activity list
            if filteredActivities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No activities yet")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Complete an activity to see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredActivities) { activity in
                    NavigationLink(destination: ActivityDetailView(activityId: activity.id, onStartBansheeMode: onStartBansheeMode)) {
                        ActivityRowView(activity: activity)
                    }
                }
            }
        }
        .navigationTitle("Activities")
    }
}

struct ActivityRowView: View {
    let activity: ActivitySummary

    var body: some View {
        HStack(spacing: 12) {
            // Activity type icon
            Image(systemName: activity.type.icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)

                HStack(spacing: 16) {
                    Label(BansheeLib.formatDistance(distanceMeters: activity.totalDistanceMeters),
                          systemImage: "ruler")
                    Label(BansheeLib.formatDuration(durationMs: activity.durationMs),
                          systemImage: "clock")
                    Label(BansheeLib.formatPace(distanceMeters: activity.totalDistanceMeters,
                                                durationMs: activity.durationMs),
                          systemImage: "speedometer")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Date
            Text(formatDate(activity.recordedAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ epochMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ActivityDetailView: View {
    let activityId: String
    let onStartBansheeMode: (String) -> Void
    @ObservedObject var repository = ActivityRepository.shared
    @Environment(\.dismiss) private var dismiss

    var activity: Activity? {
        guard let json = repository.loadActivity(id: activityId),
              let data = json.data(using: .utf8),
              let activity = try? JSONDecoder().decode(Activity.self, from: data) else {
            return nil
        }
        return activity
    }

    var summary: ActivitySummary? {
        repository.activities.first { $0.id == activityId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let summary = summary, let activity = activity {
                    // Header
                    HStack {
                        Image(systemName: summary.type.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text(summary.name)
                                .font(.title)
                                .fontWeight(.bold)
                            Text(formatDate(summary.recordedAt))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 10)

                    Divider()

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        StatCard(title: "Distance", value: BansheeLib.formatDistance(distanceMeters: summary.totalDistanceMeters), icon: "ruler")
                        StatCard(title: "Duration", value: BansheeLib.formatDuration(durationMs: summary.durationMs), icon: "clock")
                        StatCard(title: "Pace", value: BansheeLib.formatPace(distanceMeters: summary.totalDistanceMeters, durationMs: summary.durationMs), icon: "speedometer")
                        StatCard(title: "Points", value: "\(activity.coordinates.count)", icon: "location")
                    }

                    Divider()

                    // Activity info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity Details")
                            .font(.headline)
                        HStack {
                            Text("Type:")
                                .foregroundColor(.secondary)
                            Text(summary.type.displayName)
                        }
                        if let first = activity.coordinates.first {
                            HStack {
                                Text("Start:")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.5f, %.5f", first.lat, first.lon))
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        if let last = activity.coordinates.last {
                            HStack {
                                Text("End:")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.5f, %.5f", last.lat, last.lon))
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }

                    Spacer().frame(height: 20)

                    // Banshee Mode button
                    Button(action: {
                        onStartBansheeMode(activityId)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "figure.run")
                            Text("Banshee Mode")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Text("Race against this activity! The race starts when you reach the start point and ends at the finish.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                } else {
                    Text("Activity not found")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Activity")
    }

    private func formatDate(_ epochMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PersonalBestsView: View {
    @ObservedObject var repository = ActivityRepository.shared
    @State private var selectedType: BansheeLib.ActivityType = .run

    var personalBests: [PersonalBest] {
        repository.getPersonalBests(type: selectedType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Type picker
            Picker("Activity Type", selection: $selectedType) {
                ForEach(BansheeLib.ActivityType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // PB list
            if personalBests.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No personal bests yet")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Complete activities to set your records")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(personalBests) { pb in
                    PersonalBestRowView(personalBest: pb)
                }
            }
        }
        .navigationTitle("Personal Bests")
    }
}

struct PersonalBestRowView: View {
    let personalBest: PersonalBest

    var body: some View {
        HStack(spacing: 16) {
            // Distance badge
            VStack {
                Text(personalBest.distanceName)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(width: 80, height: 40)
            .background(Color.accentColor)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(personalBest.formattedTime)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(personalBest.formattedPace)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Date achieved
            Text(formatDate(personalBest.achievedAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ epochMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
