DateTime _date(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// A user profile, optionally with follower statistics (from `profile_stats`).
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName = '',
    this.bio = '',
    this.avatarUrl,
    this.followerCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.followedByMe = false,
    this.requestedByMe = false,
    this.createdAt,
    this.interests = const [],
    this.onboarded = true,
    this.headerUrl,
    this.country,
    this.profileLabel,
    this.automated = false,
    this.protectedPosts = false,
    this.managedByUsername,
    this.verified,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool followedByMe;

  /// I asked to follow this protected account and it has not answered yet.
  final bool requestedByMe;

  /// When the account was created (from `profile_stats`).
  final DateTime? createdAt;

  /// Topic ids picked during sign-up (see `core/topics.dart`).
  final List<String> interests;

  /// False while the user is still in the sign-up steps.
  final bool onboarded;

  /// Banner image on the profile page.
  final String? headerUrl;

  /// Country picked in Settings > Your account.
  final String? country;

  /// commentary | fan | parody (null = no label).
  final String? profileLabel;

  /// True for an automated (bot) account.
  final bool automated;

  /// "Protect your posts" is on.
  final bool protectedPosts;

  /// Username of the account that manages this automated account.
  final String? managedByUsername;

  /// Verification badge: blue | gold | gray (null = none). Gold accounts are
  /// organisations and get a square avatar.
  final String? verified;

  /// "Parody account", "Fan account" ... (null without a label).
  String? get labelText => labelTitle(profileLabel);

  static String? labelTitle(String? label) {
    switch (label) {
      case 'commentary':
        return 'Commentary account';
      case 'fan':
        return 'Fan account';
      case 'parody':
        return 'Parody account';
    }
    return null;
  }

  /// Counts as "set up" once there is a profile picture and a bio.
  bool get isSetUp => (avatarUrl ?? '').isNotEmpty && bio.trim().isNotEmpty;

  /// Name to show in the UI (falls back to the username).
  String get name => displayName.trim().isEmpty ? username : displayName;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        username: (m['username'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
        bio: (m['bio'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        followerCount: _int(m['follower_count']),
        followingCount: _int(m['following_count']),
        postCount: _int(m['post_count']),
        followedByMe: (m['followed_by_me'] as bool?) ?? false,
        requestedByMe: (m['requested_by_me'] as bool?) ?? false,
        createdAt: m['created_at'] == null ? null : _date(m['created_at']),
        interests: ((m['interests'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        onboarded: (m['onboarded'] as bool?) ?? true,
        headerUrl: m['header_url'] as String?,
        country: m['country'] as String?,
        profileLabel: m['profile_label'] as String?,
        automated: (m['automated'] as bool?) ?? false,
        protectedPosts: (m['protected'] as bool?) ?? false,
        managedByUsername: m['managed_by_username'] as String?,
        verified: m['verified'] as String?,
      );

  Profile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    int? followerCount,
    bool? followedByMe,
    bool? requestedByMe,
    bool? protectedPosts,
    List<String>? interests,
    String? headerUrl,
  }) =>
      Profile(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        postCount: postCount,
        followedByMe: followedByMe ?? this.followedByMe,
        requestedByMe: requestedByMe ?? this.requestedByMe,
        createdAt: createdAt,
        interests: interests ?? this.interests,
        onboarded: onboarded,
        headerUrl: headerUrl ?? this.headerUrl,
        country: country,
        profileLabel: profileLabel,
        automated: automated,
        protectedPosts: protectedPosts ?? this.protectedPosts,
        managedByUsername: managedByUsername,
        verified: verified,
      );

  /// Text of the follow button: Follow / Pending / Following.
  String get followLabel =>
      followedByMe ? 'Following' : (requestedByMe ? 'Pending' : 'Follow');

  /// "Following" and "Pending" are outlined, "Follow" is the solid button.
  bool get followIsOutline => followedByMe || requestedByMe;

  /// The follow button was tapped: what the profile looks like right away.
  /// A protected account turns "Follow" into "Pending" (a request); tapping
  /// "Following" or "Pending" takes the follow / the request back.
  Profile afterFollowTap() {
    final wasOn = followedByMe || requestedByMe;
    final nowFollowing = !wasOn && !protectedPosts;
    final nowRequested = !wasOn && protectedPosts;
    return copyWith(
      followedByMe: nowFollowing,
      requestedByMe: nowRequested,
      followerCount:
          followerCount + (nowFollowing ? 1 : 0) - (followedByMe ? 1 : 0),
    );
  }
}

/// One row of a Followers / Following list.
class FollowEntry {
  const FollowEntry({required this.profile, this.followsMe = false});

  final Profile profile;

  /// This person follows me ("Follows you" tag).
  final bool followsMe;

  FollowEntry copyWith({Profile? profile}) =>
      FollowEntry(profile: profile ?? this.profile, followsMe: followsMe);
}

/// The post a quote post points at (shown as a small card inside it).
class QuotedPost {
  const QuotedPost({
    required this.id,
    required this.content,
    required this.username,
    this.displayName = '',
    this.avatarUrl,
    this.imageUrl,
    this.verified,
    this.createdAt,
  });

  final String id;
  final String content;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? imageUrl;
  final String? verified;
  final DateTime? createdAt;

  String get authorName => displayName.trim().isEmpty ? username : displayName;

  /// Null when the post carries no quote.
  static QuotedPost? fromMap(Map<String, dynamic> m) {
    final id = m['quote_id'] as String?;
    if (id == null || m['quote_username'] == null) return null;
    return QuotedPost(
      id: id,
      content: (m['quote_content'] as String?) ?? '',
      username: (m['quote_username'] as String?) ?? '',
      displayName: (m['quote_display_name'] as String?) ?? '',
      avatarUrl: m['quote_avatar_url'] as String?,
      imageUrl: m['quote_image_url'] as String?,
      verified: m['quote_verified'] as String?,
      createdAt: DateTime.tryParse((m['quote_created_at'] ?? '').toString())
          ?.toLocal(),
    );
  }
}

/// One answer of a poll with its votes.
class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    required this.votes,
    required this.votedByMe,
  });

  final String id;
  final String label;
  final int votes;
  final bool votedByMe;

  factory PollOption.fromMap(Map<String, dynamic> m) => PollOption(
        id: m['option_id'] as String,
        label: (m['label'] as String?) ?? '',
        votes: _int(m['votes']),
        votedByMe: (m['voted_by_me'] as bool?) ?? false,
      );
}

/// A feed post (row of the `posts_feed` view).
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.username,
    this.imageUrl,
    this.displayName = '',
    this.avatarUrl,
    this.likeCount = 0,
    this.likedByMe = false,
    this.bookmarkedByMe = false,
    this.parentId,
    this.replyCount = 0,
    this.repostCount = 0,
    this.repostedByMe = false,
    this.views = 0,
    this.communityId,
    this.communityName,
    this.replySetting = 'everyone',
    this.location,
    this.paidPartnership = false,
    this.madeWithAi = false,
    this.scheduledAt,
    this.pollEndsAt,
    this.quote,
    this.authorLabel,
    this.authorAutomated = false,
    this.authorProtected = false,
    this.imageUrls = const [],
    this.videoUrl,
    this.authorVerified,
    this.bookmarkCount = 0,
    this.editedAt,
    this.noteId,
    this.noteBody,
    this.noteSource,
  });

  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;

  /// Set after the author changed the text of the post.
  final DateTime? editedAt;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int likeCount;
  final bool likedByMe;
  final bool bookmarkedByMe;

  /// Set when this post is a reply to another post.
  final String? parentId;
  final int replyCount;
  final int repostCount;
  final bool repostedByMe;
  final int views;

  /// Set when the post was written inside a community.
  final String? communityId;
  final String? communityName;

  /// everyone | following | verified | mentioned
  final String replySetting;

  /// Place name added with the location button.
  final String? location;

  /// Content disclosures chosen in the composer's flag dialog.
  final bool paidPartnership;
  final bool madeWithAi;

  /// Set while the post waits for its publishing time (only I can see it).
  final DateTime? scheduledAt;

  /// Set when the post carries a poll; the poll closes at this time.
  final DateTime? pollEndsAt;

  /// The post this one quotes.
  final QuotedPost? quote;

  /// Profile label of the author (commentary | fan | parody).
  final String? authorLabel;
  final bool authorAutomated;
  final bool authorProtected;

  /// All pictures of the post (up to four). [imageUrl] is the first one.
  final List<String> imageUrls;

  /// The video of the post (a post has up to 4 photos / GIFs *or* 1 video).
  final String? videoUrl;

  bool get hasVideo => (videoUrl ?? '').isNotEmpty;

  /// Badge of the author: blue | gold | gray (null = none).
  final String? authorVerified;
  final int bookmarkCount;

  /// The Community Note shown under the post (null = none yet).
  final String? noteId;
  final String? noteBody;
  final String? noteSource;

  /// The pictures to show: [imageUrls], or just [imageUrl] on older posts.
  List<String> get images => imageUrls.isNotEmpty
      ? imageUrls
      : ((imageUrl ?? '').isEmpty ? const [] : [imageUrl!]);

  /// Small grey line under the name: "Automated · Parody account".
  String? get authorBadge {
    final parts = <String>[
      if (authorAutomated) 'Automated',
      if (Profile.labelTitle(authorLabel) != null)
        Profile.labelTitle(authorLabel)!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  bool get hasPoll => pollEndsAt != null;

  String get authorName => displayName.trim().isEmpty ? username : displayName;

  factory Post.fromMap(Map<String, dynamic> m) => Post(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        content: (m['content'] as String?) ?? '',
        imageUrl: m['image_url'] as String?,
        createdAt: _date(m['created_at']),
        username: (m['username'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        likeCount: _int(m['like_count']),
        likedByMe: (m['liked_by_me'] as bool?) ?? false,
        bookmarkedByMe: (m['bookmarked_by_me'] as bool?) ?? false,
        parentId: m['parent_id'] as String?,
        replyCount: _int(m['reply_count']),
        repostCount: _int(m['repost_count']),
        repostedByMe: (m['reposted_by_me'] as bool?) ?? false,
        views: _int(m['views']),
        communityId: m['community_id'] as String?,
        communityName: m['community_name'] as String?,
        replySetting: (m['reply_setting'] as String?) ?? 'everyone',
        location: m['location'] as String?,
        paidPartnership: (m['paid_partnership'] as bool?) ?? false,
        madeWithAi: (m['made_with_ai'] as bool?) ?? false,
        scheduledAt:
            m['scheduled_at'] == null ? null : _date(m['scheduled_at']),
        pollEndsAt:
            m['poll_ends_at'] == null ? null : _date(m['poll_ends_at']),
        quote: QuotedPost.fromMap(m),
        authorLabel: m['author_label'] as String?,
        authorAutomated: (m['author_automated'] as bool?) ?? false,
        authorProtected: (m['author_protected'] as bool?) ?? false,
        imageUrls: ((m['image_urls'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        videoUrl: m['video_url'] as String?,
        authorVerified: m['author_verified'] as String?,
        bookmarkCount: _int(m['bookmark_count']),
        editedAt:
            m['edited_at'] == null ? null : _date(m['edited_at']),
        noteId: m['note_id'] as String?,
        noteBody: m['note_body'] as String?,
        noteSource: m['note_source'] as String?,
      );

  Post copyWith({
    int? likeCount,
    bool? likedByMe,
    bool? bookmarkedByMe,
    int? replyCount,
    int? repostCount,
    bool? repostedByMe,
    int? bookmarkCount,
    String? content,
    DateTime? editedAt,
  }) =>
      Post(
        id: id,
        userId: userId,
        content: content ?? this.content,
        editedAt: editedAt ?? this.editedAt,
        imageUrl: imageUrl,
        createdAt: createdAt,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
        parentId: parentId,
        replyCount: replyCount ?? this.replyCount,
        repostCount: repostCount ?? this.repostCount,
        repostedByMe: repostedByMe ?? this.repostedByMe,
        views: views,
        communityId: communityId,
        communityName: communityName,
        replySetting: replySetting,
        location: location,
        paidPartnership: paidPartnership,
        madeWithAi: madeWithAi,
        scheduledAt: scheduledAt,
        pollEndsAt: pollEndsAt,
        quote: quote,
        authorLabel: authorLabel,
        authorAutomated: authorAutomated,
        authorProtected: authorProtected,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        authorVerified: authorVerified,
        bookmarkCount: bookmarkCount ?? this.bookmarkCount,
        noteId: noteId,
        noteBody: noteBody,
        noteSource: noteSource,
      );
}

/// A trending hashtag with the number of recent posts that use it.
class TrendingTag {
  const TrendingTag(this.tag, this.count);

  /// Including the leading "#".
  final String tag;
  final int count;
}

/// A "Who to follow" entry; [context] is e.g. "Sam follows" when someone I
/// follow also follows this person.
class Suggestion {
  const Suggestion(this.profile, {this.context});

  final Profile profile;
  final String? context;

  Suggestion copyWith({Profile? profile}) =>
      Suggestion(profile ?? this.profile, context: context);
}

/// A direct message.
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.replyTo,
    this.mediaPath,
    this.mediaKind,
    this.mediaMs,
  });

  /// Message this one answers (null = a normal message).
  final String? replyTo;

  /// Photo / video / voice message: the file in the private `chat-media`
  /// bucket, its kind (`image`, `video`, `voice`) and length in ms.
  final String? mediaPath;
  final String? mediaKind;
  final int? mediaMs;
  bool get hasMedia => mediaPath != null && mediaKind != null;

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'] as String,
        senderId: m['sender_id'] as String,
        receiverId: m['receiver_id'] as String,
        content: (m['content'] as String?) ?? '',
        createdAt: _date(m['created_at']),
        readAt: m['read_at'] == null ? null : _date(m['read_at']),
        replyTo: m['reply_to'] as String?,
        mediaPath: m['media_path'] as String?,
        mediaKind: m['media_kind'] as String?,
        mediaMs: (m['media_ms'] as num?)?.toInt(),
      );
}

/// One row of the inbox (result of the `my_conversations()` function).
class Conversation {
  const Conversation({
    required this.partnerId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastAt,
    required this.lastFromMe,
    required this.unreadCount,
  });

  final String partnerId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastAt;
  final bool lastFromMe;
  final int unreadCount;

  String get name => displayName.trim().isEmpty ? username : displayName;

  Profile get partner => Profile(
        id: partnerId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
        partnerId: m['partner_id'] as String,
        username: (m['username'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        lastMessage: (m['last_message'] as String?) ?? '',
        lastAt: _date(m['last_at']),
        lastFromMe: (m['last_from_me'] as bool?) ?? false,
        unreadCount: _int(m['unread_count']),
      );
}

/// A message to the team: Contact us, Report a problem or a verification
/// request. The team answers in the dashboard (`status`, `reply`).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.kind,
    required this.subject,
    required this.message,
    required this.status,
    required this.reply,
    required this.createdAt,
  });

  final String id;

  /// contact | problem | verification
  final String kind;
  final String subject;
  final String message;

  /// open | in_review | resolved | rejected
  final String status;
  final String? reply;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'in_review' => 'In review',
        'resolved' => 'Resolved',
        'rejected' => 'Not approved',
        _ => 'Sent',
      };

  bool get isWaiting => status == 'open' || status == 'in_review';

  factory SupportTicket.fromMap(Map<String, dynamic> m) => SupportTicket(
        id: m['id'] as String,
        kind: (m['kind'] as String?) ?? 'contact',
        subject: (m['subject'] as String?) ?? '',
        message: (m['message'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'open',
        reply: m['reply'] as String?,
        createdAt: _date(m['created_at']),
      );
}

/// My list options for one chat (pin, mute, archive, mark as unread).
class ChatPref {
  const ChatPref({
    this.pinned = false,
    this.muted = false,
    this.archived = false,
    this.markedUnread = false,
    this.clearedAt,
  });

  final bool pinned;
  final bool muted;
  final bool archived;
  final bool markedUnread;

  /// Messages up to this moment were "deleted" by me.
  final DateTime? clearedAt;

  ChatPref copyWith({
    bool? pinned,
    bool? muted,
    bool? archived,
    bool? markedUnread,
    DateTime? clearedAt,
  }) =>
      ChatPref(
        pinned: pinned ?? this.pinned,
        muted: muted ?? this.muted,
        archived: archived ?? this.archived,
        markedUnread: markedUnread ?? this.markedUnread,
        clearedAt: clearedAt ?? this.clearedAt,
      );

  factory ChatPref.fromMap(Map<String, dynamic> m) => ChatPref(
        pinned: (m['pinned'] as bool?) ?? false,
        muted: (m['muted'] as bool?) ?? false,
        archived: (m['archived'] as bool?) ?? false,
        markedUnread: (m['marked_unread'] as bool?) ?? false,
        clearedAt: m['cleared_at'] == null ? null : _date(m['cleared_at']),
      );
}

/// One row of the inbox for a group chat (`my_groups()`).
class GroupChat {
  const GroupChat({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.lastMessage,
    required this.lastAt,
    required this.lastFromMe,
    required this.lastSenderName,
    required this.unreadCount,
  });

  final String id;
  final String name;
  final int memberCount;

  /// Empty while nobody wrote yet.
  final String lastMessage;
  final DateTime lastAt;
  final bool lastFromMe;
  final String? lastSenderName;
  final int unreadCount;

  factory GroupChat.fromMap(Map<String, dynamic> m) => GroupChat(
        id: m['group_id'] as String,
        name: (m['name'] as String?) ?? 'Group',
        memberCount: _int(m['member_count']),
        lastMessage: (m['last_message'] as String?) ?? '',
        lastAt: _date(m['last_at']),
        lastFromMe: (m['last_from_me'] as bool?) ?? false,
        lastSenderName: m['last_sender_name'] as String?,
        unreadCount: _int(m['unread_count']),
      );
}

/// One message in a group chat.
class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.mediaPath,
    this.mediaKind,
    this.mediaMs,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? mediaPath;
  final String? mediaKind;
  final int? mediaMs;
  bool get hasMedia => mediaPath != null && mediaKind != null;

  factory GroupMessage.fromMap(Map<String, dynamic> m) => GroupMessage(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        senderId: m['sender_id'] as String,
        content: (m['content'] as String?) ?? '',
        createdAt: _date(m['created_at']),
        mediaPath: m['media_path'] as String?,
        mediaKind: m['media_kind'] as String?,
        mediaMs: (m['media_ms'] as num?)?.toInt(),
      );
}

/// A person in a group chat (`group_member_list()`).
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isAdmin,
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isAdmin;

  String get name => displayName.trim().isEmpty ? username : displayName;

  Profile get profile => Profile(
        id: userId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );

  factory GroupMember.fromMap(Map<String, dynamic> m) => GroupMember(
        userId: m['user_id'] as String,
        username: (m['username'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        isAdmin: m['role'] == 'admin',
      );
}

/// Kinds of entries on the Notifications tab.
enum NotificationKind { like, follow, mention }

/// A Note: one short status (up to [maxLength] characters) per account that
/// disappears after 24 hours. Shown at the top of the Chat tab.
class StatusNote {
  const StatusNote({
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.expiresAt,
    this.username = '',
    this.displayName = '',
    this.avatarUrl,
    this.verified,
  });

  static const int maxLength = 60;

  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? verified;

  String get name => displayName.trim().isEmpty ? username : displayName;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());

  /// "21h left" / "35m left" for the sheets.
  String get timeLeft {
    final left = expiresAt.difference(DateTime.now());
    if (left.inMinutes <= 0) return 'expired';
    if (left.inHours >= 1) return '${left.inHours}h left';
    return '${left.inMinutes}m left';
  }

  factory StatusNote.fromMap(Map<String, dynamic> m) => StatusNote(
        userId: m['user_id'] as String,
        content: (m['content'] as String?) ?? '',
        createdAt: _date(m['created_at']),
        expiresAt: _date(m['expires_at']),
        username: (m['username'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        verified: m['verified'] as String?,
      );
}

/// One entry on the Notifications tab, built from likes, follows and posts
/// that mention me.
class AppNotification {
  const AppNotification({
    required this.kind,
    required this.actor,
    required this.createdAt,
    this.postText = '',
    this.postImageUrl,
  });

  final NotificationKind kind;

  /// The person who liked / followed / mentioned me.
  final Profile actor;
  final DateTime createdAt;

  /// My liked post, or the post that mentions me.
  final String postText;
  final String? postImageUrl;
}

/// A community (row of the `community_stats` view).
class Community {
  const Community({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.category = 'General',
    this.imageUrl,
    this.coverUrl,
    this.memberCount = 0,
    this.joinedByMe = false,
    this.joinPolicy = 'open',
    this.myRole,
    this.requestedByMe = false,
    this.ruleCount = 0,
    this.pendingRequests = 0,
    this.ownerUsername = '',
    this.ownerName = '',
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String category;
  final String? imageUrl;

  /// Wide picture on top of the community page.
  final String? coverUrl;
  final int memberCount;
  final bool joinedByMe;

  /// `open` (tap Join) or `request` (ask to join, moderators answer).
  final String joinPolicy;

  /// admin | moderator | member, or null when I am not in it.
  final String? myRole;
  final bool requestedByMe;
  final int ruleCount;

  /// Join requests waiting for an answer (only counted for moderators).
  final int pendingRequests;
  final String ownerUsername;
  final String ownerName;
  final DateTime? createdAt;

  bool get isRestricted => joinPolicy == 'request';
  bool get isAdmin => myRole == 'admin';
  bool get isMod => myRole == 'admin' || myRole == 'moderator';
  String get owner => ownerName.trim().isEmpty ? ownerUsername : ownerName;

  /// The picture of the cover, or the square icon when there is no cover.
  String? get banner => (coverUrl ?? '').isNotEmpty ? coverUrl : imageUrl;

  factory Community.fromMap(Map<String, dynamic> m) => Community(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'General',
        imageUrl: m['image_url'] as String?,
        coverUrl: m['cover_url'] as String?,
        memberCount: _int(m['member_count']),
        joinedByMe: (m['joined_by_me'] as bool?) ?? false,
        joinPolicy: (m['join_policy'] as String?) ?? 'open',
        myRole: m['my_role'] as String?,
        requestedByMe: (m['requested_by_me'] as bool?) ?? false,
        ruleCount: _int(m['rule_count']),
        pendingRequests: _int(m['pending_requests']),
        ownerUsername: (m['owner_username'] as String?) ?? '',
        ownerName: (m['owner_display_name'] as String?) ?? '',
        createdAt: m['created_at'] == null ? null : _date(m['created_at']),
      );

  Community copyWith({
    int? memberCount,
    bool? joinedByMe,
    bool? requestedByMe,
    String? myRole,
    bool clearRole = false,
    int? pendingRequests,
  }) =>
      Community(
        id: id,
        ownerId: ownerId,
        name: name,
        description: description,
        category: category,
        imageUrl: imageUrl,
        coverUrl: coverUrl,
        memberCount: memberCount ?? this.memberCount,
        joinedByMe: joinedByMe ?? this.joinedByMe,
        joinPolicy: joinPolicy,
        myRole: clearRole ? null : (myRole ?? this.myRole),
        requestedByMe: requestedByMe ?? this.requestedByMe,
        ruleCount: ruleCount,
        pendingRequests: pendingRequests ?? this.pendingRequests,
        ownerUsername: ownerUsername,
        ownerName: ownerName,
        createdAt: createdAt,
      );
}

/// One rule of a community (up to 10 per community, at least 1).
class CommunityRule {
  const CommunityRule({required this.title, this.description = ''});

  final String title;
  final String description;

  factory CommunityRule.fromMap(Map<String, dynamic> m) => CommunityRule(
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {'title': title, 'description': description};
}

/// A member of a community (or somebody who asked to join) with the role.
class CommunityMember {
  const CommunityMember({
    required this.profile,
    this.role = 'member',
    this.joinedAt,
  });

  final Profile profile;

  /// admin | moderator | member
  final String role;
  final DateTime? joinedAt;

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';

  factory CommunityMember.fromMap(Map<String, dynamic> m) => CommunityMember(
        profile: Profile(
          id: m['user_id'] as String,
          username: (m['username'] as String?) ?? '',
          displayName: (m['display_name'] as String?) ?? '',
          avatarUrl: m['avatar_url'] as String?,
          bio: (m['bio'] as String?) ?? '',
          verified: m['verified'] as String?,
        ),
        role: (m['role'] as String?) ?? 'member',
        joinedAt: m['joined_at'] == null
            ? (m['created_at'] == null ? null : _date(m['created_at']))
            : _date(m['joined_at']),
      );
}

/// A curated list of accounts (row of the `list_stats` view).
class UserList {
  const UserList({
    required this.id,
    required this.ownerId,
    required this.ownerUsername,
    required this.name,
    this.ownerName = '',
    this.ownerAvatarUrl,
    this.ownerVerified,
    this.description = '',
    this.isPrivate = false,
    this.bannerUrl,
    this.memberCount = 0,
    this.followerCount = 0,
    this.followedByMe = false,
    this.pinnedByMe = false,
  });

  final String id;
  final String ownerId;
  final String ownerUsername;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String? ownerVerified;
  final String name;
  final String description;
  final bool isPrivate;
  final String? bannerUrl;
  final int memberCount;
  final int followerCount;
  final bool followedByMe;

  /// Pinned to the top of my Lists page (up to 10).
  final bool pinnedByMe;

  String get owner => ownerName.trim().isEmpty ? ownerUsername : ownerName;

  factory UserList.fromMap(Map<String, dynamic> m) => UserList(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        ownerUsername: (m['owner_username'] as String?) ?? '',
        ownerName: (m['owner_display_name'] as String?) ?? '',
        ownerAvatarUrl: m['owner_avatar_url'] as String?,
        ownerVerified: m['owner_verified'] as String?,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        isPrivate: (m['is_private'] as bool?) ?? false,
        bannerUrl: m['banner_url'] as String?,
        memberCount: _int(m['member_count']),
        followerCount: _int(m['follower_count']),
        followedByMe: (m['followed_by_me'] as bool?) ?? false,
        pinnedByMe: (m['pinned_by_me'] as bool?) ?? false,
      );

  UserList copyWith({
    int? memberCount,
    int? followerCount,
    bool? followedByMe,
    bool? pinnedByMe,
    String? name,
    String? description,
    bool? isPrivate,
    String? bannerUrl,
  }) =>
      UserList(
        id: id,
        ownerId: ownerId,
        ownerUsername: ownerUsername,
        ownerName: ownerName,
        ownerAvatarUrl: ownerAvatarUrl,
        ownerVerified: ownerVerified,
        name: name ?? this.name,
        description: description ?? this.description,
        isPrivate: isPrivate ?? this.isPrivate,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        memberCount: memberCount ?? this.memberCount,
        followerCount: followerCount ?? this.followerCount,
        followedByMe: followedByMe ?? this.followedByMe,
        pinnedByMe: pinnedByMe ?? this.pinnedByMe,
      );
}


/// A Community Note written for a post, with the ratings it got.
class CommunityNote {
  const CommunityNote({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.body,
    required this.createdAt,
    this.sourceUrl,
    this.helpfulCount = 0,
    this.notHelpfulCount = 0,
    this.myRating,
    this.shown = false,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorUsername;
  final String body;
  final String? sourceUrl;
  final DateTime createdAt;
  final int helpfulCount;
  final int notHelpfulCount;

  /// true = I rated it helpful, false = not helpful, null = not rated.
  final bool? myRating;

  /// Enough people found it helpful: it is shown under the post.
  final bool shown;

  factory CommunityNote.fromMap(Map<String, dynamic> m) => CommunityNote(
        id: m['id'] as String,
        postId: m['post_id'] as String,
        authorId: m['author_id'] as String,
        authorUsername: (m['author_username'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        sourceUrl: m['source_url'] as String?,
        createdAt: _date(m['created_at']),
        helpfulCount: _int(m['helpful_count']),
        notHelpfulCount: _int(m['not_helpful_count']),
        myRating: m['my_rating'] as bool?,
        shown: (m['shown'] as bool?) ?? false,
      );
}

/// One day of the little chart in "Post analytics".
class AnalyticsDay {
  const AnalyticsDay(this.day, this.likes, this.reposts, this.replies);

  final String day; // YYYY-MM-DD
  final int likes;
  final int reposts;
  final int replies;

  int get total => likes + reposts + replies;
}

/// Numbers for one of my own posts (result of `post_analytics`).
class PostAnalytics {
  const PostAnalytics({
    required this.views,
    required this.likes,
    required this.reposts,
    required this.quotes,
    required this.replies,
    required this.bookmarks,
    required this.detailExpands,
    required this.profileVisits,
    required this.shares,
    required this.linkClicks,
    required this.daily,
  });

  final int views;
  final int likes;
  final int reposts;
  final int quotes;
  final int replies;
  final int bookmarks;
  final int detailExpands;
  final int profileVisits;
  final int shares;
  final int linkClicks;
  final List<AnalyticsDay> daily;

  /// Everything people did with the post.
  int get engagements =>
      likes + reposts + quotes + replies + bookmarks + shares + detailExpands;

  factory PostAnalytics.fromMap(Map<String, dynamic> m) => PostAnalytics(
        views: _int(m['views']),
        likes: _int(m['likes']),
        reposts: _int(m['reposts']),
        quotes: _int(m['quotes']),
        replies: _int(m['replies']),
        bookmarks: _int(m['bookmarks']),
        detailExpands: _int(m['detail_expands']),
        profileVisits: _int(m['profile_visits']),
        shares: _int(m['shares']),
        linkClicks: _int(m['link_clicks']),
        daily: [
          for (final d in (m['daily'] as List? ?? const []))
            AnalyticsDay(
              (d['day'] as String?) ?? '',
              _int(d['likes']),
              _int(d['reposts']),
              _int(d['replies']),
            ),
        ],
      );
}
