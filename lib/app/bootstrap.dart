import 'package:flutter/foundation.dart';
import 'package:petcare/data/local/database.dart';

/// Bootstrap the application with necessary initializations
class AppBootstrap {
  static bool _initialized = false;

  /// Initialize the app with required services
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize local database
      await LocalDatabase.initialize();
      
      if (kDebugMode) {
        print('✅ Local database initialized');
      }

      _initialized = true;
      
      if (kDebugMode) {
        print('✅ App bootstrap completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ App bootstrap failed: $e');
      }
      rethrow;
    }
  }

  /// Clean up resources
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      await LocalDatabase.instance.close();
      
      if (kDebugMode) {
        print('✅ App cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ App cleanup failed: $e');
      }
    }
  }
}