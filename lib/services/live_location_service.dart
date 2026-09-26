import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class LiveLocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  bool _isTracking = false;

  /// Get the current location once
  Future<Position?> getCurrentLocation({
    bool allowPermissionRequest = true,
    bool allowOpenSettings = true,
  }) async {
    try {
      // Check location permission
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        if (!allowPermissionRequest) {
          return null;
        }

        final granted = await _requestLocationPermission(
          allowOpenSettings: allowOpenSettings,
        );
        if (!granted) {
          return null;
        }
      }

      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!allowOpenSettings) {
          return null;
        }

        // Try to open location settings
        await Geolocator.openLocationSettings();
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start tracking location continuously
  Future<bool> startLocationTracking({
    Duration interval = const Duration(seconds: 5),
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
  }) async {
    try {
      if (_isTracking) {
        return true;
      }

      // Check permission
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        final granted = await _requestLocationPermission();
        if (!granted) {
          return false;
        }
      }

      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return false;
      }

      // Start location stream
      final locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: null,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          _positionController.add(position);
        },
        onError: (error) {
          print('Location stream error: $error');
        },
      );

      _isTracking = true;
      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop tracking location
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
  }

  /// Get the location stream
  Stream<Position> get locationStream => _positionController.stream;

  /// Check if currently tracking
  bool get isTracking => _isTracking;

  /// Generate Google Maps link from coordinates
  String generateGoogleMapsLink(double latitude, double longitude) {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// Check location permission
  Future<bool> _checkLocationPermission() async {
    final status = await ph.Permission.location.status;
    return status.isGranted;
  }

  /// Request location permission
  Future<bool> _requestLocationPermission({
    bool allowOpenSettings = true,
  }) async {
    final status = await ph.Permission.location.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied && allowOpenSettings) {
      // Open app settings if permanently denied
      await ph.openAppSettings();
      return false;
    }
    return false;
  }

  /// Request background location permission (for continuous tracking)
  Future<bool> requestBackgroundLocationPermission() async {
    final status = await ph.Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Check if background location is granted
  Future<bool> isBackgroundLocationGranted() async {
    final status = await ph.Permission.locationAlways.status;
    return status.isGranted;
  }

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
    _positionController.close();
  }
}
