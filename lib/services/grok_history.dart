import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// One message of a Grok conversation.
class GrokMsg {
  const GrokMsg._(this.fromUser, this.text, this.image, this.isImage,
      [this.attachment]);

  /// A message I wrote.
  const GrokMsg.user(String text, {Uint8List? attachment})
      : this._(true, text, null, false, attachment);

  /// An answer from the assistant.
  const GrokMsg.bot(String text) : this._(false, text, null, false);

  /// A picture made from [prompt]. The picture itself is only kept while the
  /// chat is open; saved chats keep the prompt.
  const GrokMsg.image(String prompt, Uint8List? image)
      : this._(false, prompt, image, true);

  final bool fromUser;

  /// True for a generated picture (its [image] is null in a reopened chat).
  final bool isImage;

  /// Photo I sent with my message (not kept in saved chats).
  final Uint8List? attachment;

  /// Text of the message, or the prompt of an image.
  final String text;
  final Uint8List? image;
}

/// A saved conversation.
class GrokChat {
  GrokChat({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<GrokMsg> messages;
}

/// Conversations are kept on this phone (SharedPreferences), one list per
/// account, newest first, at most [maxChats].
class GrokHistory {
  GrokHistory._();

  static const int maxChats = 30;

  static String get _key => 'grok_chats_${Api.uid}';

  static Future<List<GrokChat>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final chats = <GrokChat>[
        for (final c in list)
          GrokChat(
            id: c['id'] as String,
            title: (c['title'] as String?) ?? 'New chat',
            updatedAt: DateTime.tryParse('${c['at']}') ?? DateTime.now(),
            messages: [
              for (final m in (c['m'] as List).cast<Map<String, dynamic>>())
                if (m['u'] == true)
                  GrokMsg.user(m['t'] as String)
                else if (m['i'] == true)
                  GrokMsg.image(m['t'] as String, null)
                else
                  GrokMsg.bot(m['t'] as String),
            ],
          ),
      ];
      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return chats;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<GrokChat> chats) async {
    final prefs = await SharedPreferences.getInstance();
    final data = [
      for (final c in chats.take(maxChats))
        {
          'id': c.id,
          'title': c.title,
          'at': c.updatedAt.toIso8601String(),
          'm': [
            for (final m in c.messages)
              {
                'u': m.fromUser,
                't': m.text,
                'i': m.isImage,
              },
          ],
        },
    ];
    await prefs.setString(_key, jsonEncode(data));
  }

  static Future<void> save(GrokChat chat) async {
    final chats = await load();
    chats.removeWhere((c) => c.id == chat.id);
    chats.insert(0, chat);
    await _write(chats);
  }

  /// Deletes every saved conversation of this account.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> delete(String id) async {
    final chats = await load();
    chats.removeWhere((c) => c.id == id);
    await _write(chats);
  }
}
