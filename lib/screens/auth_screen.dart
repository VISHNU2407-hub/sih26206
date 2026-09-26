import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential? userCredential = await _authService
          .signInWithGoogle();

      if (userCredential != null && mounted) {
        // Navigate to SplashScreen which handles post-auth routing
        // (checking profile existence, permissions, etc.)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const SplashScreen(skipAnimation: true),
          ),
          (route) => false,
        );
      } else if (mounted) {
        // Sign in failed or was cancelled
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in was cancelled or failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        // Normalise to lowercase — firebase_auth 4.x can return either
        // kebab-case ("account-exists-with-different-credential") or the
        // legacy UPPER_SNAKE_CASE format depending on the Android SDK.
        switch (e.code.toLowerCase()) {
          case 'account-exists-with-different-credential':
            message =
                'An account already exists with this email using '
                'a different sign-in method. Please try a different sign-in option.';
            break;
          case 'invalid-credential':
            message = 'Sign-in failed. Please try again.';
            break;
          case 'user-disabled':
            message = 'This account has been disabled.';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Please try again later.';
            break;
          case 'operation-not-allowed':
            message = 'Google Sign-In is not enabled. Please contact support.';
            break;
          default:
            message = 'Sign-in failed: ${e.message ?? e.code}';
        }
        debugPrint(
          'LoginError[FirebaseAuthException] code=${e.code}: $message',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        String message;
        // Google Play Services DEVELOPER_ERROR (code 10) — almost always
        // a SHA-1 fingerprint mismatch in the Firebase Console.
        if (e.code == 'sign_in_failed' &&
            (e.message?.contains('ApiException: 10') ?? false)) {
          message =
              'Sign-in failed due to a configuration issue. '
              'Please ensure this app\'s SHA-1 fingerprint is registered '
              'in the Firebase Console (Project Settings > Your apps > Android).';
        } else if (e.code == 'network_error') {
          message = 'Network error. Please check your internet connection.';
        } else {
          message = 'Sign-in failed: ${e.message ?? e.code}';
        }
        debugPrint('LoginError[PlatformException] code=${e.code}: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if Firebase authentication succeeded despite the plugin exception.
        // This handles the known pigeon type cast bug in firebase_auth/google_sign_in
        // where authentication succeeds but the plugin throws a type cast error.
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          debugPrint(
            'LoginError[Unknown] $e - but Firebase auth succeeded, continuing navigation',
          );
          // Navigate to SplashScreen which handles post-auth routing
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const SplashScreen(skipAnimation: true),
            ),
            (route) => false,
          );
        } else {
          final message = 'An unexpected error occurred. Please try again.';
          debugPrint('LoginError[Unknown] $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Builds the SATS tagline with S, A, T, S letters highlighted in the
  /// app's accent green colour via [RichText]/[TextSpan].
  ///
  /// This mirrors the shared logic in [SplashScreen._buildHighlightedTagline].
  /// A future refactor could extract the tagline string and positions to a
  /// shared constant, eliminating the duplication entirely.
  Widget _buildHighlightedTagline(double fontSize) {
    const String full = 'Smart Assistance and Tracking System';
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
            color: isSatsLetter
                ? SplashConfig.accentGreen
                : Colors.grey[600],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top spacing
                const Spacer(flex: 2),

                // App Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/sats_logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App Title
                const Text(
                  'SATS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Subtitle with SATS Highlighting
                _buildHighlightedTagline(18),

                const SizedBox(height: 12),

                // Description
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Your intelligent platform for community safety, '
                    'emergency assistance, and village services.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 48),

                // Welcome Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sign in to access village services and connect with your community',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Google Sign-In Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Image.asset(
                            'assets/images/google_logo.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.account_circle,
                                color: Colors.white,
                                size: 24,
                              );
                            },
                          ),
                    label: Text(
                      _isLoading ? 'Signing in...' : 'Continue with Google',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF1565C0).withOpacity(0.3),
                    ),
                  ),
                ),

                const Spacer(),

                // Terms and Privacy
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
