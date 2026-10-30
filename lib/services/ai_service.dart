import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'image_picker_service.dart';

/// The composer's AI helper ("Generate image" / "Enhance your post").
///
/// The app never talks to the AI provider directly: it calls the Supabase
/// Edge Function `ai-assist` (supabase/functions/ai-assist), which holds the
/// API key as a secret. That keeps the key out of the app.
class AiAssist {
  AiAssist._();

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke('ai-assist', body: body);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) throw Exception('${data['error']}');
        return data;
      }
      throw Exception('The AI helper sent an unexpected answer.');
    } on FunctionException catch (e) {
      if (e.status == 404) {
        throw Exception(
          'The AI helper isn’t set up yet. Deploy the ai-assist function '
          'and add your API key (see README).',
        );
      }
      final d = e.details;
      if (d is Map && d['error'] != null) throw Exception('${d['error']}');
      if (e.status == 546 || e.status == 504 || e.status == 408) {
        throw Exception(
          'The AI helper took too long. Try again with a shorter request.',
        );
      }
      final extra = d is String && d.trim().isNotEmpty ? ' ${d.trim()}' : '';
      throw Exception('The AI helper failed (error ${e.status}).$extra');
    }
  }

  /// `@grok` in a post (not part of an e-mail address or a longer name).
  static final RegExp _grokMention = RegExp(
    r'(^|[^A-Za-z0-9_])@grok(?![A-Za-z0-9_])',
    caseSensitive: false,
  );
  static bool mentionsGrok(String text) => _grokMention.hasMatch(text);

  /// Counts up whenever @grok has just answered a post of mine (open post
  /// pages reload their replies).
  static final ValueNotifier<int> grokReplied = ValueNotifier<int>(0);

  /// Why @grok could not answer my last mention (null = nothing wrong).
  static final ValueNotifier<String?> grokError = ValueNotifier<String?>(null);

  /// Asks the server to answer the post [postId] (which mentions @grok) as a
  /// reply from the @grok account. The server checks everything itself; this
  /// never throws, it reports through [grokReplied] / [grokError].
  static Future<void> answerMention(String postId) async {
    try {
      await _call({'action': 'mention', 'post_id': postId});
      grokReplied.value++;
    } catch (e) {
      grokError.value = '$e'.replaceFirst('Exception: ', '');
    }
  }

  /// Rewrites [text] so it reads better (still at most 280 characters).
  static Future<String> enhance(String text) async {
    final data = await _call({'action': 'enhance', 'text': text});
    final out = (data['text'] as String?)?.trim() ?? '';
    if (out.isEmpty) throw Exception('The AI helper returned nothing.');
    return out;
  }

  /// Next answer of the assistant. [messages] is the conversation so far:
  /// maps with `role` ('user' / 'assistant') and `content`. [persona] is an
  /// optional role to play ("Hire a bot"); [image] a photo for the newest
  /// message.
  static Future<String> chat(
    List<Map<String, String>> messages, {
    String? persona,
    PickedImage? image,
  }) async {
    final data = await _call({
      'action': 'chat',
      'messages': messages,
      if (persona != null) 'persona': persona,
      if (image != null) ...{
        'image': base64Encode(image.bytes),
        'mime': image.contentType,
      },
    });
    final out = (data['text'] as String?)?.trim() ?? '';
    if (out.isEmpty) throw Exception('The assistant returned nothing.');
    return out;
  }

  /// Changes [image] as described by [prompt] and returns the new picture.
  static Future<PickedImage> editImage(String prompt, PickedImage image) async {
    final data = await _call({
      'action': 'edit',
      'prompt': prompt,
      'image': base64Encode(image.bytes),
      'mime': image.contentType,
    });
    final b64 = data['image'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception('The AI helper returned no image.');
    }
    return PickedImage(base64Decode(b64), 'png');
  }

  /// Makes a picture from [prompt].
  static Future<PickedImage> generateImage(String prompt) async {
    final data = await _call({'action': 'image', 'prompt': prompt});
    final b64 = data['image'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception('The AI helper returned no image.');
    }
    return PickedImage(base64Decode(b64), 'png');
  }
}
