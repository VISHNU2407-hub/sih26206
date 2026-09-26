import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/guardian_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/roles.dart';
import '../../widgets/mandal_autocomplete.dart';
import '../../widgets/district_autocomplete.dart';

import '../../widgets/profile_image_widget.dart';
import '../permissions_setup_screen.dart';
import '../auth_screen.dart';
import 'guardian_setup_screen.dart';

/// SATS Disaster — profile.
///
/// Premium, calm account surface: identity header, account information,
/// emergency contacts and the permission entry point. Authority geographic
/// scope stays provisioned/read-only exactly as before.
class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isUploadingImage = false;

  /// Guards the Save button against double-taps firing two `updateUser` writes.
  bool _isSavingProfile = false;

  /// Emergency contacts are fetched once per screen instance and re-fetched
  /// only on explicit retry, not on every `setState`.
  late Future<List<GuardianModel>> _guardiansFuture;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _mandalController;
  late TextEditingController _villageController;
  late TextEditingController _stateController;
  late TextEditingController _districtController;
  late TextEditingController _bloodGroupController;
  DateTime? _dateOfBirth;
  bool _isBloodDonor = false;
  UserModel? _currentUser;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool get _isAuthority =>
      AppRoles.isAuthority(_currentUser?.role ?? 'citizen');

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _mandalController = TextEditingController(text: widget.user.mandal);
    _villageController = TextEditingController(text: widget.user.village);
    _stateController = TextEditingController(text: widget.user.state);
    _districtController = TextEditingController(text: widget.user.district);
    _dateOfBirth = widget.user.dateOfBirth;
    _bloodGroupController = TextEditingController(text: widget.user.bloodGroup);
    _isBloodDonor = widget.user.isBloodDonor;
    // Held in a field (not created inside build) so ordinary rebuilds do not
    // re-issue a Firestore fetch and re-show the spinner.
    _guardiansFuture = _loadGuardians();
  }

  /// Re-fetches the emergency contacts after a failed load.
  void _reloadGuardians() {
    setState(() => _guardiansFuture = _loadGuardians());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _mandalController.dispose();
    _villageController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.xl),
            _buildAccountSection(),
            const SizedBox(height: AppSpacing.xl),
            _buildGuardiansSection(),
            const SizedBox(height: AppSpacing.xl),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  // ── Identity header ─────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(66),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ProfileImageWidget(
                imageUrl: _currentUser?.photoUrl,
                name: _currentUser?.name ?? 'User',
                size: 84,
                showBorder: true,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap:
                        _isUploadingImage ? null : _pickAndUploadImage,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _isUploadingImage
                            ? AppColors.neutral
                            : Colors.white,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploadingImage
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded,
                              color: AppColors.primary, size: 16),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser?.name ?? 'User',
                  style: AppText.headline.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  AppRoles.label(_currentUser?.role ?? 'citizen'),
                  style: AppText.caption.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((_currentUser?.village ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationLine(),
                          style: AppText.metadata
                              .copyWith(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _locationLine() {
    final parts = <String>[
      if ((_currentUser?.village ?? '').isNotEmpty) _currentUser!.village,
      if ((_currentUser?.mandal ?? '').isNotEmpty) _currentUser!.mandal,
    ];
    return parts.isEmpty ? '' : parts.join(' • ');
  }

  // ── Account information ────────────────────────────────────────────────

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Account Information'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm + 2,
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.person_rounded,
                'Full Name',
                _currentUser?.name ?? '',
                _nameController,
              ),
              _buildInfoRow(
                Icons.phone_rounded,
                'Phone Number',
                AppHelpers.formatPhoneNumber(_currentUser?.phone ?? ''),
                _phoneController,
              ),
              _buildInfoRow(
                Icons.public_rounded,
                'State',
                _currentUser?.state ?? '',
                _stateController,
              ),
              // Authority geographic scope is provisioned — not
              // user-editable. Same behavior as before, clearer hint.
              _buildInfoRow(
                Icons.map_rounded,
                'District',
                _currentUser?.district ?? '',
                _isAuthority ? null : _districtController,
                _isAuthority,
              ),
              _buildInfoRow(
                Icons.location_city_rounded,
                'Mandal',
                _currentUser?.mandal ?? '',
                _isAuthority ? null : _mandalController,
                _isAuthority,
              ),
              _buildInfoRow(
                Icons.home_rounded,
                'Village',
                _currentUser?.village ?? '',
                _isAuthority ? null : _villageController,
                _isAuthority,
              ),
              _buildDateOfBirthRow(),
              _buildInfoRow(
                Icons.bloodtype_rounded,
                'Blood Group',
                _currentUser?.bloodGroup ?? '',
                _bloodGroupController,
              ),
              _buildBloodDonorRow(),
            ],
          ),
        ),
        if (_isEditing && _isAuthority) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your district, mandal and village are set by the system '
                  'and cannot be changed.',
                  style: AppText.metadata,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, [
    TextEditingController? controller,
    bool locked = false,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: AppText.metadata),
                    if (locked) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.lock_outline_rounded,
                          size: 12, color: AppColors.textTertiary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (_isEditing && controller != null)
                  label == 'Mandal'
                      ? MandalAutocomplete(
                          controller: controller,
                          labelText: null,
                          hintText: 'Search mandal...',
                          prefixIcon: null,
                          validator: (val) =>
                              val?.isEmpty ?? true ? 'Required' : null,
                          textInputAction: TextInputAction.next,
                        )
                      : label == 'District'
                          ? DistrictAutocomplete(
                              controller: controller,
                              labelText: null,
                              hintText: 'Search district...',
                              prefixIcon: null,
                              validator: (val) =>
                                  val?.isEmpty ?? true ? 'Required' : null,
                              textInputAction: TextInputAction.next,
                            )
                          : TextField(
                              controller: controller,
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                              ),
                            )
                else
                  Text(
                    value.isEmpty ? 'Not set' : value,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateOfBirthRow() {
    final dob = _dateOfBirth;
    final age = AppHelpers.calculateAge(dob) ??
        int.tryParse(_currentUser?.age ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cake_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.dateOfBirth, style: AppText.metadata),
                const SizedBox(height: 4),
                if (_isEditing)
                  InkWell(
                    onTap: _pickDateOfBirth,
                    borderRadius:
                        BorderRadius.circular(AppRadius.control),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: AppColors.outlineStrong),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              dob != null
                                  ? AppHelpers.formatDate(dob)
                                  : AppStrings.selectDateOfBirth,
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: dob != null
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    dob != null ? AppHelpers.formatDate(dob) : 'Not set',
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: dob != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                if (age != null && !_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Age: $age years',
                      style: AppText.metadata,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      // Do not allow selecting a future date.
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Widget _buildBloodDonorRow() {
    // Age comes from DOB when available, falling back to the legacy stored
    // age so existing users without a DOB are not broken.
    final age = AppHelpers.calculateAge(_dateOfBirth) ??
        int.tryParse(_currentUser?.age ?? '');
    final canDonate = age != null && age >= 18;
    final isUnder18 = age != null && age < 18;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bloodtype_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blood Donor', style: AppText.metadata),
                const SizedBox(height: 4),
                if (_isEditing)
                  Row(
                    children: [
                      Switch(
                        value: _isBloodDonor,
                        onChanged: canDonate
                            ? (value) {
                                setState(() {
                                  _isBloodDonor = value;
                                });
                              }
                            : null,
                        activeThumbColor: AppColors.primary,
                      ),
                      Expanded(
                        child: Text(
                          canDonate
                              ? (_isBloodDonor
                                  ? 'You are registered as an emergency donor'
                                  : 'You are not registered as a donor')
                              : (isUnder18
                                  ? AppStrings.bloodDonorAgeRestriction
                                  : AppStrings.bloodDonorSelectDob),
                          style: AppText.metadata,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _currentUser?.isBloodDonor == true ? 'Yes' : 'No',
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Emergency contacts ─────────────────────────────────────────────────

  Widget _buildGuardiansSection() {
    return FutureBuilder<List<GuardianModel>>(
      future: _guardiansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const AppCard(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        // A failed read must not masquerade as "you have no contacts".
        if (snapshot.hasError) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Emergency Contacts'),
                Text(
                  'Could not load your emergency contacts. Check your '
                  'connection and try again.',
                  style: AppText.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _reloadGuardians,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        final guardians = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Emergency Contacts',
              actionLabel: guardians.isEmpty ? null : 'Manage',
              onAction: guardians.isEmpty
                  ? null
                  : () => _openGuardianSetup(),
            ),
            if (guardians.isEmpty)
              AppCard(
                child: Column(
                  children: [
                    const IconBadge(Icons.contact_phone_rounded,
                        AppColors.warning, size: 52, soft: true),
                    const SizedBox(height: AppSpacing.md),
                    Text('No emergency contacts yet',
                        style: AppText.cardTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Add family or neighbours who should be alerted when '
                      'you trigger SOS.',
                      textAlign: TextAlign.center,
                      style: AppText.caption,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: _openGuardianSetup,
                      icon: const Icon(Icons.person_add_alt_rounded,
                          size: 18),
                      label: const Text('Add Contact'),
                    ),
                  ],
                ),
              )
            else
              ...guardians.map(_buildGuardianCard),
          ],
        );
      },
    );
  }

  Widget _buildGuardianCard(GuardianModel guardian) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Text(
                guardian.name.isNotEmpty
                    ? guardian.name[0].toUpperCase()
                    : 'G',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guardian.name, style: AppText.cardTitle),
                  const SizedBox(height: 2),
                  Text(
                    '${guardian.relation} • '
                    '${AppHelpers.formatPhoneNumber(guardian.phone)}',
                    style: AppText.metadata,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit contact',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GuardianSetupScreen(editGuardian: guardian),
                  ),
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(Icons.edit_rounded,
                  color: AppColors.primary, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Widget _buildActions() {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: _isSavingProfile ? null : _saveProfile,
              child: _isSavingProfile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _enableEditMode,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit Profile'),
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PermissionsSetupScreen(
                  canSkip: true,
                ),
              ),
            );
          },
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              const IconBadge(Icons.security_rounded, AppColors.primary,
                  size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Permissions Setup', style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      'Check SOS, location and notification access',
                      style: AppText.metadata,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }

  // ── Handlers (logic unchanged) ─────────────────────────────────────────

  /// Loads the emergency-contact list.
  ///
  /// Errors are deliberately propagated (previously swallowed and turned into
  /// an empty list) so the UI can distinguish "no contacts saved" from
  /// "could not read your contacts".
  Future<List<GuardianModel>> _loadGuardians() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    final firestoreService = FirestoreService();
    return firestoreService.getGuardians(currentUser.uid);
  }

  void _openGuardianSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GuardianSetupScreen(),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _enableEditMode() {
    setState(() {
      _isEditing = true;
      _nameController.text = _currentUser?.name ?? '';
      _phoneController.text = _currentUser?.phone ?? '';
      _stateController.text = _currentUser?.state ?? '';
      _districtController.text = _currentUser?.district ?? '';
      _mandalController.text = _currentUser?.mandal ?? '';
      _villageController.text = _currentUser?.village ?? '';
      _dateOfBirth = _currentUser?.dateOfBirth;
      _bloodGroupController.text = _currentUser?.bloodGroup ?? '';
      _isBloodDonor = _currentUser?.isBloodDonor ?? false;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      // Discard any unsaved DOB changes so view mode shows the saved value.
      _dateOfBirth = _currentUser?.dateOfBirth;
    });
  }

  /// Validates the fields that every location-scoped query in the app
  /// depends on. The inline `MandalAutocomplete` / `DistrictAutocomplete`
  /// validators cannot fire on their own because this screen is not wrapped
  /// in a `Form`, so the same rules are enforced here before any write.
  String? _validateProfileFields() {
    if (_nameController.text.trim().isEmpty) return 'Please enter your name.';

    final phoneError = AppHelpers.validatePhone(_phoneController.text.trim());
    if (phoneError != null) return phoneError;

    if (_districtController.text.trim().isEmpty) {
      return 'Please select your district.';
    }
    if (_mandalController.text.trim().isEmpty) {
      return 'Please select your mandal.';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;

    final validationError = _validateProfileFields();
    if (validationError != null) {
      AppHelpers.showErrorSnackBar(context, validationError);
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      final updatedUser = widget.user.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
        mandal: _mandalController.text.trim().toLowerCase(),
        village: _villageController.text.trim().toLowerCase(),
        // Age is derived dynamically from dateOfBirth; keep any legacy value.
        age: _currentUser?.age ?? '',
        dateOfBirth: _dateOfBirth,
        bloodGroup: _bloodGroupController.text.trim(),
        photoUrl: _currentUser?.photoUrl, // Preserve current photoUrl
        isBloodDonor: _isBloodDonor,
      );

      final firestoreService = FirestoreService();
      await firestoreService.updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isEditing = false;
        });
        AppHelpers.showSuccessSnackBar(context, 'Profile updated successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Profile update failed: $e');
      if (mounted) {
        AppHelpers.showErrorSnackBar(
          context,
          'Could not save your profile. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Sign out failed: $e');
      if (mounted) {
        AppHelpers.showErrorSnackBar(
          context,
          'Could not sign you out. Please try again.',
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Pick image from gallery
      final File? imageFile = await _cloudinaryService.pickImageFromGallery();

      if (imageFile == null) {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
        return;
      }

      // Upload to Cloudinary
      final String imageUrl = await _cloudinaryService.uploadImage(imageFile);

      // Update user model with new image URL
      final updatedUser = _currentUser!.copyWith(photoUrl: imageUrl);

      // Save to Firestore
      final firestoreService = FirestoreService();
      await firestoreService.updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isUploadingImage = false;
        });
        AppHelpers.showSuccessSnackBar(
          context,
          'Profile image updated successfully',
        );
        // Return success to parent screen to trigger reload
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Profile image update failed: $e');
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        AppHelpers.showErrorSnackBar(
          context,
          'Could not update your profile photo. Please try again.',
        );
      }
    }
  }
}

