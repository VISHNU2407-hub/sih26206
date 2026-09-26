import 'package:url_launcher/url_launcher.dart';

/// SATS Disaster — Google Maps directions helper.
///
/// Builds a universal Google Maps directions deep link and launches it.
/// Uses the official Maps URLs API (`api=1`) which requires **no API key**
/// and works on both Android and iOS; when the standalone Maps app is not
/// installed the OS falls back to the browser automatically.
class MapsDirections {
  MapsDirections._();

  /// Builds a Google Maps directions URL to [latitude]/[longitude].
  ///
  /// The destination is always the exact coordinates (not a text geocode)
  /// so the route targets the shelter pin precisely. Returns `null` when
  /// the coordinates are missing or out of range.
  static String? buildDirectionsUrl({
    required double? latitude,
    required double? longitude,
  }) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

    return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
  }

  /// Builds a plain "view on map" URL (pin, no route) for records that only
  /// have coordinates but no routing need.
  static String buildViewUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  /// Opens Google Maps directions to the given destination. Returns `true`
  /// when a Maps target could be launched. Launch failures (no Maps app,
  /// no browser, platform restriction) return `false` so callers can show a
  /// human-friendly message instead of a raw exception.
  static Future<bool> openDirections({
    required double? latitude,
    required double? longitude,
  }) async {
    final url = buildDirectionsUrl(latitude: latitude, longitude: longitude);
    if (url == null) return false;

    final uri = Uri.parse(url);
    try {
      // externalApplication lets the OS pick the Maps app, falling back to
      // the browser when Maps is not installed.
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
