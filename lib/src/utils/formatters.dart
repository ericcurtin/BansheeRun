import 'package:intl/intl.dart';

class Formatters {
  /// Format duration in milliseconds to HH:MM:SS or MM:SS
  static String formatDuration(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format pace in seconds per km to MM:SS/km
  static String formatPace(double? paceSecPerKm) {
    if (paceSecPerKm == null ||
        paceSecPerKm <= 0 ||
        paceSecPerKm.isNaN ||
        paceSecPerKm.isInfinite) {
      return '--:--';
    }

    final totalSeconds = paceSecPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format distance in meters to km with 2 decimal places
  static String formatDistanceKm(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// Format distance in meters to miles
  static String formatDistanceMiles(double meters) {
    final miles = meters / 1609.344;
    if (miles < 0.1) {
      final feet = meters * 3.28084;
      return '${feet.round()} ft';
    }
    return '${miles.toStringAsFixed(2)} mi';
  }

  /// Format date for display
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Format time for display
  static String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  /// Format date and time
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

  /// Format relative time (e.g., "2 days ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return formatDate(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }

  /// Format banshee delta for display
  static String formatBansheeDelta(double deltaMeters) {
    final absDistance = deltaMeters.abs();
    final direction = deltaMeters > 0 ? 'behind' : 'ahead';

    if (absDistance < 1) {
      return 'Even';
    } else if (absDistance < 1000) {
      return '${absDistance.round()}m $direction';
    } else {
      return '${(absDistance / 1000).toStringAsFixed(2)}km $direction';
    }
  }
}
