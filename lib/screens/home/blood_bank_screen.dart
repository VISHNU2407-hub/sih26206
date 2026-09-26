import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/user_model.dart';
import '../../models/blood_bank_model.dart';
import '../../services/firestore_service.dart';
import '../../services/blood_bank_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/profile_image_widget.dart';

class BloodBankScreen extends StatefulWidget {
  const BloodBankScreen({super.key});

  @override
  State<BloodBankScreen> createState() => _BloodBankScreenState();
}

class _BloodBankScreenState extends State<BloodBankScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // ── Tab controller ──
  late final TabController _tabController;

  // ── Blood group options ──
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // ── Donor state (unchanged) ──
  String? _selectedBloodGroup;
  bool _isSearching = false;
  List<UserModel> _donors = [];
  StreamSubscription? _donorSubscription;
  String? _errorMessage;
  UserModel? _currentUser;

  // ── Location state (shared) ──
  Position? _currentPosition;
  bool _isFetchingLocation = false;
  String? _locationErrorMessage;

  // ── Blood banks state ──
  final TextEditingController _bloodBankSearchController = TextEditingController();
  String _bloodBankSearchQuery = '';
  List<BloodBank> _bloodBanks = [];
  List<BloodBank> _filteredBloodBanks = [];
  bool _isLoadingBloodBanks = false;
  String? _bloodBanksErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurrentUser();
    _requestLocationAndFetch();
  }

  @override
  void dispose() {
    _donorSubscription?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _bloodBankSearchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _tabController.index == 1 &&
        _bloodBanks.isEmpty &&
        !_isLoadingBloodBanks) {
      _loadBloodBanks();
    }
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
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _requestLocationAndFetch() async {
    setState(() {
      _isFetchingLocation = true;
      _locationErrorMessage = null;
    });

    try {
      // Request location permission
      final status = await Permission.location.request();

      if (status.isGranted) {
        // Permission granted, fetch current location
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _currentPosition = position;
            _isFetchingLocation = false;
          });
        }

        // If blood banks were already loaded with alphabetical fallback
        // (because location was pending), re-sort them by distance now.
        if (_bloodBanks.isNotEmpty) {
          BloodBankService.sortByDistance(
            banks: _bloodBanks,
            userLat: position.latitude,
            userLng: position.longitude,
          );
          if (mounted) {
            setState(() {}); // trigger rebuild with updated distances & order
          }
          debugPrint(
            'Blood banks re-sorted by distance after location acquired',
          );
        } else if (!_isLoadingBloodBanks) {
          // Tab was never visited — pre-load blood banks now with location,
          // so data is ready with correct distance sort when user switches tab.
          _loadBloodBanks();
        }

        // Update user's location in Firebase
        await _updateUserLocationInFirebase(position);
      } else {
        // Permission denied
        if (mounted) {
          setState(() {
            _isFetchingLocation = false;
            _locationErrorMessage = 'Enable location for nearest results';
          });
        }
        debugPrint('Location permission denied');
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _locationErrorMessage = 'Enable location for nearest results';
        });
      }
    }
  }

  Future<void> _updateUserLocationInFirebase(Position position) async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await _firestoreService.updateUserLocation(
          user.uid,
          position.latitude,
          position.longitude,
        );
        debugPrint(
          'User location updated in Firebase: ${position.latitude}, ${position.longitude}',
        );
      }
    } catch (e) {
      debugPrint('Error updating user location in Firebase: $e');
    }
  }

  // ── Blood banks loading ──

  Future<void> _loadBloodBanks() async {
    setState(() {
      _isLoadingBloodBanks = true;
      _bloodBanksErrorMessage = null;
    });

    try {
      final banks = await BloodBankService.loadBloodBanks();

      List<BloodBank> sortedBanks;
      if (_currentPosition != null) {
        sortedBanks = BloodBankService.sortByDistance(
          banks: banks,
          userLat: _currentPosition!.latitude,
          userLng: _currentPosition!.longitude,
        );
      } else {
        // No location available — show unsorted (alphabetical fallback)
        sortedBanks = List.from(banks);
        sortedBanks.sort((a, b) => a.name.compareTo(b.name));
      }

      if (mounted) {
        setState(() {
          _bloodBanks = sortedBanks;
          _filteredBloodBanks = sortedBanks;
          _isLoadingBloodBanks = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blood banks: $e');
      if (mounted) {
        setState(() {
          _bloodBanksErrorMessage = 'Failed to load blood banks. Please try again.';
          _isLoadingBloodBanks = false;
        });
      }
    }
  }

  // ── Shared helpers ──

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m away';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} km away';
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      AppHelpers.showErrorSnackBar(context, 'Could not launch phone dialer');
    }
  }

  Future<void> _openDirections(double latitude, double longitude) async {
    // Try Google Maps navigation app first
    final navigationUri = Uri.parse(
      'google.navigation:q=$latitude,$longitude&mode=d',
    );
    if (await canLaunchUrl(navigationUri)) {
      await launchUrl(navigationUri);
      return;
    }

    // Fallback: open Google Maps in directions mode via web URL
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else {
      AppHelpers.showErrorSnackBar(context, 'Could not open maps');
    }
  }

  // ── Donor search (unchanged) ──

  Future<void> _searchDonors() async {
    if (_selectedBloodGroup == null || _selectedBloodGroup!.isEmpty) {
      AppHelpers.showErrorSnackBar(context, 'Please select a blood group');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _donors = [];
    });

    try {
      // Debug prints
      debugPrint('Blood Bank Search:');
      debugPrint('  Selected Blood Group: $_selectedBloodGroup');
      debugPrint('  Current User ID: ${_auth.currentUser?.uid}');

      final stream = _firestoreService.getBloodDonors(
        _selectedBloodGroup!,
        _auth.currentUser?.uid ?? '',
      );

      await _donorSubscription?.cancel();
      _donorSubscription = stream.listen(
        (snapshot) {
          if (!mounted) return;

          debugPrint('  Firestore Snapshot Size: ${snapshot.docs.length}');

          // Convert all documents to UserModel
          final allDonors = snapshot.docs
              .map(
                (doc) => UserModel.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

          debugPrint('  All Blood Donors from Firestore: ${allDonors.length}');
          for (var donor in allDonors) {
            debugPrint(
              '    - ${donor.name}, Blood: ${donor.bloodGroup}, Mandal: ${donor.mandal}, isBloodDonor: ${donor.isBloodDonor}',
            );
          }

          // Filter locally: exclude current user (bloodGroup already filtered by Firestore)
          final filteredDonors = allDonors.where((donor) {
            final notCurrentUser = donor.uid != (_auth.currentUser?.uid);

            debugPrint(
              '    Filtering ${donor.name}: notCurrentUser=$notCurrentUser',
            );

            return notCurrentUser;
          }).toList();

          debugPrint('  Filtered Donors Count: ${filteredDonors.length}');

          // Calculate distances and sort if location is available
          List<UserModel> sortedDonors = filteredDonors;
          if (_currentPosition != null) {
            sortedDonors = filteredDonors.map((donor) {
              return donor.copyWith(
                latitude: donor.latitude,
                longitude: donor.longitude,
              );
            }).toList();

            // Sort by distance (nearest first)
            sortedDonors.sort((a, b) {
              double distanceA = 0.0;
              double distanceB = 0.0;

              if (a.latitude != null && a.longitude != null) {
                distanceA = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  a.latitude!,
                  a.longitude!,
                );
              }

              if (b.latitude != null && b.longitude != null) {
                distanceB = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  b.latitude!,
                  b.longitude!,
                );
              }

              return distanceA.compareTo(distanceB);
            });

            debugPrint('  Donors sorted by distance');
          }

          setState(() {
            _donors = sortedDonors;
            _isSearching = false;
          });
        },
        onError: (error) {
          debugPrint('  Firestore Error: $error');
          if (mounted) {
            setState(() {
              _errorMessage = error.toString();
              _isSearching = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('  Search Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  String _formatWhatsAppNumber(String phoneNumber) {
    // Convert to String
    final phoneStr = phoneNumber.toString();

    // Remove ALL non-digit characters using regex
    final cleanedPhone = phoneStr.replaceAll(RegExp(r'[^\d]'), '');

    // If cleaned number length == 10, prepend 91
    if (cleanedPhone.length == 10) {
      return '91$cleanedPhone';
    }

    // If number already starts with 91 AND length == 12, keep unchanged
    if (cleanedPhone.length == 12 && cleanedPhone.startsWith('91')) {
      return cleanedPhone;
    }

    // Return cleaned number as-is (will be validated later)
    return cleanedPhone;
  }

  Future<void> _openWhatsApp(UserModel donor) async {
    if (_currentUser == null) {
      AppHelpers.showErrorSnackBar(context, 'User data not available');
      return;
    }

    // Show dialog to get hospital/location
    final locationController = TextEditingController();

    final location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hospital / Location'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(
            hintText: 'Enter hospital or location name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (locationController.text.trim().isNotEmpty) {
                Navigator.pop(context, locationController.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (location == null || location.isEmpty) return;

    // Format phone number using dedicated helper function
    final formattedNumber = _formatWhatsAppNumber(donor.phone);

    // Validation: Check formattedNumber.length >= 12
    if (formattedNumber.length < 12) {
      AppHelpers.showErrorSnackBar(context, 'Invalid phone number');
      return;
    }

    // Debug print before launch
    debugPrint('FINAL WHATSAPP NUMBER: $formattedNumber');

    // Generate WhatsApp message
    final message =
        '''Hello, I urgently need $_selectedBloodGroup blood.\n\nHospital/Location: $location\n\nPlease contact me as soon as possible.\n\nMy contact number: ${_currentUser!.phone}''';

    // Open WhatsApp with prefilled message
    final whatsappUrl = Uri.parse(
      'https://wa.me/$formattedNumber?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(
      whatsappUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open WhatsApp')));
    }
  }

  // ═══════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Blood Support',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Shared header ──
          _buildHeader(),

          // ── Tab bar ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade700,
              indicator: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Donors'),
                Tab(text: 'Blood Banks'),
              ],
            ),
          ),

          // ── Tab content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDonorsContent(),
                _buildBloodBanksContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared header ──

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD32F2F), Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bloodtype,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Blood Support',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Donors & blood banks near you',
                    style: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 13,
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

  // ═══════════════════════════════════════════
  //  DONORS TAB (unchanged logic)
  // ═══════════════════════════════════════════

  Widget _buildDonorsContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Blood Group Dropdown
        const Text(
          'Blood Group',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBloodGroup,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Select blood group'),
              ),
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              items: _bloodGroups.map((group) {
                return DropdownMenuItem<String>(
                  value: group,
                  child: Text(group, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBloodGroup = value;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Location message
        if (_locationErrorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_off,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationErrorMessage!,
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (_isFetchingLocation)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Fetching location...',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Search Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSearching ? null : _searchDonors,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSearching
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : const Text(
                    'Search Donors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 32),

        // Results Section
        if (_isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $_errorMessage',
                    style: TextStyle(color: Colors.red[300]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_donors.isEmpty && _selectedBloodGroup != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No donors found for selected filters',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else if (_donors.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${_donors.length} donor${_donors.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ..._donors.map((donor) => _buildDonorCard(donor)),
            ],
          ),
      ],
    );
  }

  Widget _buildDonorCard(UserModel donor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Donor info row
            Row(
              children: [
                // Profile image
                ProfileImageWidget(
                  imageUrl: donor.photoUrl,
                  name: donor.name,
                  size: 56,
                  showBorder: false,
                ),
                const SizedBox(width: 16),
                // Name and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donor.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD32F2F),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              donor.bloodGroup,
                              style: const TextStyle(
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              donor.village,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Distance display
                      if (_currentPosition != null &&
                          donor.latitude != null &&
                          donor.longitude != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.near_me,
                                size: 12,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDistance(
                                  Geolocator.distanceBetween(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                    donor.latitude!,
                                    donor.longitude!,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(donor.phone),
                    icon: const Icon(Icons.call, size: 20),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openWhatsApp(donor),
                    icon: const Icon(Icons.chat, size: 20),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Blood bank search ──

  void _onBloodBankSearchChanged(String query) {
    setState(() {
      _bloodBankSearchQuery = query.trim().toLowerCase();
      if (_bloodBankSearchQuery.isEmpty) {
        _filteredBloodBanks = _bloodBanks;
      } else {
        _filteredBloodBanks = _bloodBanks.where((bank) {
          return bank.name.toLowerCase().contains(_bloodBankSearchQuery) ||
              bank.address.toLowerCase().contains(_bloodBankSearchQuery) ||
              bank.hospitalType.toLowerCase().contains(_bloodBankSearchQuery);
        }).toList();
      }
    });
  }

  // ═══════════════════════════════════════════
  //  BLOOD BANKS TAB
  // ═══════════════════════════════════════════

  Widget _buildBloodBanksContent() {
    if (_isLoadingBloodBanks) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading blood banks...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_bloodBanksErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(
                _bloodBanksErrorMessage!,
                style: TextStyle(color: Colors.red[300], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _bloodBanksErrorMessage = null;
                  });
                  _loadBloodBanks();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_bloodBanks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_hospital, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No blood banks available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please check back later',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    // Blood banks loaded — show list
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          '${_bloodBanks.length} blood bank${_bloodBanks.length == 1 ? '' : 's'} near you',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        if (_currentPosition == null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enable location to see nearest blood banks first',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ── Search field ──
        TextField(
          controller: _bloodBankSearchController,
          onChanged: _onBloodBankSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by name, address or type...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _bloodBankSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _bloodBankSearchController.clear();
                      _onBloodBankSearchChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (_filteredBloodBanks.isEmpty && _bloodBankSearchQuery.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No blood banks match "$_bloodBankSearchQuery"',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._filteredBloodBanks.map((bank) => _buildBloodBankCard(bank)),
      ],
    );
  }

  Widget _buildBloodBankCard(BloodBank bank) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + distance
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    bank.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (bank.distanceKm > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.near_me,
                          size: 12,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          BloodBankService.formatDistance(bank.distanceKm),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bank.address,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Hospital type badge
            if (bank.hospitalType.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD32F2F).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  bank.hospitalType,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Phone number
            if (bank.hasPhone) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    bank.phone,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        bank.hasPhone ? () => _makeCall(bank.phone) : null,
                    icon: const Icon(Icons.call, size: 20),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: bank.hasValidCoordinates
                        ? () => _openDirections(bank.latitude, bank.longitude)
                        : null,
                    icon: const Icon(Icons.directions, size: 20),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
