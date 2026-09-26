import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../models/guardian_model.dart';
import '../../services/contact_picker_service.dart';
import '../../services/firestore_service.dart';
import '../../services/permissions_setup_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../home/main_screen.dart';
import '../permissions_setup_screen.dart';

class GuardianSetupScreen extends StatefulWidget {
  final GuardianModel? editGuardian;

  const GuardianSetupScreen({super.key, this.editGuardian});

  @override
  State<GuardianSetupScreen> createState() => _GuardianSetupScreenState();
}

class _GuardianSetupScreenState extends State<GuardianSetupScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ContactPickerService _contactPickerService = ContactPickerService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _phoneController = TextEditingController();

  List<GuardianModel> _guardians = [];
  bool _isLoading = false;

  /// True when the guardian list could not be read, so the empty state is not
  /// shown as "you have no emergency contacts".
  bool _loadFailed = false;
  bool _isSavingGuardian = false;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
    if (widget.editGuardian != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEditGuardianDialog(widget.editGuardian!);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadGuardians() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final guardians = await _firestoreService.getGuardians(currentUser.uid);
        if (!mounted) return;
        setState(() {
          _guardians = guardians;
          _loadFailed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadFailed = true);
        AppHelpers.showErrorSnackBar(
          context,
          'Could not load your emergency contacts. Check your connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddGuardianDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.addGuardian),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: AppStrings.guardianName,
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Guardian name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _relationController,
                  decoration: InputDecoration(
                    labelText: AppStrings.relation,
                    prefixIcon: const Icon(Icons.family_restroom),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Relation'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: AppStrings.phoneNumber,
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: AppHelpers.validatePhone,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickGuardianFromContacts,
                    icon: const Icon(Icons.contacts),
                    label: const Text('Pick From Contacts'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearForm();
            },
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: _isSavingGuardian ? null : _addGuardian,
            child: _isSavingGuardian
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(AppStrings.add),
          ),
        ],
      ),
    );
  }

  Future<void> _pickGuardianFromContacts() async {
    final status = await ph.Permission.contacts.request();
    if (!status.isGranted) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(
          context,
          'Contacts permission is required to pick a guardian contact.',
        );
      }
      return;
    }

    try {
      final contact = await _contactPickerService.pickPhoneContact();
      if (contact == null) {
        return;
      }

      final phone = _normalizeGuardianPhone(contact.phone);
      if (contact.name.isNotEmpty) {
        _nameController.text = contact.name;
      }
      if (phone.isNotEmpty) {
        _phoneController.text = phone;
      }
    } on PlatformException catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(
          context,
          e.message ?? 'Unable to pick contact',
        );
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Unable to pick contact: $e');
      }
    }
  }

  String _normalizeGuardianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  bool _guardianPhoneExists(String phone, {String? excludingGuardianId}) {
    final normalizedPhone = _normalizeGuardianPhone(phone);
    if (normalizedPhone.isEmpty) {
      return false;
    }

    return _guardians.any((guardian) {
      if (excludingGuardianId != null && guardian.id == excludingGuardianId) {
        return false;
      }
      return _normalizeGuardianPhone(guardian.phone) == normalizedPhone;
    });
  }

  Future<void> _addGuardian() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_guardians.length >= AppConstants.maxGuardians) {
      showErrorSnackBar(
        context,
        'Maximum ${AppConstants.maxGuardians} guardians allowed',
      );
      return;
    }

    setState(() {
      _isSavingGuardian = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final guardianPhone = _phoneController.text.trim();
      if (_guardianPhoneExists(guardianPhone)) {
        if (mounted) {
          AppHelpers.showErrorSnackBar(
            context,
            'This guardian number already exists.',
          );
        }
        return;
      }

      // Get user's phone number for validation
      final userModel = await _firestoreService.getUser(currentUser.uid);
      if (userModel != null) {
        final userPhone = userModel.phone.trim();

        final normalizedUserPhone = _normalizeGuardianPhone(userPhone);
        final normalizedGuardianPhone = _normalizeGuardianPhone(guardianPhone);

        if (normalizedUserPhone == normalizedGuardianPhone) {
          if (mounted) {
            AppHelpers.showErrorSnackBar(
              context,
              'Your personal number cannot be added as a guardian contact.',
            );
          }
          return;
        }
      }

      final guardian = GuardianModel(
        id: AppHelpers.generateUniqueId(),
        name: _nameController.text.trim(),
        relation: _relationController.text.trim(),
        phone: guardianPhone,
        createdAt: DateTime.now(),
      );

      await _firestoreService.saveGuardian(currentUser.uid, guardian);

      if (mounted) {
        Navigator.pop(context);
        _clearForm();
        AppHelpers.showSuccessSnackBar(context, AppStrings.guardianSaved);
        _loadGuardians();
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to add guardian: $e');
      }
    } finally {
      setState(() {
        _isSavingGuardian = false;
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _relationController.clear();
    _phoneController.clear();
  }

  void _showEditGuardianDialog(GuardianModel guardian) {
    _nameController.text = guardian.name;
    _relationController.text = guardian.relation;
    _phoneController.text = guardian.phone;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Guardian'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppStrings.guardianName,
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    AppHelpers.validateRequired(value, 'Guardian name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _relationController,
                decoration: InputDecoration(
                  labelText: AppStrings.relation,
                  prefixIcon: const Icon(Icons.family_restroom),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    AppHelpers.validateRequired(value, 'Relation'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: AppStrings.phoneNumber,
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: AppHelpers.validatePhone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearForm();
            },
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: _isSavingGuardian
                ? null
                : () => _updateGuardian(guardian),
            child: _isSavingGuardian
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGuardian(GuardianModel existingGuardian) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSavingGuardian = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final guardianPhone = _phoneController.text.trim();
      if (_guardianPhoneExists(
        guardianPhone,
        excludingGuardianId: existingGuardian.id,
      )) {
        if (mounted) {
          AppHelpers.showErrorSnackBar(
            context,
            'This guardian number already exists.',
          );
        }
        return;
      }

      // Get user's phone number for validation
      final userModel = await _firestoreService.getUser(currentUser.uid);
      if (userModel != null) {
        final userPhone = userModel.phone.trim();

        final normalizedUserPhone = _normalizeGuardianPhone(userPhone);
        final normalizedGuardianPhone = _normalizeGuardianPhone(guardianPhone);

        if (normalizedUserPhone == normalizedGuardianPhone) {
          if (mounted) {
            AppHelpers.showErrorSnackBar(
              context,
              'Your personal number cannot be added as a guardian contact.',
            );
          }
          return;
        }
      }

      final updatedGuardian = GuardianModel(
        id: existingGuardian.id,
        name: _nameController.text.trim(),
        relation: _relationController.text.trim(),
        phone: guardianPhone,
        createdAt: existingGuardian.createdAt,
      );

      await _firestoreService.updateGuardian(currentUser.uid, updatedGuardian);

      if (!mounted) return;

      Navigator.pop(context, true);
      _clearForm();
      AppHelpers.showSuccessSnackBar(context, 'Guardian updated successfully');
      _loadGuardians();
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to update guardian: $e');
      }
    } finally {
      setState(() {
        _isSavingGuardian = false;
      });
    }
  }

  Future<void> _deleteGuardian(GuardianModel guardian) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Guardian'),
        content: Text('Are you sure you want to delete ${guardian.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _firestoreService.deleteGuardian(currentUser.uid, guardian.id);
          if (!mounted) return;
          AppHelpers.showSuccessSnackBar(context, AppStrings.guardianDeleted);
          _loadGuardians();
        }
      } catch (e) {
        if (mounted) {
          AppHelpers.showErrorSnackBar(
            context,
            'Failed to delete guardian: $e',
          );
        }
      }
    }
  }

  /// Onboarding order is Profile → Guardians → Permissions → Main.
  ///
  /// A brand-new user used to be pushed straight to `MainScreen` from here,
  /// which meant `PermissionsSetupScreen` was only ever seen by a *returning*
  /// user whose flag happened to be unset — new users silently skipped the
  /// SMS / location / phone / overlay permissions the SOS and alert features
  /// depend on. Now the step is honoured for first-time users, and users who
  /// already completed it go straight through.
  Future<void> _navigateToMainScreen() async {
    final permissionsDone = await PermissionsSetupService.isCompleted();
    if (!mounted) return;

    if (permissionsDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          AppStrings.guardianSetup,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_guardians.length < AppConstants.maxGuardians)
            IconButton(
              onPressed: _showAddGuardianDialog,
              icon: const Icon(Icons.add),
              color: AppColors.primary,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Emergency Contacts Setup',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add up to ${AppConstants.maxGuardians} emergency contacts who will be notified in case of emergency.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

            // Guardians List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadFailed
                      ? _buildLoadErrorState()
                      : _guardians.isEmpty
                          ? _buildEmptyState()
                          : _buildGuardiansList(),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: CustomButton(
                text: _guardians.isNotEmpty
                    ? 'Continue to Main Screen'
                    : 'Continue without Guardians',
                onPressed: _navigateToMainScreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Could not load emergency contacts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadFailed = false;
                });
                _loadGuardians();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_phone, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No emergency contacts added',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first emergency contact',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: AppStrings.addGuardian,
            onPressed: _showAddGuardianDialog,
            icon: const Icon(Icons.add),
            width: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildGuardiansList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _guardians.length,
      itemBuilder: (context, index) {
        final guardian = _guardians[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                guardian.name.isNotEmpty ? guardian.name[0].toUpperCase() : 'G',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            title: Text(
              guardian.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardian.relation,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  AppHelpers.formatPhoneNumber(guardian.phone),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showEditGuardianDialog(guardian),
                  icon: const Icon(
                    Icons.edit,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteGuardian(guardian),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
