import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petcare/data/services/image_service.dart';

class ProfileImagePicker extends StatelessWidget {
  final String? imagePath;
  final Function(File?) onImageSelected;
  final double size;
  final bool showEditIcon;

  const ProfileImagePicker({
    super.key,
    this.imagePath,
    required this.onImageSelected,
    this.size = 120,
    this.showEditIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // 프로필 이미지
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceVariant,
              ),
              child: ClipOval(
                child: _buildImageContent(context),
              ),
            ),
            // 편집 아이콘
            if (showEditIcon)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: size * 0.15,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      try {
        return Image.file(
          File(imagePath!),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(context);
          },
        );
      } catch (e) {
        return _buildDefaultAvatar(context);
      }
    }
    return _buildDefaultAvatar(context);
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Icon(
        Icons.pets,
        size: size * 0.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _showImageSourceDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '프로필 사진 선택',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  context,
                  icon: Icons.photo_library,
                  label: '갤러리',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(context, ImageSource.gallery);
                  },
                ),
                _buildSourceOption(
                  context,
                  icon: Icons.camera_alt,
                  label: '카메라',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(context, ImageSource.camera);
                  },
                ),
                if (imagePath != null && imagePath!.isNotEmpty)
                  _buildSourceOption(
                    context,
                    icon: Icons.delete,
                    label: '삭제',
                    onTap: () async {
                      Navigator.pop(context);
                      onImageSelected(null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(
              icon,
              size: 30,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      File? imageFile;
      
      if (source == ImageSource.gallery) {
        imageFile = await ImageService.pickImageFromGallery();
      } else {
        imageFile = await ImageService.pickImageFromCamera();
      }

      if (imageFile != null) {
        // 이미지 압축
        final compressedImage = await ImageService.compressImage(imageFile);
        if (compressedImage != null) {
          // 앱 내부 저장소에 저장
          final savedPath = await ImageService.saveImageToAppDirectory(compressedImage);
          if (savedPath != null) {
            onImageSelected(compressedImage);
          } else {
            _showErrorSnackBar(context, '이미지 저장에 실패했습니다.');
          }
        } else {
          _showErrorSnackBar(context, '이미지 압축에 실패했습니다.');
        }
      }
    } catch (e) {
      _showErrorSnackBar(context, '이미지 선택 중 오류가 발생했습니다.');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
