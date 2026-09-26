import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/roles.dart';
import '../../services/cloudinary_service.dart';

import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/mandal_autocomplete.dart';
import '../../widgets/district_autocomplete.dart';


class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _mandalController = TextEditingController();
  final _villageController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  String _selectedBloodGroup = '';
  // Self-signup is always a citizen (Firestore rules enforce role ==
  // "citizen" at create; see the Role field below). _selectedRole is kept
  // as a local so _saveProfile needs no changes.
  final String _selectedRole = AppRoles.citizen;
  bool _isBloodDonor = false;
  bool _phoneFromAuth = false;

  bool _isLoading = false;
  bool _isUploadingImage = false;
  File? _selectedImage;
  @override
  void initState() {
    super.initState();
    // Pre-populate phone from Firebase Auth if available
    final user = _auth.currentUser;
    if (user != null && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      _phoneController.text = user.phoneNumber!;
      _phoneFromAuth = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _mandalController.dispose();
    _villageController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Widget _buildVerifiedPhoneDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.phoneNumber,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _phoneController.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Colors.green,
                ),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      // Default to ~18 years ago so the 18+ blood donor check is common.
      initialDate: _selectedDateOfBirth ??
          DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      // Do not allow selecting a future date.
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = AppHelpers.formatDate(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Upload image to Cloudinary if selected
      String photoUrl = '';
      if (_selectedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });
        try {
          photoUrl = await _cloudinaryService.uploadImage(_selectedImage!);
        } catch (e) {
          if (mounted) {
            showErrorSnackBar(context, 'Failed to upload image: $e');
          }
          // Continue without image if upload fails
        } finally {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }

      // Create user model
      final user = UserModel(
        uid: currentUser.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
        mandal: _mandalController.text.trim().toLowerCase(),
        village: _villageController.text.trim().toLowerCase(),
        photoUrl: photoUrl,
        // Age is derived dynamically from dateOfBirth; not stored manually.
        age: '',
        dateOfBirth: _selectedDateOfBirth,
        bloodGroup: _selectedBloodGroup,
        role: _selectedRole,
        isBloodDonor: _isBloodDonor,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestoreService.saveUser(user);

      if (mounted) {
        showSuccessSnackBar(context, AppStrings.profileSaved);
        // Navigate to guardian setup
        Navigator.pushReplacementNamed(context, '/guardian-setup');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          AppStrings.profileSetup,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Profile Avatar
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: _selectedImage != null
                          ? Image.file(
                              _selectedImage!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            )
                          : CircleAvatar(
                              radius: 60,
                              backgroundColor: AppColors.primary
                                  .withOpacity(0.1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    color: AppColors.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isUploadingImage
                      ? 'Uploading image...'
                      : 'Tap to add profile photo',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: AppStrings.fullName,
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => validateRequired(value, 'Name'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Phone Field
                _phoneFromAuth
                    ? _buildVerifiedPhoneDisplay()
                    : TextFormField(
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
                        validator: validatePhone,
                        textInputAction: TextInputAction.next,
                      ),

                const SizedBox(height: 16),

                // State Field
                TextFormField(
                  controller: _stateController,
                  decoration: InputDecoration(
                    labelText: AppStrings.state,
                    prefixIcon: const Icon(Icons.public),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => validateRequired(value, 'State'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // District Field
                DistrictAutocomplete(
                  controller: _districtController,
                  labelText: AppStrings.district,
                  prefixIcon: Icons.map,
                  validator: (value) => validateRequired(value, 'District'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Mandal Field
                MandalAutocomplete(
                  controller: _mandalController,
                  labelText: AppStrings.mandal,
                  prefixIcon: Icons.location_city,
                  validator: (value) => validateRequired(value, 'Mandal'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Village Field
                TextFormField(
                  controller: _villageController,
                  decoration: InputDecoration(
                    labelText: AppStrings.village,
                    prefixIcon: const Icon(Icons.home),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => validateRequired(value, 'Village'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Date of Birth Field
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _pickDateOfBirth,
                  decoration: InputDecoration(
                    labelText: AppStrings.dateOfBirth,
                    prefixIcon: const Icon(Icons.cake),
                    suffixIcon: const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (_) =>
                      AppHelpers.validateDateOfBirth(_selectedDateOfBirth),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Blood Group Field
                DropdownButtonFormField<String>(
                  value: _selectedBloodGroup.isNotEmpty
                      ? _selectedBloodGroup
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: const Icon(Icons.bloodtype),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items:
                      const [
                        'A+',
                        'A-',
                        'B+',
                        'B-',
                        'AB+',
                        'AB-',
                        'O+',
                        'O-',
                      ].map((String bloodGroup) {
                        return DropdownMenuItem<String>(
                          value: bloodGroup,
                          child: Text(bloodGroup),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBloodGroup = newValue ?? '';
                    });
                  },
                  validator: (value) => validateRequired(value, 'Blood group'),
                ),

                const SizedBox(height: 16),

                // Blood Donor Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bloodtype,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Available to Donate Blood?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _isBloodDonor,
                            onChanged: (value) {
                              if (value) {
                                final age = AppHelpers.calculateAge(
                                  _selectedDateOfBirth,
                                );
                                if (age == null || age < 18) {
                                  showErrorSnackBar(
                                    context,
                                    _selectedDateOfBirth == null
                                        ? AppStrings.bloodDonorSelectDob
                                        : AppStrings.bloodDonorAgeRestriction,
                                  );
                                  return;
                                }
                              }
                              setState(() {
                                _isBloodDonor = value;
                              });
                            },
                            activeThumbColor: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Age eligibility message
                      Builder(
                        builder: (context) {
                          final age = AppHelpers.calculateAge(
                            _selectedDateOfBirth,
                          );
                          if (_selectedDateOfBirth == null) {
                            return Text(
                              AppStrings.bloodDonorSelectDob,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }
                          if (age != null && age < 18) {
                            return Text(
                              AppStrings.bloodDonorAgeRestriction,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Role Field
                //
                // SECURITY: self-signup may only ever create a citizen.
                // Firestore rules reject any create with role != "citizen"
                // (and role is immutable afterwards), so offering Admin here
                // only produced a guaranteed permission-denied failure on
                // save. Authority roles (village_authority, district_authority,
                // rescue) are provisioned out-of-band via the Admin SDK
                // (functions/src/seedDemoUsers.ts).
                DropdownButtonFormField<String>(
                  initialValue: AppRoles.citizen,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText:
                        'Authority roles are assigned by the district office',
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: AppRoles.citizen,
                      child: Text('Citizen'),
                    ),
                  ],
                  onChanged: null, // fixed: role cannot self-escalate
                ),

                const SizedBox(height: 32),

                // Save Button
                CustomButton(
                  text: AppStrings.save,
                  onPressed: _saveProfile,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
