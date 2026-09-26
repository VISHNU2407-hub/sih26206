import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool isEditable;
  final VoidCallback? onEdit;
  final bool showBorder;
  final bool forceRefresh;

  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 50,
    this.isEditable = false,
    this.onEdit,
    this.showBorder = true,
    this.forceRefresh = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: isEditable ? onEdit : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: ClipOval(
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  memCacheWidth: forceRefresh ? null : (size * 2).toInt(),
                  memCacheHeight: forceRefresh ? null : (size * 2).toInt(),
                  placeholder: (context, url) => Container(
                    width: size,
                    height: size,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildFallback(),
                )
              : _buildFallback(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      color: AppConstants.primaryColor,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
