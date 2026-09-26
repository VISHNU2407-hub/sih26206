import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/permissions_setup_service.dart';
import 'auth_screen.dart';
import 'home/main_screen.dart';
import 'permissions_setup_screen.dart';
import 'profile/profile_setup_screen.dart';

// -----------------------------------------------------------------------------
// Splash Screen Configuration
// -----------------------------------------------------------------------------
/// Centralized branding configuration for the splash screen.
///
/// To customize the look:
///   1. Set [logoAssetPath] to your logo asset (e.g. 'assets/images/logo.png')
///   2. Update [appName] and [primaryColor] to match your branding
///   3. Optionally set [tagline] to a short subtitle
///
/// No other code changes are required.
class SplashConfig {
  const SplashConfig._();

  /// Asset path for the SATS logo.
  /// The logo should be a square PNG at least 1024×1024 px for crisp
  /// rendering on high-DPI (2×/3×) Android and iOS displays.
  static const String logoAssetPath = 'assets/images/sats_logo.png';

  /// Application name displayed below the logo.
  static const String appName = 'SATS';

  /// Expanded acronym shown beneath the app name.
  /// SATS stands for Smart Assistance and Tracking System.
  static const String tagline = 'Smart Assistance and Tracking System';

  /// Short description shown beneath the tagline, explaining the app's
  /// purpose. Set to an empty string (`''`) to hide it.
  static const String description =
      'Your intelligent platform for community safety, '
      'emergency assistance, and village services.';

  /// Primary brand colour for text and progress indicator.
  static const Color primaryColor = Color(0xFF1565C0);

  /// Accent green used to highlight the SATS letters within the tagline.
  static const Color accentGreen = Color(0xFF2E7D32);

  /// Total duration of the splash entrance animation.
  ///
  /// 1.5 seconds keeps the splash snappy — each branded element (logo,
  /// app name, tagline, description) still stages in sequentially with
  /// the same smooth, premium transitions, but users reach the app
  /// faster, which matters for a safety/emergency app.
  static const Duration splashDuration = Duration(milliseconds: 1500);

  /// Base logo size in logical pixels — used as a reference for
  /// responsive sizing. The [SplashScreen] build method clamps this
  /// value between a small-screen minimum and a large-screen maximum
  /// based on [MediaQuery.size.shortestSide] so the logo always
  /// occupies a consistent visual proportion of the screen.
  static const double logoSize = 120;

  /// Minimum logo size on very small screens (e.g. 320 dp wide).
  static const double logoSizeMin = 130;

  /// Maximum logo size on large screens / tablets.
  static const double logoSizeMax = 220;

  /// Fraction of the screen's shortest side used to derive a
  /// responsive logo size. 38 % keeps the logo prominent and visible
  /// across all devices without overwhelming the layout.
  static const double logoSizeFraction = 0.38;

  /// Size of the circular progress indicator.
  static const double progressIndicatorSize = 28;

  /// Spacing scale factor: distances between elements are derived
  /// from `shortestSide × spacingScale` to ensure even whitespace
  /// on every screen size.
  static const double spacingScale = 0.05;

  /// Minimum vertical gap between elements (dp).
  static const double spacingMin = 24;

  /// Maximum vertical gap between elements (dp).
  static const double spacingMax = 56;
}

