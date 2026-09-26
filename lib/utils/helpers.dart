import 'package:flutter/material.dart';
import 'constants.dart';

class AppHelpers {
  // Get greeting based on time of day
  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  // Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any non-digit characters
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }

    return null;
  }

  // Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Validate Date of Birth (required + must not be in the future)
  static String? validateDateOfBirth(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      return AppStrings.dateOfBirthRequired;
    }
    if (dateOfBirth.isAfter(DateTime.now())) {
      return AppStrings.dateOfBirthInvalid;
    }
    return null;
  }

  /// Calculate the user's current age from their Date of Birth.
  ///
  /// Correctly accounts for whether the birthday has already occurred this
  /// year (never simply `currentYear - birthYear`):
  ///   - born 2000-08-10, on 2026-08-09 -> 25 (birthday tomorrow)
  ///   - born 2000-08-10, on 2026-08-10 -> 26 (birthday today)
  ///   - born 2000-08-10, on 2026-08-11 -> 26
  ///
  /// Returns null when [dateOfBirth] is null or invalid (e.g. in the future).
  /// [now] is optional and only used to make the calculation testable.
  static int? calculateAge(DateTime? dateOfBirth, {DateTime? now}) {
    if (dateOfBirth == null) return null;

    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final dob = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);

    if (dob.isAfter(today)) return null;

    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  // Format phone number for display
  static String formatPhoneNumber(String phone) {
    if (phone.length == 10) {
      return '${phone.substring(0, 5)}-${phone.substring(5)}';
    }
    return phone;
  }

  // Show snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, color: Colors.green);
  }

  // Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, color: Colors.red);
  }

  // Format date for display
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Format date time for display - defensive with error handling
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      print('WARNING: formatDateTime received null, using current time');
      return formatDate(DateTime.now());
    }

    try {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('ERROR: Failed to format DateTime: $e');
      return 'Unknown time';
    }
  }

  // Generate unique ID
  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Check if string is empty or null
  static bool isEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Get emergency icon based on type
  static IconData getEmergencyIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medical':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'fire':
        return Icons.local_fire_department;
      case 'sos':
        return Icons.sos;
      default:
        return Icons.emergency;
    }
  }

  // Get emergency color based on type
  static Color getEmergencyColor(String type) {
    switch (type.toLowerCase()) {
      case 'medical':
        return Colors.red;
      case 'police':
        return Colors.blue;
      case 'fire':
        return Colors.orange;
      case 'sos':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Get the standard color for a complaint status.
  ///
  /// Single source of truth used by complaint cards, complaint details,
  /// the admin dashboard, the status timeline, and all status chips:
  ///   Pending -> Orange, In Progress -> Blue, Reviewing -> Purple,
  ///   Resolved -> Green, Rejected -> Red.
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'reviewing':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get the Material icon for a complaint category.
  ///
  /// Replaces the previous emoji glyphs with consistent, professional
  /// Material Design icons across all complaint surfaces.
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Roads':
        return Icons.route;
      case 'Water':
        return Icons.water_drop;
      case 'Electricity':
        return Icons.electric_bolt;
      case 'Drainage':
        return Icons.plumbing;
      case 'Garbage':
        return Icons.delete_outline;
      case 'Street Lights':
        return Icons.lightbulb_outline;
      case 'Internet':
        return Icons.wifi;
      case 'Public Safety':
        return Icons.security;
      case 'Other':
      default:
        return Icons.category;
    }
  }
}

// Global helper shortcuts
String? validatePhone(String? value) => AppHelpers.validatePhone(value);

String? validateRequired(String? value, String fieldName) =>
    AppHelpers.validateRequired(value, fieldName);

void showSuccessSnackBar(BuildContext context, String message) =>
    AppHelpers.showSuccessSnackBar(context, message);

void showErrorSnackBar(BuildContext context, String message) =>
    AppHelpers.showErrorSnackBar(context, message);
