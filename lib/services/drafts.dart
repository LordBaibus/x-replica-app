import 'user_prefs.dart';

/// A post that was written but not sent. Only the text (and the thread) is
/// kept; photos, polls and GIFs are not part of a draft.
class DraftPost {
  const DraftPost({
    required this.id,
    required this.texts,
    required this.savedAt,
    this.replyScope = 'everyone',
  });

  final String id;

  /// One entry per post of the thread (a single entry for a normal post).
  final List<String> texts;
  final DateTime savedAt;
  final String replyScope;

  String get preview {
    for (final t in texts) {
      if (t.trim().isNotEmpty) return t.trim();
    }
    return '';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'texts': texts,
        'saved_at': savedAt.toUtc().toIso8601String(),
        'reply_scope': replyScope,
      };

  static DraftPost? fromMap(Map<String, dynamic> m) {
    final id = m['id'];
    final texts = m['texts'];
    if (id is! String || texts is! List) return null;
    return DraftPost(
      id: id,
      texts: [for (final t in texts) t.toString()],
      savedAt: DateTime.tryParse('${m['saved_at']}')?.toLocal() ??
          DateTime.now(),
      replyScope: (m['reply_scope'] as String?) ?? 'everyone',
    );
  }
}

/// Drafts of the signed-in account. They live in the account's preferences,
/// so they follow the person to another phone.
class Drafts {
  Drafts._();

  static const String key = 'post_drafts';
  static const int max = 50;

  /// Newest first.
  static List<DraftPost> all() {
    final list = [
      for (final m in UserPrefs.instance.maps(key))
        if (DraftPost.fromMap(m) != null) DraftPost.fromMap(m)!,
    ];
    list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Adds the draft, or replaces the one with the same id.
  static Future<void> save(DraftPost draft) async {
    final rest = all().where((d) => d.id != draft.id).toList();
    final next = [draft, ...rest].take(max).toList();
    await UserPrefs.instance.set(key, [for (final d in next) d.toMap()]);
  }

  static Future<void> remove(String id) async {
    final next = all().where((d) => d.id != id).toList();
    await UserPrefs.instance.set(
      key,
      next.isEmpty ? null : [for (final d in next) d.toMap()],
    );
  }
}
