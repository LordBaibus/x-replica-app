import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:x_replica/models/models.dart';
import 'package:x_replica/services/drafts.dart';
import 'package:x_replica/widgets/avatar.dart';
import 'package:x_replica/widgets/badges.dart';
import 'package:x_replica/widgets/post_menus.dart';

Map<String, dynamic> _row({
  String? imageUrl,
  List<String>? imageUrls,
  String? verified,
  int? bookmarks,
}) =>
    {
      'id': '0b0f6b1e-5b3a-4c53-9c1a-0f6f4f1a2b3c',
      'user_id': 'u1',
      'content': 'hello',
      'created_at': '2026-10-23T20:06:00Z',
      'username': 'sam',
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'author_verified': verified,
      'bookmark_count': bookmarks,
    };

void main() {
  group('post pictures', () {
    test('an older post with one image_url shows that picture', () {
      final p = Post.fromMap(_row(imageUrl: 'a.png'));
      expect(p.images, ['a.png']);
    });

    test('image_urls wins and keeps the order', () {
      final p = Post.fromMap(
        _row(imageUrl: 'a.png', imageUrls: ['a.png', 'b.png', 'c.png']),
      );
      expect(p.images, ['a.png', 'b.png', 'c.png']);
    });

    test('no picture gives an empty list', () {
      expect(Post.fromMap(_row()).images, isEmpty);
    });
  });

  group('post counters', () {
    test('bookmark count and author badge are read from the view', () {
      final p = Post.fromMap(_row(verified: 'gold', bookmarks: 12));
      expect(p.bookmarkCount, 12);
      expect(p.authorVerified, 'gold');
    });

    test('copyWith changes the bookmark count only', () {
      final p = Post.fromMap(_row(bookmarks: 3));
      final q = p.copyWith(bookmarkCount: 4);
      expect(q.bookmarkCount, 4);
      expect(q.content, p.content);
    });
  });

  group('badges and avatars', () {
    test('badge colours', () {
      expect(verifiedColor('gold'), const Color(0xFFE2B719));
      expect(verifiedColor('gray'), const Color(0xFF829AAB));
      expect(verifiedColor('blue'), const Color(0xFF1D9BF0));
    });

    test('only gold accounts get a rounded-square picture', () {
      expect(Avatar.isSquare('gold'), isTrue);
      expect(Avatar.isSquare('blue'), isFalse);
      expect(Avatar.isSquare(null), isFalse);
    });
  });

  test('a post link uses the app scheme', () {
    final p = Post.fromMap(_row());
    expect(postLink(p), 'xreplica://post/${p.id}');
  });

  test('reply sort labels', () {
    expect(replySortLabel(ReplySort.relevant), 'Relevant');
    expect(replySortLabel(ReplySort.recent), 'Recent');
    expect(replySortLabel(ReplySort.liked), 'Liked');
  });

  test('a quoted post keeps its badge and time', () {
    final q = QuotedPost.fromMap({
      'quote_id': 'q1',
      'quote_username': 'jai',
      'quote_content': 'hello',
      'quote_verified': 'gold',
      'quote_created_at': '2026-10-01T10:00:00Z',
    })!;
    expect(q.verified, 'gold');
    expect(q.createdAt, isNotNull);
    expect(q.authorName, 'jai');
  });

  test('a draft survives being saved and loaded', () {
    final d = DraftPost(
      id: '1',
      texts: const ['first', 'second'],
      savedAt: DateTime.utc(2026, 10, 27, 12),
      replyScope: 'following',
    );
    final back = DraftPost.fromMap(d.toMap())!;
    expect(back.id, '1');
    expect(back.texts, ['first', 'second']);
    expect(back.replyScope, 'following');
    expect(back.preview, 'first');
    expect(DraftPost.fromMap({'id': 5}), isNull);
  });

  test('a post knows when it was edited', () {
    final p = Post.fromMap(_row());
    expect(p.editedAt, isNull);
    final e = Post.fromMap({..._row(), 'edited_at': '2026-10-27T10:00:00Z'});
    expect(e.editedAt, isNotNull);
    expect(p.copyWith(content: 'new').content, 'new');
  });
}
