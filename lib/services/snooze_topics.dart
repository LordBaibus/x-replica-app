import 'package:flutter/cupertino.dart';

import '../models/models.dart';
import 'user_prefs.dart';

/// One row of "Snooze Topics".
class SnoozeTopic {
  const SnoozeTopic({
    required this.id,
    required this.label,
    required this.icon,
    this.words = const [],
    this.exactWords = const [],
    this.video = false,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Lower-case word beginnings that put a post under the topic ("movie"
  /// also catches "movies").
  final List<String> words;

  /// Short words that must stand alone ("ai" must not match "again").
  final List<String> exactWords;

  /// The topic is "any post with a video".
  final bool video;

  bool matches(Post p) {
    if (video && p.videoUrl != null && p.videoUrl!.isNotEmpty) return true;
    final text = p.content.toLowerCase();
    if (text.isEmpty) return false;
    for (final w in words) {
      if (RegExp('(^|[^a-z0-9])${RegExp.escape(w)}').hasMatch(text)) return true;
    }
    for (final w in exactWords) {
      if (RegExp('(^|[^a-z0-9])${RegExp.escape(w)}([^a-z0-9]|\$)')
          .hasMatch(text)) {
        return true;
      }
    }
    return false;
  }
}

/// "Snooze Topics" of the For you timeline: topics the person switched off
/// for 24 hours. Kept in the account's prefs (key `snoozed_topics`, topic id
/// -> time it ends), so it follows the account and wears off by itself.
class SnoozedTopics {
  SnoozedTopics._();

  static final SnoozedTopics instance = SnoozedTopics._();

  static const _key = 'snoozed_topics';
  static const duration = Duration(hours: 24);

  static const topics = <SnoozeTopic>[
    SnoozeTopic(
      id: 'politics',
      label: 'Politics',
      icon: CupertinoIcons.flag,
      words: ['politic', 'election', 'government', 'senat', 'mayor',
        'city hall', 'barangay', 'congress', 'president', 'vote'],
    ),
    SnoozeTopic(
      id: 'sports',
      label: 'Sports',
      icon: CupertinoIcons.sportscourt,
      words: ['sport', 'nba', 'football', 'basketball', 'soccer', 'tennis',
        'boxing', 'marathon', 'playoff', 'hoops', 'league'],
    ),
    SnoozeTopic(
      id: 'business',
      label: 'Business & Finance',
      icon: CupertinoIcons.briefcase,
      words: ['business', 'finance', 'stock', 'market', 'startup', 'invest',
        'budget', 'savings', 'sari-sari'],
    ),
    SnoozeTopic(
      id: 'tech',
      label: 'Science & Technology',
      icon: CupertinoIcons.lab_flask,
      words: ['tech', 'science', 'research', 'climate', 'software', 'coding',
        'flutter', 'programming', 'gadget', 'phone', 'battery', 'app '],
    ),
    SnoozeTopic(
      id: 'entertainment',
      label: 'Entertainment & Arts',
      icon: CupertinoIcons.film,
      words: ['movie', 'film', 'series', 'netflix', 'music', 'album',
        'concert', 'song', 'celebrity', 'kpop', 'anime', 'mural', 'sketch',
        'doodle', 'illustrat', 'painting', 'comedy', 'stand-up'],
    ),
    SnoozeTopic(
      id: 'ai',
      label: 'Artificial Intelligence',
      icon: CupertinoIcons.sparkles,
      words: ['artificial intelligence', 'chatgpt', 'grok', 'llm',
        'machine learning', 'generative'],
      exactWords: ['ai'],
    ),
    SnoozeTopic(
      id: 'gaming',
      label: 'Gaming',
      icon: CupertinoIcons.game_controller,
      words: ['gaming', 'gamer', 'esports', 'valorant', 'playstation',
        'game boy', 'stream', 'ranked'],
    ),
    SnoozeTopic(
      id: 'crypto',
      label: 'Crypto',
      icon: CupertinoIcons.money_dollar_circle,
      words: ['crypto', 'bitcoin', 'ethereum'],
    ),
    SnoozeTopic(
      id: 'videos',
      label: 'Videos',
      icon: CupertinoIcons.videocam,
      video: true,
    ),
  ];

  Map<String, int> _read() {
    final raw = UserPrefs.instance.maps(_key);
    // Stored as one map inside a list so it fits UserPrefs' helpers.
    final out = <String, int>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final m in raw) {
      for (final e in m.entries) {
        final until = e.value is num ? (e.value as num).toInt() : 0;
        if (until > now) out[e.key] = until;
      }
    }
    return out;
  }

  Future<void> _write(Map<String, int> m) =>
      UserPrefs.instance.set(_key, m.isEmpty ? null : [m]);

  /// Ids of the topics that are snoozed right now.
  Set<String> get active => _read().keys.toSet();

  bool isSnoozed(String id) => _read().containsKey(id);

  Future<void> set(String id, bool snoozed) {
    final m = _read();
    if (snoozed) {
      m[id] = DateTime.now().add(duration).millisecondsSinceEpoch;
    } else {
      m.remove(id);
    }
    return _write(m);
  }

  Future<void> reset() => _write({});

  /// True when [post] belongs to a topic that is snoozed.
  bool hides(Post post) {
    final on = active;
    if (on.isEmpty) return false;
    for (final t in topics) {
      if (on.contains(t.id) && t.matches(post)) return true;
    }
    return false;
  }
}
