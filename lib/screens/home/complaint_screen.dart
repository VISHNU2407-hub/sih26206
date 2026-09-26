import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  File? _selectedImage;
  UserModel? _currentUser;
  String? _selectedCategory;

  final List<String> _categories = [
    'Roads',
    'Water',
    'Electricity',
    'Drainage',
    'Garbage',
    'Street Lights',
    'Internet',
    'Public Safety',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userData = await _firestoreService.getUser(user.uid);
        if (!mounted) return;
        setState(() {
          _currentUser = userData;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
    }
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
        AppHelpers.showErrorSnackBar(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final url = await _cloudinaryService.uploadImage(image);
      return url;
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to upload image: $e');
      }
      return null;
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      AppHelpers.showErrorSnackBar(context, 'Please select a category');
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

      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await _uploadImage(_selectedImage!);
        if (uploadedImageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      final complaint = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'media': uploadedImageUrl != null && uploadedImageUrl.isNotEmpty
            ? [uploadedImageUrl]
            : [],
        'userId': currentUser.uid,
        'userName': _currentUser?.name ?? 'Anonymous',
        'userVillage': _currentUser?.village ?? '',
        'userMandal': _currentUser?.mandal ?? '',
        'userProfileImage': _currentUser?.photoUrl,
        'status': 'pending',
        'category': _selectedCategory,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      final complaintId = await _firestoreService.submitComplaint(complaint);

      // Create notification for the complaint creator
      try {
        final notification = NotificationModel(
          id: '',
          title: 'Complaint Submitted',
          body: 'Your complaint has been submitted and is under review.',
          type: 'complaint',
          createdAt: DateTime.now(),
          isRead: false,
          targetMandal: _currentUser?.mandal ?? '',
          targetUserId: currentUser.uid,
          relatedDocumentId: complaintId,
        );
        await _firestoreService.createNotification(notification);
      } catch (notificationError) {
        // Log but do not fail complaint submission if notification fails
        print('Error creating complaint notification: $notificationError');
      }

      // Notify all admins in the same village and mandal
      try {
        final admins = await _firestoreService.getAdminUsersByVillageAndMandal(
          _currentUser?.village ?? '',
          _currentUser?.mandal ?? '',
        );
        for (final admin in admins) {
          final adminNotification = NotificationModel(
            id: '',
            title: 'New Complaint Received',
            body: 'A new complaint has been submitted in your village.',
            type: 'complaint',
            createdAt: DateTime.now(),
            isRead: false,
            targetMandal: _currentUser?.mandal ?? '',
            targetUserId: admin.uid,
            relatedDocumentId: complaintId,
          );
          await _firestoreService.createNotification(adminNotification);
        }
      } catch (notificationError) {
        // Log but do not fail complaint submission if notification fails
        print('Error creating admin notification: $notificationError');
      }

      if (mounted) {
        AppHelpers.showSuccessSnackBar(context, AppStrings.complaintSubmitted);
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to submit complaint: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImage = null;
      _selectedCategory = null;
    });
  }

  IconData _getCategoryIcon(String category) {
    return AppHelpers.getCategoryIcon(category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Complaint Box',
          style: TextStyle(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Category Dropdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      hint: const Text('Select Category *'),
                      isExpanded: true,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category),
                                size: 22,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(category),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Complaint Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Complaint Title',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLength: 100,
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Complaint title'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 20),

                // Image Upload Section
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Image (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImage != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    width: double.infinity,
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
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                  });
                                },
                                icon: const Icon(Icons.close),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: _isUploadingImage
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 12),
                                        Text('Uploading image...'),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to upload image',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Complaint Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: AppStrings.complaintDescription,
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  maxLength: 1000,
                  validator: (value) => AppHelpers.validateRequired(
                    value,
                    'Complaint description',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitComplaint(),
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? AppStrings.loading : 'Submit Complaint',
                    onPressed: _submitComplaint,
                    isLoading: _isLoading || _isUploadingImage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
