/// App-wide constants
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // Contact email
  static const String contactEmail = 'ridusoft@gmail.com';

  // Pet species options
  static const List<String> petSpecies = ['Dog', 'Cat', 'Other'];

  // Sex options (display)
  static const List<String> sexOptions = ['남아', '여아'];

  // Sex mapping (display -> DB)
  static const Map<String, String> sexMapping = {
    '남아': 'Male',
    '여아': 'Female',
  };

  // Settings UI dimensions
  static const double petCardHeight = 240.0;
  static const double petCardWidth = 200.0;
  static const double petCardSpacing = 26.0;
  static const double selectedPetBorderWidth = 2.5;
  static const double selectedPetElevation = 4.0;
  static const double defaultPetElevation = 2.0;
  static const double profileEditButtonSpacing = 230.0;
  static const double profileEditBottomSpacing = 40.0;
  static const double avatarSize = 60.0;
  static const double iconSize = 30.0;
  static const double defaultPadding = 16.0;
  static const double mediumPadding = 24.0;
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 12.0;
  static const double largeSpacing = 16.0;

  // Edge Function timeout
  static const Duration edgeFunctionTimeout = Duration(seconds: 20);
}

