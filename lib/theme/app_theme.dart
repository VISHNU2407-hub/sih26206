import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// SATS Disaster — centralized design system.
///
/// One place for the semantic color language, typography scale, geometry
/// and shared status mappings so every screen stays visually consistent.
/// Screens should never hardcode severity/status colors.

// ─────────────────────────────────────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────────────────────────────────────

/// Semantic palette. Statuses/severities MUST map through [severityColor],
/// [incidentStatusColor] etc. instead of inline Color literals.
abstract final class AppColors {
  // Brand / trust
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primarySoft = Color(0xFFE8F0FB);

  // Semantic
  static const Color danger = Color(0xFFC62828); // emergency / critical
  static const Color dangerDeep = Color(0xFF8E1414); // SOS surfaces
  static const Color warning = Color(0xFFE65100); // high severity
  static const Color amber = Color(0xFFF9A825); // medium severity
  static const Color success = Color(0xFF2E7D32); // safe / resolved
  static const Color info = Color(0xFF1565C0); // informational
  static const Color neutral = Color(0xFF607D8B); // inactive / closed
  static const Color violet = Color(0xFF6A1B9A); // people-centric metrics

  // Surfaces
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F3F6);
  static const Color outline = Color(0xFFE1E6EC);
  static const Color outlineStrong = Color(0xFFCBD2DB);

  // Text
  static const Color textPrimary = Color(0xFF1A2430);
  static const Color textSecondary = Color(0xFF5A6472);
  static const Color textTertiary = Color(0xFF8A94A2);

  /// True when the color is light enough that dark text is required on it.
  static bool needsDarkText(Color color) =>
      color.computeLuminance() > 0.55;
}

// ─────────────────────────────────────────────────────────────────────────
//  Geometry
// ─────────────────────────────────────────────────────────────────────────

abstract final class AppRadius {
  static const double card = 16;
  static const double cardLarge = 20;
  static const double control = 12;
  static const double chip = 999;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double screen = 20;
}

/// Consistent soft elevation for white cards on the grey background.
List<BoxShadow> appCardShadow({double opacity = 0.05}) => [
      BoxShadow(
        color: Color.fromRGBO(20, 35, 60, opacity),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];

// ─────────────────────────────────────────────────────────────────────────
//  Typography
// ─────────────────────────────────────────────────────────────────────────

abstract final class AppText {
  /// Page title inside the app bar.
  static const TextStyle screenTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Large hero heading (banners, dashboards).
  static const TextStyle headline = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Section title (e.g. "Quick Actions").
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Card title / important status line.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Main body copy.
  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  /// Supporting line under a title.
  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.35,
  );

  /// Metadata (timestamps, ids).
  static const TextStyle metadata = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );
}

// ─────────────────────────────────────────────────────────────────────────
//  Status / severity mappings (single source of truth)
// ─────────────────────────────────────────────────────────────────────────

/// low → green, medium → amber, high → orange, critical → red.
Color severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return AppColors.danger;
    case 'high':
      return AppColors.warning;
    case 'medium':
      return AppColors.amber;
    case 'low':
      return AppColors.success;
    default:
      return AppColors.neutral;
  }
}

/// Disaster lifecycle status color.
Color disasterStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'monitoring':
      return AppColors.amber;
    case 'active':
      return AppColors.danger;
    case 'contained':
      return AppColors.primary;
    case 'closed':
      return AppColors.neutral;
    default:
      return AppColors.neutral;
  }
}

/// Incident triage status color:
/// Reported → Verified → Triaged → Dispatched → Resolved (Invalid = neutral).
Color incidentStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'reported':
      return AppColors.amber;
    case 'verified':
    case 'triaged':
      return AppColors.primary;
    case 'dispatched':
      return AppColors.warning;
    case 'resolved':
      return AppColors.success;
    case 'rejected':
      return AppColors.neutral;
    default:
      return AppColors.neutral;
  }
}

/// Shelter status color (citizen-facing vocabulary: Available/Limited/Full/Closed).
Color shelterStatusColor(String status, {bool hasSpace = true, double? occupancyPercent}) {
  switch (status.toLowerCase()) {
    case 'closed':
      return AppColors.neutral;
    case 'full':
      return AppColors.danger;
    case 'active':
    default:
      if (!hasSpace) return AppColors.danger;
      if ((occupancyPercent ?? 0) >= 80) return AppColors.amber;
      return AppColors.success;
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Theme
// ─────────────────────────────────────────────────────────────────────────

/// Builds the global [ThemeData] used by [MaterialApp].
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: AppText.screenTitle,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control + 2),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control + 2),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.outlineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.outlineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.primary,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
      space: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.outline,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.outlineStrong,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      selectedLabelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11.5),
      elevation: 8,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────

