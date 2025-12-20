import SwiftUI

struct ActivityListView: View {
    @ObservedObject var repository = ActivityRepository.shared
    @State private var selectedType: BansheeLib.ActivityType? = nil

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
                    ActivityRowView(activity: activity)
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
