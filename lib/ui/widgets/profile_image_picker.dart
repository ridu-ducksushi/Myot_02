import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petcare/data/services/image_service.dart';
import 'package:petcare/ui/theme/app_colors.dart';

class ProfileImagePicker extends StatelessWidget {
  final String? imagePath;
  final Function(File?) onImageSelected;
  final Function(String)? onDefaultIconSelected;
  final double size;
  final bool showEditIcon;
  final String? selectedDefaultIcon;

  const ProfileImagePicker({
    super.key,
    this.imagePath,
    required this.onImageSelected,
    this.onDefaultIconSelected,
    this.size = 120,
    this.showEditIcon = true,
    this.selectedDefaultIcon,
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
    // 기본 아이콘이 선택된 경우 기본 아이콘 표시
    if (selectedDefaultIcon != null) {
      return _buildDefaultAvatar(context);
    }
    
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
      child: _buildDefaultIcon(context),
    );
  }

  Widget _buildDefaultIcon(BuildContext context) {
    if (selectedDefaultIcon != null) {
      final iconData = _getDefaultIconData(selectedDefaultIcon!);
      final color = _getDefaultIconColor(selectedDefaultIcon!);
      
      return Icon(
        iconData,
        size: size * 0.4,
        color: color,
      );
    }
    
    return Icon(
      Icons.pets,
      size: size * 0.4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                _buildSourceOption(
                  context,
                  icon: Icons.pets,
                  label: '기본 아이콘',
                  onTap: () async {
                    Navigator.pop(context);
                    _showDefaultIconsDialog(context);
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

  // 기본 아이콘 목록
  static const List<String> _defaultIcons = [
    'dog1',
    'dog2', 
    'cat1',
    'cat2',
    'rabbit',
    'bird',
    'fish',
    'hamster',
    'turtle',
    'heart'
  ];

  // 기본 아이콘 데이터 매핑
  IconData _getDefaultIconData(String iconName) {
    switch (iconName) {
      case 'dog1':
        return Icons.pets;
      case 'dog2':
        return Icons.pets_outlined;
      case 'cat1':
        return Icons.cruelty_free;
      case 'cat2':
        return Icons.cruelty_free_outlined;
      case 'rabbit':
        return Icons.cruelty_free;
      case 'bird':
        return Icons.flight;
      case 'fish':
        return Icons.water_drop;
      case 'hamster':
        return Icons.circle;
      case 'turtle':
        return Icons.circle_outlined;
      case 'heart':
        return Icons.favorite;
      default:
        return Icons.pets;
    }
  }

  // 기본 아이콘 색상 매핑
  Color _getDefaultIconColor(String iconName) {
    switch (iconName) {
      case 'dog1':
        return const Color(0xFF8B4513); // 갈색
      case 'dog2':
        return const Color(0xFFCD853F); // 페루색
      case 'cat1':
        return const Color(0xFF696969); // 회색
      case 'cat2':
        return const Color(0xFFA9A9A9); // 어두운 회색
      case 'rabbit':
        return const Color(0xFFFFB6C1); // 연분홍
      case 'bird':
        return const Color(0xFF87CEEB); // 하늘색
      case 'fish':
        return const Color(0xFF4169E1); // 로얄블루
      case 'hamster':
        return const Color(0xFFDEB887); // 버프색
      case 'turtle':
        return const Color(0xFF9ACD32); // 옐로우그린
      case 'heart':
        return const Color(0xFFFF69B4); // 핫핑크
      default:
        return const Color(0xFF666666);
    }
  }

  // 기본 아이콘 선택 다이얼로그
  void _showDefaultIconsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
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
              '기본 프로필 아이콘 선택',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: _defaultIcons.length,
                itemBuilder: (context, index) {
                  final iconName = _defaultIcons[index];
                  final isSelected = selectedDefaultIcon == iconName;
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (onDefaultIconSelected != null) {
                        onDefaultIconSelected!(iconName);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                            : Theme.of(context).colorScheme.surfaceVariant,
                        border: Border.all(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getDefaultIconData(iconName),
                        color: _getDefaultIconColor(iconName),
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
