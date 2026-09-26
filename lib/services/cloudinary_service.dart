import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class CloudinaryService {
  // Cloudinary configuration
  static const String cloudName = 'dtq9hkyzn';
  static const String uploadPreset = 'village_posts';

  final ImagePicker _imagePicker = ImagePicker();

  // Upload image to Cloudinary
  Future<String> uploadImage(File imageFile) async {
    try {
      // Validate file size (10MB limit)
      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024; // 10MB in bytes

      if (fileSize > maxSize) {
        throw Exception('Image size must be under 10MB');
      }

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Upload timeout. Please check your internet connection.',
          );
        },
      );

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);

        try {
          // Parse JSON response safely
          final jsonData = jsonDecode(responseString) as Map<String, dynamic>;

          // Validate secure_url exists
          if (jsonData.containsKey('secure_url') &&
              jsonData['secure_url'] != null) {
            final secureUrl = jsonData['secure_url'] as String;
            if (secureUrl.isNotEmpty) {
              return secureUrl;
            }
          }

          throw Exception('Invalid response: secure_url not found');
        } catch (e) {
          if (e is FormatException) {
            throw Exception('Invalid response format from Cloudinary');
          }
          rethrow;
        }
      } else if (response.statusCode == 400) {
        throw Exception('Invalid image or upload parameters');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Authentication failed. Please check Cloudinary configuration.',
        );
      } else if (response.statusCode == 413) {
        throw Exception('Image too large. Please use a smaller image.');
      } else if (response.statusCode == 429) {
        throw Exception('Too many upload attempts. Please try again later.');
      } else if (response.statusCode >= 500) {
        throw Exception('Cloudinary server error. Please try again later.');
      } else {
        throw Exception(
          'Upload failed with status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      if (e.toString().contains('Image size must be under 10MB')) {
        rethrow;
      }
      throw Exception('Image upload failed. Please try again.');
    }
  }

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);

        // Validate file size immediately after picking
        final fileSize = await file.length();
        const maxSize = 10 * 1024 * 1024; // 10MB in bytes

        if (fileSize > maxSize) {
          throw Exception('Image size must be under 10MB');
        }

        return file;
      }
      return null;
    } catch (e) {
      if (e.toString().contains('Image size must be under 10MB')) {
        rethrow;
      }
      throw Exception('Failed to pick image: $e');
    }
  }

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);

        // Validate file size immediately after picking
        final fileSize = await file.length();
        const maxSize = 10 * 1024 * 1024; // 10MB in bytes

        if (fileSize > maxSize) {
          throw Exception('Image size must be under 10MB');
        }

        return file;
      }
      return null;
    } catch (e) {
      if (e.toString().contains('Image size must be under 10MB')) {
        rethrow;
      }
      throw Exception('Failed to pick image: $e');
    }
  }

  // Pick multiple images from gallery (up to 4)
  Future<List<File>> pickMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFiles.isEmpty) {
        return [];
      }

      // Validate maximum 4 images
      if (pickedFiles.length > 4) {
        throw Exception('Maximum 4 images allowed');
      }

      final List<File> files = [];
      const maxSize = 10 * 1024 * 1024; // 10MB in bytes

      for (final pickedFile in pickedFiles) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();

        if (fileSize > maxSize) {
          throw Exception('Image size must be under 10MB');
        }

        files.add(file);
      }

      return files;
    } catch (e) {
      if (e.toString().contains('Maximum 4 images allowed') ||
          e.toString().contains('Image size must be under 10MB')) {
        rethrow;
      }
      throw Exception('Failed to pick images: $e');
    }
  }

  // Pick PDF file
  Future<File?> pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = File(result.files.single.path!);

      // Validate file size (15MB limit for PDF)
      final fileSize = await file.length();
      const maxSize = 15 * 1024 * 1024; // 15MB in bytes

      if (fileSize > maxSize) {
        throw Exception('PDF size must be under 15MB');
      }

      return file;
    } catch (e) {
      if (e.toString().contains('PDF size must be under 15MB')) {
        rethrow;
      }
      throw Exception('Failed to pick PDF: $e');
    }
  }

  // Upload PDF to Cloudinary
  Future<String> uploadPDF(File pdfFile, String fileName) async {
    try {
      // Validate file size (15MB limit)
      final fileSize = await pdfFile.length();
      const maxSize = 15 * 1024 * 1024; // 15MB in bytes

      if (fileSize > maxSize) {
        throw Exception('PDF size must be under 15MB');
      }

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/raw/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['public_id'] =
            'pdf_${DateTime.now().millisecondsSinceEpoch}_$fileName'
        ..files.add(await http.MultipartFile.fromPath('file', pdfFile.path));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Upload timeout. Please check your internet connection.',
          );
        },
      );

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);

        try {
          final jsonData = jsonDecode(responseString) as Map<String, dynamic>;

          if (jsonData.containsKey('secure_url') &&
              jsonData['secure_url'] != null) {
            final secureUrl = jsonData['secure_url'] as String;
            if (secureUrl.isNotEmpty) {
              return secureUrl;
            }
          }

          throw Exception('Invalid response: secure_url not found');
        } catch (e) {
          if (e is FormatException) {
            throw Exception('Invalid response format from Cloudinary');
          }
          rethrow;
        }
      } else if (response.statusCode == 400) {
        throw Exception('Invalid PDF or upload parameters');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Authentication failed. Please check Cloudinary configuration.',
        );
      } else if (response.statusCode == 413) {
        throw Exception('PDF too large. Please use a smaller PDF.');
      } else if (response.statusCode == 429) {
        throw Exception('Too many upload attempts. Please try again later.');
      } else if (response.statusCode >= 500) {
        throw Exception('Cloudinary server error. Please try again later.');
      } else {
        throw Exception(
          'Upload failed with status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      if (e.toString().contains('PDF size must be under 15MB')) {
        rethrow;
      }
      throw Exception('PDF upload failed. Please try again.');
    }
  }
}
