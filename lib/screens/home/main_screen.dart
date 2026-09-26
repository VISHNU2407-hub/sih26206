import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/profile_image_widget.dart';
import '../profile/profile_screen.dart';
import 'disaster_home_screen.dart';
import 'help_screen.dart';
import 'notifications_screen.dart';
import 'report_incident_screen.dart';
import '../authority/disaster_dashboard_screen.dart';
import '../authority/authority_incident_feed_screen.dart';
import '../authority/authority_shelters_screen.dart';
import '../authority/authority_alerts_screen.dart';
import '../sos_screen.dart';
import '../../utils/roles.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  int _currentIndex = 0;
  UserModel? _currentUser;

  /// Authority roles (village/district authority, legacy admin, rescue)
  /// get the Disaster Command navigation; citizens keep the
  /// Alerts / Report / Help experience.
  bool get _isAuthority =>
      _currentUser != null &&
      (AppRoles.isAuthority(_currentUser!.role) ||
          _currentUser!.role == AppRoles.rescue);

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userData = await _firestoreService.getUser(user.uid);
        if (mounted) {
          setState(() {
            _currentUser = userData;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Couldn\u2019t load your account. Some details may be out of '
                'date — pull to refresh or sign in again.'),
          ),
        );
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Translucent app bar for the citizen Home tab only — brand mark,
  /// notifications with unread badge and profile avatar.
  PreferredSizeWidget _buildCitizenHomeBar() {
    return AppBar(
      title: Text(
        AppConstants.appName,
        style: AppText.screenTitle.copyWith(
          color: AppColors.primary,
          fontSize: 19,
        ),
      ),
      centerTitle: false,
      actions: [
        StreamBuilder<int>(
          stream: _firestoreService.getUnreadNotificationCount(
            userId: _auth.currentUser!.uid,
            userMandal: _currentUser!.mandal,
          ),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationsScreen(
                          currentUser: _currentUser!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(user: _currentUser!),
              ),
            );
            if (result == true && mounted) {
              _loadCurrentUser();
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileImageWidget(
              imageUrl: _currentUser!.photoUrl,
              name: _currentUser!.name,
              size: 34,
              showBorder: true,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: LoadingState(message: 'Loading your account…'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      // Outer bar only for the citizen Home tab (tab 0). The other citizen
      // tabs provide their own titled AppBars; authority screens manage
      // their own chrome entirely.
      appBar: (!_isAuthority && _currentIndex == 0) ? _buildCitizenHomeBar() : null,
      body: _isAuthority
          ? IndexedStack(
                index: _currentIndex,
                children: [
                  DisasterDashboardScreen(currentUser: _currentUser!),
                  AuthorityIncidentFeedScreen(currentUser: _currentUser!),
                  AuthoritySheltersScreen(user: _currentUser!),
                  AuthorityAlertsScreen(user: _currentUser!),
                ],
              )
          : IndexedStack(
              index: _currentIndex,
              children: [
                DisasterHomeScreen(user: _currentUser!),
                ReportIncidentScreen(user: _currentUser!),
                SOSScreen(user: _currentUser!),
                HelpScreen(user: _currentUser!),
              ],
            ),
      bottomNavigationBar: _isAuthority
          ? NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primary.withAlpha(26),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppText.metadata.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)
                      : AppText.metadata,
                ),
              ),
              child: NavigationBar(
                height: 68,
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabTapped,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.monitor_heart_outlined),
                    selectedIcon: Icon(Icons.monitor_heart_rounded),
                    label: 'Command',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.feed_outlined),
                    selectedIcon: Icon(Icons.feed_rounded),
                    label: 'Incidents',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.night_shelter_outlined),
                    selectedIcon: Icon(Icons.night_shelter_rounded),
                    label: 'Shelters',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.campaign_outlined),
                    selectedIcon: Icon(Icons.campaign_rounded),
                    label: 'Alerts',
                  ),
                ],
              ),
            )
          : _CitizenNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
    );
  }
}

/// Citizen bottom navigation — the SOS slot is visually distinct (red pill
/// behind the icon) so the emergency action reads instantly.
class _CitizenNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CitizenNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final destinations = <(IconData, IconData, String)>[
      (
        Icons.shield_outlined,
        Icons.shield_rounded,
        'Home'
      ),
      (
        Icons.report_outlined,
        Icons.report_rounded,
        'Report'
      ),
      (
        Icons.emergency,
        Icons.emergency,
        'SOS'
      ),
      (
        Icons.support_agent_outlined,
        Icons.support_agent_rounded,
        'Get Help'
      ),
    ];

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      selectedFontSize: 11.5,
      unselectedFontSize: 11.5,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      items: [
        for (var i = 0; i < destinations.length; i++)
          BottomNavigationBarItem(
            icon: i == 2
                ? _SosNavIcon(active: currentIndex == i)
                : Icon(
                    currentIndex == i ? destinations[i].$2 : destinations[i].$1,
                  ),
            label: destinations[i].$3,
          ),
      ],
    );
  }
}

/// Red SOS pill icon for the citizen bottom navigation slot.
class _SosNavIcon extends StatelessWidget {
  final bool active;

  const _SosNavIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? AppColors.danger
            : AppColors.danger.withAlpha(20),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        'SOS',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: active ? Colors.white : AppColors.danger,
        ),
      ),
    );
  }
}
