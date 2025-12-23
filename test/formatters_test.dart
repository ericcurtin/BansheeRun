import 'package:flutter_test/flutter_test.dart';
import 'package:banshee_run_app/src/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('formatDuration', () {
      test('formats zero duration', () {
        expect(Formatters.formatDuration(0), '0:00');
      });

      test('formats seconds only', () {
        expect(Formatters.formatDuration(45000), '0:45');
      });

      test('formats minutes and seconds', () {
        expect(Formatters.formatDuration(125000), '2:05');
      });

      test('formats hours', () {
        expect(Formatters.formatDuration(3661000), '1:01:01');
      });
    });

    group('formatDistanceKm', () {
      test('formats zero distance as meters', () {
        expect(Formatters.formatDistanceKm(0), '0 m');
      });

      test('formats small distance as meters', () {
        expect(Formatters.formatDistanceKm(500), '500 m');
      });

      test('formats kilometers', () {
        expect(Formatters.formatDistanceKm(5123), '5.12 km');
      });

      test('formats at threshold', () {
        expect(Formatters.formatDistanceKm(1000), '1.00 km');
      });
    });

    group('formatPace', () {
      test('returns -- for null', () {
        expect(Formatters.formatPace(null), '--:--');
      });

      test('returns -- for zero', () {
        expect(Formatters.formatPace(0), '--:--');
      });

      test('formats pace correctly', () {
        // 5 min/km = 300 sec/km
        expect(Formatters.formatPace(300), '5:00');
      });

      test('formats pace with seconds', () {
        // 5:30 min/km = 330 sec/km
        expect(Formatters.formatPace(330), '5:30');
      });
    });

    group('formatBansheeDelta', () {
      test('formats when ahead', () {
        // Negative means user is ahead
        expect(Formatters.formatBansheeDelta(-50), '50m ahead');
      });

      test('formats when behind', () {
        // Positive means user is behind
        expect(Formatters.formatBansheeDelta(75), '75m behind');
      });

      test('formats exact tie', () {
        expect(Formatters.formatBansheeDelta(0), 'Even');
      });

      test('formats large distance in km', () {
        expect(Formatters.formatBansheeDelta(1500), '1.50km behind');
      });
    });
  });
}
