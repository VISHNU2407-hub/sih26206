import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool _isLoading = false;
  UserModel? _currentUser;
  List<File> _selectedImages = [];
  File? _selectedPDF;
  String? _selectedPDFName;
  double _uploadProgress = 0.0;

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

  Future<void> _pickMultipleImages() async {
    try {
      final images = await _cloudinaryService.pickMultipleImages();
      if (images.isNotEmpty && mounted) {
        setState(() {
          _selectedImages = images;
        });
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, e.toString());
      }
    }
  }

  void _removeImageAtIndex(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _pickPDF() async {
    try {
      final pdf = await _cloudinaryService.pickPDF();
      if (pdf != null && mounted) {
        setState(() {
          _selectedPDF = pdf;
          _selectedPDFName = pdf.path.split('/').last;
        });
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, e.toString());
      }
    }
  }

  void _removePDF() {
    setState(() {
      _selectedPDF = null;
      _selectedPDFName = null;
    });
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
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to load user data: $e');
      }
    }
  }

  Future<void> _postPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentUser == null) {
      debugPrint('_postPost - User data not loaded');
      AppHelpers.showErrorSnackBar(
        context,
        'User data not loaded. Please try again.',
      );
      return;
    }

    // Validate that user has required fields
    if (_currentUser!.village.isEmpty) {
      debugPrint('_postPost - Village is empty');
      AppHelpers.showErrorSnackBar(
        context,
        'Your village is not set. Please update your profile first.',
      );
      return;
    }

    if (_currentUser!.mandal.isEmpty) {
      debugPrint('_postPost - Mandal is empty');
      AppHelpers.showErrorSnackBar(
        context,
        'Your mandal is not set. Please update your profile first.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final postId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('_postPost - Creating post with ID: $postId');
      debugPrint(
        '_postPost - User village: ${_currentUser!.village}, mandal: ${_currentUser!.mandal}',
      );

      // Build media array
      List<Map<String, dynamic>> media = [];

      // Upload images if selected
      if (_selectedImages.isNotEmpty) {
        debugPrint(
          '_postPost - Uploading ${_selectedImages.length} images for post $postId',
        );

        for (int i = 0; i < _selectedImages.length; i++) {
          setState(() {
            _uploadProgress = (i + 1) / _selectedImages.length * 0.5;
          });
          final imageUrl = await _cloudinaryService.uploadImage(
            _selectedImages[i],
          );
          media.add({'type': 'image', 'url': imageUrl});
          debugPrint(
            '_postPost - Image ${i + 1} uploaded successfully: $imageUrl',
          );
        }
      }

      // Upload PDF if selected
      if (_selectedPDF != null) {
        debugPrint('_postPost - Uploading PDF for post $postId');
        setState(() {
          _uploadProgress = 0.75;
        });
        final pdfUrl = await _cloudinaryService.uploadPDF(
          _selectedPDF!,
          _selectedPDFName!,
        );
        media.add({'type': 'pdf', 'url': pdfUrl, 'fileName': _selectedPDFName});
        debugPrint('_postPost - PDF uploaded successfully: $pdfUrl');
      }

      setState(() {
        _uploadProgress = 1.0;
      });

      // Create post with userVillage and userMandal for filtering
      final post = PostModel(
        postId: postId,
        userId: _currentUser!.uid,
        userName: _currentUser!.name,
        userType: _currentUser!.role,
        userVillage: _currentUser!.village,
        userMandal: _currentUser!.mandal,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        userProfileImage: _currentUser!.photoUrl,
        postImage: null, // Deprecated - using media array instead
        media: media.isNotEmpty ? media : null,
        createdAt: DateTime.now(),
      );

      debugPrint('_postPost - Post object created: ${post.toString()}');

      // Save to Firestore
      await _firestoreService.createPost(post);
      debugPrint('_postPost - Post saved to Firestore successfully');

      if (mounted) {
        AppHelpers.showSuccessSnackBar(context, 'Post created successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('_postPost - Error creating post: $e');
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to create post: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
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
        title: const Text(
          'Create Post',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
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
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
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
                            Icons.post_add,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Create a New Post',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share updates and news with the community',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Post Title',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLength: 120,
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Post title'),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Post Description',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  maxLength: 2000,
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Post description'),
                ),

                const SizedBox(height: 20),

                // Images picker section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.image,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Add Images (Optional, Max 4)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedImages.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _selectedImages.clear();
                                });
                              },
                              tooltip: 'Remove all images',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImages.isNotEmpty) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImages[index],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImageAtIndex(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ] else
                        GestureDetector(
                          onTap: _pickMultipleImages,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add images (Max 4)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // PDF picker section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Add PDF (Optional, Max 1)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedPDF != null)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: _removePDF,
                              tooltip: 'Remove PDF',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectedPDF != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red[700],
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPDFName ?? 'PDF Document',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[900],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PDF selected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else
                        GestureDetector(
                          onTap: _pickPDF,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add PDF (Max 15MB)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Upload progress
                if (_isLoading && _uploadProgress > 0) ...[
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading media... ${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _postPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Post',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
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
