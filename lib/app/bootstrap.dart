class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String storageBucket = String.fromEnvironment('STORAGE_BUCKET', defaultValue: 'pets');
  static const int imgThumbMax = int.fromEnvironment('IMG_THUMB_MAX', defaultValue: 512);
  static const String syncStrategy = String.fromEnvironment('SYNC_STRATEGY', defaultValue: 'latest_wins');
  static const bool analyticsEnabled = bool.fromEnvironment('ANALYTICS_ENABLED', defaultValue: true);
  static const bool crashlyticsEnabled = bool.fromEnvironment('CRASHLYTICS_ENABLED', defaultValue: true);
  static const String defaultLocale = String.fromEnvironment('DEFAULT_LOCALE', defaultValue: 'ko');
  static const String supportedLocales = String.fromEnvironment('SUPPORTED_LOCALES', defaultValue: 'ko,en,ja');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