// -----------------------------------------------------------------------------
// Splash Screen
// -----------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  /// When `true`, the entrance animation is skipped and navigation
  /// happens immediately. Useful for post-login/post-logout redirects
  /// where the user has already seen the splash.
  final bool skipAnimation;

  const SplashScreen({super.key, this.skipAnimation = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mainController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _descriptionFade;
  late final Animation<double> _progressFade;

  /// When non-null, the splash screen displays an error state instead of
  /// the normal entrance animation. This avoids navigating away to another
  /// screen when there's a transient Firestore/network error — the user
  /// can retry directly from the splash.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSplashSequence();
  }

  // ---------------------------------------------------------------------------
  // Animation setup
  // ---------------------------------------------------------------------------
  void _initAnimations() {
    // -- Main controller: drives the entire entrance sequence --
    _mainController = AnimationController(
      vsync: this,
      duration: SplashConfig.splashDuration,
    );

    // Logo: fade in over the first 33 % of the duration (0–500ms).
    // Smooth ease-in so the logo gracefully appears as the first
    // element the user sees.
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.333, curve: Curves.easeInOut),
      ),
    );

    // Logo: scale from 0.3 → 1.0 over the first 40 % (0–600ms).
    // Slightly longer than the fade so the scale completes with a
    // polished ease-out tail. No elastic overshoot — in an
    // emergency/safety app, playful bounciness undermines trust.
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    // Title: fade in from 33 % → 67 % (500–1000ms).
    // Starts after the logo has fully appeared; the entire second
    // third of the animation is dedicated to reading the app name.
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.333, 0.667, curve: Curves.easeInOut),
      ),
    );

    // Tagline: fade in from 40 % → 60 % (600–900ms).
    // Appears shortly after the title begins so the two feel
    // connected; finishes well before the final static hold.
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.40, 0.60, curve: Curves.easeInOut),
      ),
    );

    // Description: fade in from 44 % → 60 % (660–900ms).
    // Appears after the tagline so the text builds sequentially.
    _descriptionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.44, 0.60, curve: Curves.easeInOut),
      ),
    );

    // Progress indicator: fade in from 47 % → 60 % (705–900ms).
    // Completes early so the final third of the animation is a
    // clean, static hold before navigation.
    _progressFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.47, 0.60, curve: Curves.easeInOut),
      ),
    );

    // Note: No pulse/breathing animation on the logo.
    // In an emergency/safety app, pulsing calls to mind heart-rate
    // monitors and urgency — the opposite of the calm, trustworthy
    // impression the startup experience should convey.
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  Future<void> _startSplashSequence() async {
    if (widget.skipAnimation) {
      _mainController.value = 1.0;
      if (!mounted) return;
      // Wait one frame so the SplashScreen fully renders in the widget
      // tree before navigating away — prevents a blank flash that can
      // occur when pushReplacement is called from initState.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      await _navigateBasedOnAuth(preloadedProfile: null);
      return;
    }

    // Start the entrance animation
    _mainController.forward();

    // Preload user profile during the animation window to hide network
    // latency. By the time the animation ends, the Firestore read will
    // likely have completed, saving ~100-500ms of post-splash waiting.
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final Future<UserModel?> profileFuture = currentUser != null
        ? _preloadUserProfile(currentUser.uid)
        : Future.value(null);

    await Future.delayed(SplashConfig.splashDuration);

    if (!mounted) return;
    await _navigateBasedOnAuth(preloadedProfile: await profileFuture);
  }

  /// Fetches the user's Firestore profile, swallowing errors so a failed
  /// preload degrades gracefully to an on-demand fetch in
  /// [_navigateBasedOnAuth].
  Future<UserModel?> _preloadUserProfile(String uid) async {
    try {
      return await FirestoreService().getUser(uid);
    } catch (_) {
      return null; // Will be re-fetched on demand in _navigateBasedOnAuth
    }
  }

  Future<void> _navigateBasedOnAuth({UserModel? preloadedProfile}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      // Not logged in → auth screen
      if (user == null) {
        debugPrint('SplashScreen: No authenticated user → AuthScreen');
        _navigateTo(const AuthScreen());
        return;
      }

      // Logged in – check profile existence.
      // Use preloaded profile (fetched during animation) if available;
      // otherwise fall back to an on-demand fetch.
      UserModel? profile;
      try {
        profile = preloadedProfile ??
            await FirestoreService().getUser(user.uid);
      } on FirebaseException catch (e) {
        // Firestore permission / network error — log details and show
        // an in-place retry UI on the splash screen instead of
        // navigating away to AuthScreen.
        debugPrint('SplashScreen: FirestoreException fetching profile '
            '(code=${e.code}, message=${e.message})');
        if (mounted) {
          setState(() {
            _errorMessage = 'Could not load profile: ${e.message ?? e.code}';
          });
        }
        return;
      } catch (e) {
        // Non-Firebase error (e.g. format/parse error in UserModel).
        debugPrint('SplashScreen: Unexpected error fetching profile: $e');
        if (mounted) {
          _navigateTo(const AuthScreen());
        }
        return;
      }

      // No profile → profile setup
      if (profile == null) {
        debugPrint(
            'SplashScreen: No profile found for ${user.uid} → ProfileSetupScreen');
        _navigateTo(const ProfileSetupScreen());
        return;
      }

      // Profile exists → check if permissions setup is complete
      final bool permissionsDone = await PermissionsSetupService.isCompleted();

      if (!permissionsDone) {
        debugPrint(
            'SplashScreen: Profile exists, permissions not done → PermissionsSetupScreen');
        // Navigate using route context so the callback still works
        // after the splash screen is disposed.
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (routeContext) => PermissionsSetupScreen(
              onCompleted: () {
                Navigator.of(routeContext).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                );
              },
            ),
          ),
        );
        return;
      }

      // Everything ready → MainScreen
      debugPrint('SplashScreen: Everything ready → MainScreen');
      _navigateTo(const MainScreen());
    } catch (e) {
      // Catch-all for any unexpected error in the outer logic.
      debugPrint('SplashScreen: Unhandled navigation error: $e');
      if (mounted) _navigateTo(const AuthScreen());
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Responsive dimension helpers
  // ---------------------------------------------------------------------------

  /// Responsive logo size, clamped to [SplashConfig.logoSizeMin] …
  /// [SplashConfig.logoSizeMax] and derived from a fraction of the
  /// screen's shortest side so the logo occupies a consistent visual
  /// footprint on phones, phablets, and tablets.
  double _responsiveLogoSize(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final computed = shortestSide * SplashConfig.logoSizeFraction;
    return computed.clamp(SplashConfig.logoSizeMin, SplashConfig.logoSizeMax);
  }

  /// Responsive vertical gap between elements. Uses [_spacingScale]
  /// fraction of the shortest side, clamped to a comfortable range.
  double _responsiveSpacing(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final computed = shortestSide * SplashConfig.spacingScale;
    return computed.clamp(SplashConfig.spacingMin, SplashConfig.spacingMax);
  }

  /// Responsive app-name font size — scales from 22 dp (small phone)
  /// to 34 dp (large tablet) based on screen width.
  double _responsiveTitleSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Map 360 dp → 24 dp, 600 dp → 32 dp, with a comfortable range.
    return (width * 0.065).clamp(24.0, 34.0);
  }

  /// Responsive tagline font size.
  double _responsiveTaglineSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width * 0.04).clamp(14.0, 18.0);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  /// Retry the splash sequence after an error. Resets the error state
  /// and re-runs the entire auth-check / navigation logic.
  Future<void> _retry() async {
    setState(() {
      _errorMessage = null;
    });
    // Reset the controller before forwarding so the entrance animation
    // replays (an already-completed controller ignores forward()).
    _mainController.reset();
    _mainController.forward();
    await Future.delayed(SplashConfig.splashDuration);
    if (!mounted) return;
    await _navigateBasedOnAuth(preloadedProfile: null);
  }

  @override
  Widget build(BuildContext context) {
    final double logoSize = _responsiveLogoSize(context);
    final double spacing = _responsiveSpacing(context);
    final double titleSize = _responsiveTitleSize(context);
    final double taglineSize = _responsiveTaglineSize(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _errorMessage != null
            ? _buildErrorState()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ---- Animated Logo ----
                  // Fades in and scales up smoothly without pulse or elastic
                  // bounce — calm, professional, appropriate for a safety app.
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildLogo(logoSize),
                  ),

                  SizedBox(height: spacing),

                  // ---- App Name ----
                  FadeTransition(
                    opacity: _titleFade,
                    child: Text(
                      SplashConfig.appName,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: SplashConfig.primaryColor,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // ---- Tagline with SATS Highlighting (optional) ----
                  if (SplashConfig.tagline.isNotEmpty) ...[
                    SizedBox(height: spacing * 0.2),
                    FadeTransition(
                      opacity: _taglineFade,
                      child: _buildHighlightedTagline(taglineSize),
                    ),
                  ],

                  // ---- Description (optional) ----
                  if (SplashConfig.description.isNotEmpty) ...[
                    SizedBox(height: spacing * 0.15),
                    FadeTransition(
                      opacity: _descriptionFade,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.1,
                        ),
                        child: Text(
                          SplashConfig.description,
                          style: TextStyle(
                            fontSize: taglineSize - 2,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: spacing * 1.2),

                  // ---- Progress Indicator ----
                  FadeTransition(
                    opacity: _progressFade,
                    child: const SizedBox(
                      width: SplashConfig.progressIndicatorSize,
                      height: SplashConfig.progressIndicatorSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SplashConfig.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Full-screen error state shown when the splash screen cannot fetch
  /// the user's profile (e.g. Firestore permission / network error).
  /// The user can tap "Retry" to re-run the auth check.
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Error icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Colors.red.shade300,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Connection Issue',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SplashConfig.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () {
              // Sign out and go to auth screen so user can try
              // signing in with a different account.
              FirebaseAuth.instance.signOut();
              if (mounted) {
                _navigateTo(const AuthScreen());
              }
            },
            child: Text(
              'Sign in with a different account',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Image.asset(
      SplashConfig.logoAssetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  /// Builds the tagline text with SATS letters highlighted in the app's
  /// accent green colour using [RichText]/[TextSpan].
  ///
  /// Renders:
  ///   [S]mart [A]ssistance and [T]racking [S]ystem
  /// where S, A, T, S are coloured [SplashConfig.accentGreen].
  Widget _buildHighlightedTagline(double fontSize) {
    const String full = 'Smart Assistance and Tracking System';

    // The letters to highlight — their positions in the string above.
    const highlightPositions = <int>{0, 6, 21, 30};

    final List<TextSpan> spans = [];
    for (int i = 0; i < full.length; i++) {
      final String char = full[i];
      final bool isSatsLetter = highlightPositions.contains(i);

      spans.add(
        TextSpan(
          text: char,
          style: TextStyle(
            fontSize: fontSize,
            color: isSatsLetter ? SplashConfig.accentGreen : Colors.grey[600],
            fontWeight: isSatsLetter ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }
}