/// Small rounded status chip used across alerts, incidents, shelters.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final IconData? icon;

  const StatusChip(
    this.label,
    this.color, {
    super.key,
    this.filled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withAlpha(24),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: filled ? null : Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header with optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.sectionTitle)),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// White rounded card with the standard border + soft shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderColor,
    this.color,
    this.onTap,
    this.radius = AppRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            color: color ?? AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? AppColors.outline),
            boxShadow: appCardShadow(),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Consistent icon container used in list rows and quick actions.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool soft;

  const IconBadge(
    this.icon,
    this.color, {
    super.key,
    this.size = 44,
    this.soft = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: soft ? color.withAlpha(26) : color.withAlpha(31),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// Human-friendly empty state. Explains what is happening and what to expect.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.iconColor = AppColors.textTertiary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Human-friendly loading state.
class LoadingState extends StatelessWidget {
  final String message;

  const LoadingState({super.key, this.message = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.6),
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: AppText.caption),
        ],
      ),
    );
  }
}

/// Human-friendly error state. Never exposes raw exception text.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message =
        'Something went wrong while loading this information. Please try again.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Couldn\u2019t load this',
              textAlign: TextAlign.center,
              style: AppText.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: AppText.caption),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Capacity bar with semantic color (green → amber → red).
class CapacityBar extends StatelessWidget {
  final double value; // 0..1
  final double height;

  const CapacityBar({
    super.key,
    required this.value,
    this.height = 7,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final color = clamped >= 0.99
        ? AppColors.danger
        : clamped >= 0.8
            ? AppColors.amber
            : AppColors.success;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: height,
        backgroundColor: AppColors.surfaceMuted,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Row for label/value metadata pairs.
class InfoRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const InfoRow(
    this.label,
    this.value, {
    super.key,
    this.icon,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: 7),
          ],
          SizedBox(
            width: 118,
            child: Text(label, style: AppText.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.body.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "Demo data" tag so seeded prototype records stay clearly labeled.
class DemoTag extends StatelessWidget {
  const DemoTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF7E57C2).withAlpha(23),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF7E57C2).withAlpha(90)),
      ),
      child: const Text(
        'DEMO',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Color(0xFF673AB7),
        ),
      ),
    );
  }
}

/// The app's shared emergency SOS action — a hold-to-activate button with
/// ring progress. The activation callback is provided by the parent; the
/// SOS *service* logic is untouched.
class EmergencySosButton extends StatefulWidget {
  final VoidCallback onSOSActivated;
  final double size;

  const EmergencySosButton({
    super.key,
    required this.onSOSActivated,
    this.size = 190,
  });

  @override
  State<EmergencySosButton> createState() => _EmergencySosButtonState();
}

class _EmergencySosButtonState extends State<EmergencySosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  bool _holding = false;
  double _progress = 0;
  Timer? _holdTimer;

  /// Unchanged from the original SOSButton: 2-second hold to confirm.
  static const int _holdDurationSeconds = 2;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    setState(() {
      _holding = true;
      _progress = 0;
    });

    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() => _progress += 0.05 / _holdDurationSeconds);

      // Haptic tick every 500ms while holding (unchanged behavior).
      if (timer.tick % 10 == 0) _vibrate();

      if (_progress >= 1.0) {
        timer.cancel();
        _activate();
      }
    });
  }

  void _activate() {
    _vibrate();
    _vibrate();
    widget.onSOSActivated();
    _cancelHold();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _holding = false;
      _progress = 0;
    });
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      // Releasing early cancels — only the 2s timer fires activation.
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final breathScale = _holding ? 1.0 : 1.0 + _breath.value * 0.04;
          return Transform.scale(
            scale: breathScale,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft glow
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.danger.withAlpha(38),
                    AppColors.danger.withAlpha(12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Progress ring
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.danger.withAlpha(46),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            // Core button
            Container(
              width: size - 26,
              height: size - 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.danger, AppColors.dangerDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withAlpha(96),
                    blurRadius: 26,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: size * 0.19,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.155,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
