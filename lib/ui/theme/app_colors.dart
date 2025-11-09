import 'package:flutter/material.dart';

/// App-specific color constants and utilities
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary brand colors
  static const Color primary = Color(0xFF6750A4);
  static const Color primaryContainer = Color(0xFFEADDFF);
  
  // Pet-specific colors
  static const Color dogColor = Color(0xFFFF8C00);      // Orange
  static const Color catColor = Color(0xFF2196F3);      // Blue
  static const Color birdColor = Color(0xFF4CAF50);     // Green
  static const Color fishColor = Color(0xFF00BCD4);     // Cyan
  static const Color rabbitColor = Color(0xFFE91E63);   // Pink
  static const Color hamsterColor = Color(0xFFFFC107);  // Amber
  static const Color reptileColor = Color(0xFF795548);  // Brown
  static const Color otherColor = Color(0xFF9C27B0);    // Purple

  // Reminder priority colors
  static const Color highPriority = Color(0xFFF44336);    // Red
  static const Color mediumPriority = Color(0xFFFF9800);  // Orange
  static const Color lowPriority = Color(0xFF4CAF50);     // Green

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Gradient colors for cards and backgrounds
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6750A4), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient petGradient = LinearGradient(
    colors: [Color(0xFFFF8C00), Color(0xFFFFB74D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient healthGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Map<String, _RecordCategoryPalette> _recordCategoryPalettes = {
    'food': _RecordCategoryPalette(
      primary: Color(0xFFE91E63),
      soft: Color(0xFFFFE4EC),
      dark: Color(0xFFD81B60),
    ),
    'activity': _RecordCategoryPalette(
      primary: Color(0xFF4CAF50),
      soft: Color(0xFFE3F5E5),
      dark: Color(0xFF2E7D32),
    ),
    'poop': _RecordCategoryPalette(
      primary: Color(0xFFFF9800),
      soft: Color(0xFFFFF2DE),
      dark: Color(0xFFEF6C00),
    ),
    'health': _RecordCategoryPalette(
      primary: Color(0xFF2196F3),
      soft: Color(0xFFDFECFF),
      dark: Color(0xFF1565C0),
    ),
  };

  // Shadow colors
  static const Color lightShadow = Color(0x1A000000);
  static const Color mediumShadow = Color(0x33000000);

  /// Get color for pet species
  static Color getSpeciesColor(String species) {
    switch (species.toLowerCase()) {
      case 'dog':
        return dogColor;
      case 'cat':
        return catColor;
      case 'bird':
        return birdColor;
      case 'fish':
        return fishColor;
      case 'rabbit':
        return rabbitColor;
      case 'hamster':
        return hamsterColor;
      case 'reptile':
        return reptileColor;
      default:
        return otherColor;
    }
  }

  /// Get color for record type based on main category
  static Color getRecordTypeColor(String type) {
    final category = _categoryKeyForRecordType(type);
    final palette = _paletteForCategory(category);
    if (palette == null) {
      return Colors.pink;
    }
    return palette.primary;
  }

  /// Pastel background colors for record categories (FAB/submenu)
  static Color getRecordCategorySoftColor(String category) {
    final palette = _paletteForCategory(category) ?? _paletteForCategory('food')!;
    return palette.soft;
  }

  /// Darker accent colors for record categories (icons/text)
  static Color getRecordCategoryDarkColor(String category) {
    final palette = _paletteForCategory(category) ?? _paletteForCategory('food')!;
    return palette.dark;
  }

  static _RecordCategoryPalette? _paletteForCategory(String category) {
    final key = _normalizeCategoryKey(category);
    return _recordCategoryPalettes[key];
  }

  static String _normalizeCategoryKey(String category) {
    switch (category.toLowerCase()) {
      case 'activity':
      case 'play':
        return 'activity';
      case 'health':
        return 'health';
      case 'poop':
        return 'poop';
      case 'food':
      default:
        return 'food';
    }
  }

  static String _categoryKeyForRecordType(String type) {
    switch (type.toLowerCase()) {
      case 'food_meal':
      case 'food_snack':
      case 'food_water':
      case 'food_treat':
      case 'food_med':
      case 'food_supplement':
      case 'meal':
      case 'snack':
        return 'food';
      case 'health_med':
      case 'health_supplement':
      case 'health_vaccine':
      case 'health_visit':
      case 'health_weight':
      case 'med':
      case 'medicine':
      case 'vaccine':
      case 'visit':
      case 'weight':
        return 'health';
      case 'poop_feces':
      case 'poop_urine':
      case 'poop_other':
      case 'hygiene_brush':
      case 'litter':
        return 'poop';
      case 'activity_play':
      case 'activity_explore':
      case 'activity_outing':
      case 'activity_rest':
      case 'activity_other':
      case 'activity_groom':
      case 'activity_walk':
      case 'play':
      case 'groom':
        return 'activity';
      default:
        return 'food';
    }
  }

  /// Get color for reminder priority
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return highPriority;
      case 'medium':
        return mediumPriority;
      case 'low':
        return lowPriority;
      default:
        return mediumPriority;
    }
  }

  /// Get gradient for pet cards
  static LinearGradient getPetGradient(String species) {
    final baseColor = getSpeciesColor(species);
    return LinearGradient(
      colors: [
        baseColor,
        baseColor.withOpacity(0.7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Get color with opacity for backgrounds
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  /// Light/Dark theme adaptive colors
  static Color adaptiveColor({
    required Color light,
    required Color dark,
    required bool isDark,
  }) {
    return isDark ? dark : light;
  }

  // Common opacity values
  static const double opacity10 = 0.1;
  static const double opacity20 = 0.2;
  static const double opacity30 = 0.3;
  static const double opacity50 = 0.5;
  static const double opacity70 = 0.7;
  static const double opacity80 = 0.8;
  static const double opacity90 = 0.9;
}

class _RecordCategoryPalette {
  const _RecordCategoryPalette({
    required this.primary,
    required this.soft,
    required this.dark,
  });

  final Color primary;
  final Color soft;
  final Color dark;
}
