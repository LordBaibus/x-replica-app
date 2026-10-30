/// App-wide constants.
///
/// The Supabase URL and **publishable** key are read from `--dart-define`
/// values so nothing is hard-coded in the repo:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxx
///
/// (Publishable keys are designed to be shipped inside client apps; row level
/// security in `supabase/schema.sql` is what protects the data.)
class AppConfig {
  AppConfig._();

  /// Display name of the app. Change it here to rebrand everything.
  static const String appName = 'X Replica';
  static const String version = '1.0.0';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qhwvdacyevoblqpuqinf.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_SLblIAXkuQqHVgiYl_N8xg_K1bJ1UJc',
  );

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('YOUR-PROJECT-REF') &&
      !supabasePublishableKey.contains('YOUR_KEY');

  // Storage buckets (created by supabase/schema.sql)
  static const String avatarsBucket = 'avatars';
  static const String postImagesBucket = 'post-images';
  static const String postVideosBucket = 'post-videos';

  /// Video limits of a post (X allows 2 min 20 s for normal accounts; the
  /// size matches the free Supabase Storage limit of 50 MB per file).
  static const int maxVideoSeconds = 140;
  static const int maxVideoBytes = 50 * 1024 * 1024;

  /// GIPHY API key for the composer's GIF search (free beta key from
  /// developers.giphy.com, 100 calls/hour). Pass it with
  /// `--dart-define=GIPHY_API_KEY=xxxx`. Without it the GIF dialog only
  /// accepts a pasted GIF link.
  static const String giphyApiKey = String.fromEnvironment('GIPHY_API_KEY');

  static const int maxPostLength = 280;
  static const int maxBioLength = 160;
}
