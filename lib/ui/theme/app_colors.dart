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

  // Record type colors
  static const Color mealColor = Color(0xFF4CAF50);     // Green
  static const Color snackColor = Color(0xFF8BC34A);    // Light Green
  static const Color medicineColor = Color(0xFFF44336); // Red
  static const Color vaccineColor = Color(0xFF3F51B5);  // Indigo
  static const Color visitColor = Color(0xFF9C27B0);    // Purple
  static const Color weightColor = Color(0xFF00BCD4);   // Cyan
  static const Color litterColor = Color(0xFF795548);   // Brown
  static const Color playColor = Color(0xFFFF9800);     // Orange
  static const Color groomeColor = Color(0xFFE91E63);   // Pink

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

  /// Get color for record type
  static Color getRecordTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meal':
        return mealColor;
      case 'snack':
        return snackColor;
      case 'med':
      case 'medicine':
        return medicineColor;
      case 'vaccine':
        return vaccineColor;
      case 'visit':
        return visitColor;
      case 'weight':
        return weightColor;
      case 'litter':
        return litterColor;
      case 'play':
        return playColor;
      case 'groom':
        return groomeColor;
      default:
        return otherColor;
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
