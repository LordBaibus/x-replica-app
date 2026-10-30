import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_replica/core/x_icons.dart';
import 'package:x_replica/models/models.dart';
import 'package:x_replica/services/image_picker_service.dart';
import 'package:x_replica/services/saved_accounts.dart';
import 'package:x_replica/widgets/post_skeleton.dart';
import 'package:x_replica/widgets/post_video.dart';

void main() {
  group('CommunityNote', () {
    test('reads the community_notes_view row', () {
      final n = CommunityNote.fromMap({
        'id': 'n1',
        'post_id': 'p1',
        'author_id': 'u1',
        'author_username': 'jai',
        'body': 'Missing context.',
        'source_url': 'https://example.com',
        'created_at': '2026-10-20T10:00:00Z',
        'helpful_count': 3,
        'not_helpful_count': 1,
        'my_rating': true,
        'shown': true,
      });
      expect(n.authorUsername, 'jai');
      expect(n.helpfulCount, 3);
      expect(n.myRating, isTrue);
      expect(n.shown, isTrue);
    });

    test('missing counts and rating default to zero / null', () {
      final n = CommunityNote.fromMap({
        'id': 'n1',
        'post_id': 'p1',
        'author_id': 'u1',
        'created_at': '2026-10-20T10:00:00Z',
      });
      expect(n.helpfulCount, 0);
      expect(n.notHelpfulCount, 0);
      expect(n.myRating, isNull);
      expect(n.shown, isFalse);
    });
  });

  group('PostAnalytics', () {
    test('reads the post_analytics json and adds up engagements', () {
      final a = PostAnalytics.fromMap({
        'views': 120,
        'likes': 10,
        'reposts': 2,
        'quotes': 1,
        'replies': 3,
        'bookmarks': 4,
        'detail_expands': 5,
        'profile_visits': 6,
        'shares': 1,
        'link_clicks': 0,
        'daily': [
          {'day': '2026-10-20', 'likes': 1, 'reposts': 0, 'replies': 2},
          {'day': '2026-10-21', 'likes': 0, 'reposts': 0, 'replies': 0},
        ],
      });
      expect(a.views, 120);
      expect(a.engagements, 10 + 2 + 1 + 3 + 4 + 1 + 5);
      expect(a.daily, hasLength(2));
      expect(a.daily.first.total, 3);
    });

    test('an empty result does not crash', () {
      final a = PostAnalytics.fromMap(const {});
      expect(a.views, 0);
      expect(a.daily, isEmpty);
    });
  });

  group('Message', () {
    test('keeps the id of the message it answers', () {
      final m = Message.fromMap({
        'id': 'm2',
        'sender_id': 'a',
        'receiver_id': 'b',
        'content': 'hi',
        'created_at': '2026-10-20T10:00:00Z',
        'reply_to': 'm1',
      });
      expect(m.replyTo, 'm1');
    });
  });

  group('SavedAccount', () {
    test('round-trips through json and knows if it can switch', () {
      const a = SavedAccount(
        email: 'a@example.com',
        name: 'Ann',
        username: 'ann',
        userId: 'u1',
        refreshToken: 'tok',
      );
      final b = SavedAccount.fromJson(a.toJson());
      expect(b.email, 'a@example.com');
      expect(b.userId, 'u1');
      expect(b.canSwitch, isTrue);
      expect(a.copyWith(clearToken: true).canSwitch, isFalse);
    });

    test('an old entry without a token still loads', () {
      final a = SavedAccount.fromJson({
        'email': 'a@example.com',
        'name': 'Ann',
        'username': 'ann',
      });
      expect(a.canSwitch, isFalse);
      expect(a.userId, isNull);
    });
  });

  group('Profile follow button', () {
    const open = Profile(id: 'a', username: 'open', followerCount: 5);
    const locked = Profile(
      id: 'b',
      username: 'locked',
      followerCount: 5,
      protectedPosts: true,
    );

    test('a public account is followed right away', () {
      final p = open.afterFollowTap();
      expect(p.followedByMe, isTrue);
      expect(p.requestedByMe, isFalse);
      expect(p.followerCount, 6);
      expect(p.followLabel, 'Following');
      // Tapping again unfollows.
      expect(p.afterFollowTap().followLabel, 'Follow');
      expect(p.afterFollowTap().followerCount, 5);
    });

    test('a protected account turns Follow into Pending', () {
      final p = locked.afterFollowTap();
      expect(p.followedByMe, isFalse);
      expect(p.requestedByMe, isTrue);
      expect(p.followerCount, 5); // not a follower until accepted
      expect(p.followLabel, 'Pending');
      expect(p.followIsOutline, isTrue);
      // Tapping Pending takes the request back.
      final back = p.afterFollowTap();
      expect(back.requestedByMe, isFalse);
      expect(back.followLabel, 'Follow');
    });

    test('profile_stats row with the request flag', () {
      final p = Profile.fromMap({
        'id': 'c',
        'username': 'c',
        'protected': true,
        'requested_by_me': true,
      });
      expect(p.protectedPosts, isTrue);
      expect(p.requestedByMe, isTrue);
      expect(p.followLabel, 'Pending');
    });
  });

  group('X icons', () {
    final all = <List<XShape>>[
      XIcons.homeFill,
    XIcons.home,
    XIcons.search,
    XIcons.searchBold,
    XIcons.grok,
    XIcons.grokBold,
    XIcons.bell,
    XIcons.bellFill,
    XIcons.chat,
    XIcons.chatFill,
    XIcons.reply,
    XIcons.repost,
    XIcons.like,
    XIcons.likeFill,
    XIcons.views,
    XIcons.bookmark,
    XIcons.bookmarkFill,
    XIcons.share,
    XIcons.compose,
    XIcons.xLogo,
    ];

    testWidgets('every icon path parses and paints', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final icon in all)
                XIcon(icon, size: 24, color: const Color(0xFF000000)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(XIcon), findsNWidgets(all.length));
    });
  });

  group('Video posts', () {
    test('Post reads video_url (and photos stay separate)', () {
      final p = Post.fromMap({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'clip',
        'created_at': '2026-10-29T10:00:00Z',
        'username': 'jai',
        'video_url': 'https://example.com/a.mp4',
      });
      expect(p.hasVideo, isTrue);
      expect(p.images, isEmpty);
      expect(p.copyWith(likeCount: 3).videoUrl, 'https://example.com/a.mp4');
    });

    test('a post without video has none', () {
      final p = Post.fromMap({
        'id': 'p2',
        'user_id': 'u1',
        'content': 'text',
        'created_at': '2026-10-29T10:00:00Z',
        'username': 'jai',
      });
      expect(p.hasVideo, isFalse);
    });

    test('content types of picked videos', () {
      PickedVideo v(String ext) => PickedVideo(
            path: '/x.$ext',
            extension: ext,
            bytes: 1,
            duration: const Duration(seconds: 5),
          );
      expect(v('mp4').contentType, 'video/mp4');
      expect(v('mov').contentType, 'video/quicktime');
      expect(v('3gp').contentType, 'video/3gpp');
    });

    test('videoClock prints m:ss and h:mm:ss', () {
      expect(videoClock(const Duration(seconds: 103)), '1:43');
      expect(videoClock(const Duration(seconds: 9)), '0:09');
      expect(videoClock(const Duration(seconds: 3723)), '1:02:03');
    });
  });

  group('Skeletons', () {
    testWidgets('post and row skeletons build and animate', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: Size(400, 800)),
            child: Column(
              children: [
                Expanded(child: PostSkeletonList(count: 6)),
                Expanded(child: RowSkeletonList(count: 4)),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull);
      expect(find.byType(PostSkeletons), findsOneWidget);
    });
  });

  group('Notes', () {
    test('reads a status_notes_feed row', () {
      final n = StatusNote.fromMap({
        'user_id': 'u1',
        'content': 'Studying for finals',
        'created_at': '2026-10-30T08:00:00Z',
        'expires_at': '2099-01-01T00:00:00Z',
        'username': 'jai',
        'display_name': 'Jai',
        'avatar_url': null,
        'verified': null,
      });
      expect(n.userId, 'u1');
      expect(n.content, 'Studying for finals');
      expect(n.name, 'Jai');
      expect(n.isExpired, isFalse);
    });

    test('falls back to the username and detects expiry', () {
      final n = StatusNote(
        userId: 'u2',
        content: 'old',
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        username: 'maria',
      );
      expect(n.name, 'maria');
      expect(n.isExpired, isTrue);
      expect(n.timeLeft, 'expired');
    });

    test('time left is shown in hours, then minutes', () {
      StatusNote at(Duration d) => StatusNote(
            userId: 'u',
            content: 'x',
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(d),
          );
      expect(at(const Duration(hours: 5, minutes: 30)).timeLeft, '5h left');
      expect(at(const Duration(minutes: 35, seconds: 30)).timeLeft, '35m left');
    });

    test('a note holds at most 60 characters', () {
      expect(StatusNote.maxLength, 60);
    });
  });

  group('Communities', () {
    test('reads a community_stats row with role and policy', () {
      final c = Community.fromMap({
        'id': 'c1',
        'owner_id': 'u1',
        'name': 'Hoops Philippines',
        'description': 'Basketball',
        'category': 'Sports',
        'image_url': 'https://x/icon.jpg',
        'cover_url': 'https://x/cover.jpg',
        'member_count': 81,
        'joined_by_me': true,
        'join_policy': 'request',
        'my_role': 'moderator',
        'rule_count': 3,
        'pending_requests': 4,
        'owner_username': 'marco',
        'owner_display_name': 'Marco',
      });
      expect(c.isRestricted, isTrue);
      expect(c.isMod, isTrue);
      expect(c.isAdmin, isFalse);
      expect(c.banner, 'https://x/cover.jpg');
      expect(c.owner, 'Marco');
      expect(c.pendingRequests, 4);
    });

    test('defaults to an open community and falls back to the icon', () {
      final c = Community.fromMap({
        'id': 'c2',
        'owner_id': 'u1',
        'name': 'Memes',
        'image_url': 'https://x/icon.jpg',
      });
      expect(c.joinPolicy, 'open');
      expect(c.isRestricted, isFalse);
      expect(c.isMod, isFalse);
      expect(c.banner, 'https://x/icon.jpg');
    });

    test('copyWith can clear the role after leaving', () {
      final c = Community.fromMap({
        'id': 'c3',
        'owner_id': 'u1',
        'name': 'N',
        'my_role': 'member',
        'joined_by_me': true,
        'member_count': 5,
      });
      final left =
          c.copyWith(joinedByMe: false, memberCount: 4, clearRole: true);
      expect(left.myRole, isNull);
      expect(left.joinedByMe, isFalse);
      expect(left.memberCount, 4);
    });

    test('rule and member rows', () {
      final r = CommunityRule.fromMap({'title': 'Be kind', 'description': 'd'});
      expect(r.toMap(), {'title': 'Be kind', 'description': 'd'});
      final m = CommunityMember.fromMap({
        'user_id': 'u9',
        'username': 'ana',
        'display_name': 'Ana',
        'role': 'admin',
        'joined_at': '2026-10-01T00:00:00Z',
      });
      expect(m.isAdmin, isTrue);
      expect(m.isModerator, isFalse);
      expect(m.profile.username, 'ana');
      expect(m.joinedAt, isNotNull);
    });
  });

  group('Lists', () {
    test('reads a list_stats row', () {
      final l = UserList.fromMap({
        'id': 'l1',
        'owner_id': 'u1',
        'owner_username': 'courtsidenow',
        'name': 'Hoops Daily',
        'is_private': false,
        'member_count': 6,
        'follower_count': 75,
        'followed_by_me': true,
        'pinned_by_me': true,
      });
      expect(l.memberCount, 6);
      expect(l.followerCount, 75);
      expect(l.followedByMe, isTrue);
      expect(l.pinnedByMe, isTrue);
      expect(l.isPrivate, isFalse);
    });

    test('copyWith changes only what is given', () {
      final l = UserList.fromMap({
        'id': 'l2',
        'owner_id': 'u1',
        'owner_username': 'a',
        'name': 'Study Notes',
        'is_private': true,
      });
      final f = l.copyWith(followerCount: 3, pinnedByMe: true);
      expect(f.followerCount, 3);
      expect(f.pinnedByMe, isTrue);
      expect(f.name, 'Study Notes');
      expect(f.isPrivate, isTrue);
    });
  });
}
