import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ActivityType {
  run,
  walk,
  cycle,
  skate,
}

extension ActivityTypeExtension on ActivityType {
  String get displayName {
    switch (this) {
      case ActivityType.run:
        return 'Run';
      case ActivityType.walk:
        return 'Walk';
      case ActivityType.cycle:
        return 'Cycle';
      case ActivityType.skate:
        return 'Skate';
    }
  }

  String get emoji {
    switch (this) {
      case ActivityType.run:
        return '🏃';
      case ActivityType.walk:
        return '🚶';
      case ActivityType.cycle:
        return '🚴';
      case ActivityType.skate:
        return '⛸️';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityType.run:
        return Icons.directions_run;
      case ActivityType.walk:
        return Icons.directions_walk;
      case ActivityType.cycle:
        return Icons.directions_bike;
      case ActivityType.skate:
        return Icons.skateboarding;
    }
  }

  Color get color {
    switch (this) {
      case ActivityType.run:
        return AppColors.runOrange;
      case ActivityType.walk:
        return AppColors.walkBlue;
      case ActivityType.cycle:
        return AppColors.cycleGreen;
      case ActivityType.skate:
        return AppColors.skateViolet;
    }
  }
}

enum PacingStatus {
  ahead,
  behind,
  unknown,
}

extension PacingStatusExtension on PacingStatus {
  String get displayName {
    switch (this) {
      case PacingStatus.ahead:
        return 'AHEAD';
      case PacingStatus.behind:
        return 'BEHIND';
      case PacingStatus.unknown:
        return 'UNKNOWN';
    }
  }

  Color get color {
    switch (this) {
      case PacingStatus.ahead:
        return AppColors.aheadGreen;
      case PacingStatus.behind:
        return AppColors.behindRed;
      case PacingStatus.unknown:
        return AppColors.unknownYellow;
    }
  }

  IconData get icon {
    switch (this) {
      case PacingStatus.ahead:
        return Icons.trending_up;
      case PacingStatus.behind:
        return Icons.trending_down;
      case PacingStatus.unknown:
        return Icons.trending_flat;
    }
  }
}

class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class Activity {
  final String id;
  final String name;
  final ActivityType type;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final Duration duration;
  final List<GpsPoint> points;
  final String? pacePerKm;

  const Activity({
    required this.id,
    required this.name,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.duration,
    required this.points,
    this.pacePerKm,
  });

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get formattedDistance {
    if (distanceKm >= 1) {
      return '${distanceKm.toStringAsFixed(2)} km';
    } else {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
  }

  String get formattedPace {
    if (pacePerKm != null) return pacePerKm!;
    if (distanceKm == 0) return '--:--';

    final paceSeconds = duration.inSeconds / distanceKm;
    final paceMinutes = (paceSeconds / 60).floor();
    final paceSecs = (paceSeconds % 60).floor();
    return '$paceMinutes:${paceSecs.toString().padLeft(2, '0')} /km';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'distanceKm': distanceKm,
        'durationSeconds': duration.inSeconds,
        'points': points.map((p) => p.toJson()).toList(),
        'pacePerKm': pacePerKm,
      };

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ActivityType.values[json['type'] as int],
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        duration: Duration(seconds: json['durationSeconds'] as int),
        points: (json['points'] as List)
            .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        pacePerKm: json['pacePerKm'] as String?,
      );
}

class PersonalBest {
  final String id;
  final String distanceName;
  final double distanceKm;
  final ActivityType type;
  final Duration time;
  final DateTime achievedAt;
  final String? activityId;

  const PersonalBest({
    required this.id,
    required this.distanceName,
    required this.distanceKm,
    required this.type,
    required this.time,
    required this.achievedAt,
    this.activityId,
  });

  String get formattedTime {
    final hours = time.inHours;
    final minutes = time.inMinutes.remainder(60);
    final seconds = time.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get formattedPace {
    if (distanceKm == 0) return '--:--';
    final paceSeconds = time.inSeconds / distanceKm;
    final paceMinutes = (paceSeconds / 60).floor();
    final paceSecs = (paceSeconds % 60).floor();
    return '$paceMinutes:${paceSecs.toString().padLeft(2, '0')} /km';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'distanceName': distanceName,
        'distanceKm': distanceKm,
        'type': type.index,
        'timeSeconds': time.inSeconds,
        'achievedAt': achievedAt.toIso8601String(),
        'activityId': activityId,
      };

  factory PersonalBest.fromJson(Map<String, dynamic> json) => PersonalBest(
        id: json['id'] as String,
        distanceName: json['distanceName'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        type: ActivityType.values[json['type'] as int],
        time: Duration(seconds: json['timeSeconds'] as int),
        achievedAt: DateTime.parse(json['achievedAt'] as String),
        activityId: json['activityId'] as String?,
      );
}
