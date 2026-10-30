import 'package:flutter/cupertino.dart';

/// A topic people can pick during sign-up ("Pick your interests"). The same
/// topics become the extra tabs on the home timeline and the Explore tabs:
/// a post belongs to a topic when its text contains one of [keywords].
class Topic {
  const Topic({
    required this.id,
    required this.label,
    required this.icon,
    required this.keywords,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Lower-case words / hashtags that put a post under this topic.
  final List<String> keywords;
}

class Topics {
  Topics._();

  static const List<Topic> all = [
    Topic(
      id: 'news',
      label: 'News',
      icon: CupertinoIcons.news,
      keywords: ['news', 'breaking', 'headline', 'report'],
    ),
    Topic(
      id: 'sports',
      label: 'Sports',
      icon: CupertinoIcons.sportscourt,
      keywords: ['sports', 'nba', 'football', 'basketball', 'soccer', 'game'],
    ),
    Topic(
      id: 'business',
      label: 'Business & finance',
      icon: CupertinoIcons.chart_bar_alt_fill,
      keywords: ['business', 'finance', 'stocks', 'market', 'startup'],
    ),
    Topic(
      id: 'technology',
      label: 'Technology',
      icon: CupertinoIcons.device_laptop,
      keywords: ['tech', 'technology', 'coding', 'flutter', 'software', 'programming'],
    ),
    Topic(
      id: 'politics',
      label: 'Politics',
      icon: CupertinoIcons.flag,
      keywords: ['politics', 'election', 'government', 'senate'],
    ),
    Topic(
      id: 'memes',
      label: 'Memes',
      icon: CupertinoIcons.smiley,
      keywords: ['meme', 'memes', 'lol', 'funny'],
    ),
    Topic(
      id: 'crypto',
      label: 'Crypto',
      icon: CupertinoIcons.money_dollar_circle,
      keywords: ['crypto', 'bitcoin', 'ethereum'],
    ),
    Topic(
      id: 'fashion',
      label: 'Fashion',
      icon: CupertinoIcons.bag,
      keywords: ['fashion', 'style', 'outfit', 'ootd'],
    ),
    Topic(
      id: 'games',
      label: 'Video Games',
      icon: CupertinoIcons.game_controller,
      keywords: ['gaming', 'gamer', 'videogame', 'esports', 'playstation'],
    ),
    Topic(
      id: 'movies',
      label: 'Movies & TV',
      icon: CupertinoIcons.film,
      keywords: ['movie', 'movies', 'film', 'series', 'netflix', 'television'],
    ),
    Topic(
      id: 'music',
      label: 'Music',
      icon: CupertinoIcons.music_note_2,
      keywords: ['music', 'song', 'album', 'concert'],
    ),
    Topic(
      id: 'travel',
      label: 'Travel',
      icon: CupertinoIcons.airplane,
      keywords: ['travel', 'trip', 'vacation', 'flight'],
    ),
    Topic(
      id: 'food',
      label: 'Food',
      icon: CupertinoIcons.cart,
      keywords: ['food', 'recipe', 'dinner', 'lunch', 'cooking'],
    ),
    Topic(
      id: 'health',
      label: 'Health & Fitness',
      icon: CupertinoIcons.heart,
      keywords: ['health', 'fitness', 'workout', 'gym'],
    ),
    Topic(
      id: 'entertainment',
      label: 'Entertainment',
      icon: CupertinoIcons.star,
      keywords: ['entertainment', 'celebrity', 'showbiz', 'kpop'],
    ),
  ];

  static Topic? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Topics for the ids saved on a profile (unknown ids are skipped).
  static List<Topic> fromIds(Iterable<String> ids) {
    final out = <Topic>[];
    for (final id in ids) {
      final t = byId(id);
      if (t != null) out.add(t);
    }
    return out;
  }
}
