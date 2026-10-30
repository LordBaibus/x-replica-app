import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// One GIF from the GIPHY search.
class GifItem {
  const GifItem({
    required this.id,
    required this.previewUrl,
    required this.url,
    required this.aspect,
  });

  final String id;

  /// Small version shown in the picker grid.
  final String previewUrl;

  /// Version saved with the post.
  final String url;

  /// width / height
  final double aspect;
}

/// Trending / searched GIFs from GIPHY (free beta key, 100 calls an hour).
/// Google is shutting down the Tenor API, so GIPHY is used instead.
class GifService {
  GifService._();

  static bool get isConfigured => AppConfig.giphyApiKey.isNotEmpty;

  static Future<List<GifItem>> trending({int offset = 0}) =>
      _fetch('trending', const {}, offset);

  static Future<List<GifItem>> search(String query, {int offset = 0}) =>
      _fetch('search', {'q': query}, offset);

  static Future<List<GifItem>> _fetch(
    String endpoint,
    Map<String, String> extra,
    int offset,
  ) async {
    final uri = Uri.https('api.giphy.com', '/v1/gifs/$endpoint', {
      'api_key': AppConfig.giphyApiKey,
      'limit': '24',
      'offset': '$offset',
      'rating': 'pg-13',
      ...extra,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 429) {
      throw Exception('Too many GIF requests. Try again in a little while.');
    }
    if (res.statusCode != 200) {
      throw Exception('Couldn’t load GIFs (error ${res.statusCode}).');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['data'] as List?) ?? const [];
    final out = <GifItem>[];
    for (final raw in list) {
      final d = raw as Map<String, dynamic>;
      final images = d['images'] as Map<String, dynamic>?;
      if (images == null) continue;
      final fixed = images['fixed_width'] as Map<String, dynamic>?;
      final post = (images['downsized_medium'] ?? images['original'])
          as Map<String, dynamic>?;
      final previewUrl = fixed?['url'] as String?;
      final url = post?['url'] as String?;
      if (previewUrl == null || url == null) continue;
      final w = double.tryParse('${fixed?['width']}') ?? 1;
      final h = double.tryParse('${fixed?['height']}') ?? 1;
      out.add(GifItem(
        id: (d['id'] as String?) ?? url,
        previewUrl: previewUrl,
        url: url,
        aspect: h <= 0 ? 1 : w / h,
      ));
    }
    return out;
  }
}
