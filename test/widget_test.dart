// Model parsing tests (the default counter-app test was replaced because this
// app needs a Supabase connection to render).
import 'package:flutter_test/flutter_test.dart';
import 'package:x_replica/models/models.dart';

void main() {
  group('Profile', () {
    test('parses a profile_stats row', () {
      final p = Profile.fromMap({
        'id': 'u1',
        'username': 'jai',
        'display_name': 'Jai',
        'bio': 'hello',
        'avatar_url': null,
        'follower_count': 3,
        'following_count': 5,
        'post_count': 7,
        'followed_by_me': true,
      });
      expect(p.name, 'Jai');
      expect(p.followerCount, 3);
      expect(p.followingCount, 5);
      expect(p.postCount, 7);
      expect(p.followedByMe, isTrue);
    });

    test('falls back to username when display name is empty', () {
      final p = Profile.fromMap({'id': 'u1', 'username': 'jai', 'display_name': ''});
      expect(p.name, 'jai');
    });
  });

  group('Post', () {
    final row = {
      'id': 'p1',
      'user_id': 'u1',
      'content': 'Hello world',
      'image_url': null,
      'created_at': '2026-10-16T08:00:00+00:00',
      'username': 'jai',
      'display_name': 'Jai',
      'avatar_url': null,
      'like_count': 2,
      'liked_by_me': false,
    };

    test('parses a posts_feed row', () {
      final post = Post.fromMap(row);
      expect(post.content, 'Hello world');
      expect(post.likeCount, 2);
      expect(post.authorName, 'Jai');
      expect(post.createdAt.toUtc().hour, 8);
    });

    test('copyWith updates only likes', () {
      final post = Post.fromMap(row).copyWith(likedByMe: true, likeCount: 3);
      expect(post.likedByMe, isTrue);
      expect(post.likeCount, 3);
      expect(post.content, 'Hello world');
    });
  });

  group('Conversation / Message', () {
    test('parses my_conversations() output', () {
      final c = Conversation.fromMap({
        'partner_id': 'u2',
        'username': 'sam',
        'display_name': 'Sam',
        'avatar_url': null,
        'last_message': 'hey',
        'last_at': '2026-10-16T08:00:00+00:00',
        'last_from_me': true,
        'unread_count': 4,
      });
      expect(c.unreadCount, 4);
      expect(c.lastFromMe, isTrue);
      expect(c.partner.id, 'u2');
      expect(c.partner.name, 'Sam');
    });

    test('parses a message with and without read_at', () {
      final base = {
        'id': 'm1',
        'sender_id': 'a',
        'receiver_id': 'b',
        'content': 'hi',
        'created_at': '2026-10-16T08:00:00+00:00',
      };
      expect(Message.fromMap({...base, 'read_at': null}).readAt, isNull);
      expect(
        Message.fromMap({...base, 'read_at': '2026-10-16T08:05:00+00:00'}).readAt,
        isNotNull,
      );
    });
  });
}
