import 'dart:io';

/// Gives every Dart HTTP request a descriptive User-Agent.
///
/// Wikimedia Commons (where the demo photos in `supabase/seed.sql` are
/// hosted) rejects the generic "Dart/x.y" agent, so without this the seeded
/// photos could come back as broken images. Other hosts do not care.
class XReplicaHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent =
        'XReplica/1.0 (university project; Flutter app; contact via GitHub LordBaibus)';
    return client;
  }
}
