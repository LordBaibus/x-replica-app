import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/account_sessions.dart';
import '../services/ai_service.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../services/session_tracker.dart';
import '../services/user_prefs.dart';
import '../services/saved_accounts.dart';
import '../widgets/accounts_sheet.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/side_drawer.dart';
import '../core/x_icons.dart';
import 'bookmarks_screen.dart';
import 'communities_screen.dart';
import 'auth_screen.dart';
import 'compose_post_screen.dart';
import 'chat_tab.dart';
import 'creator_studio_screen.dart';
import 'developer_info_screen.dart';
import 'explore_view.dart';
import 'feed_view.dart';
import 'follow_lists_screen.dart';
import 'follower_requests_screen.dart';
import 'info_screen.dart';
import 'lists_screen.dart';
import 'grok_tab.dart';
import 'notifications_view.dart';
import 'profile_view.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

/// Main screen after login, laid out like X: five tabs (Home, Search, Grok,
/// Notifications, Chat), a round compose button, and the account menu that
/// the whole app slides aside to reveal when you tap your avatar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialSearch});

  /// Text typed on the last sign-up step; opens the search results first.
  final String? initialSearch;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _drawerOpen = false;
  Profile? _me;
  int _requestCount = 0;

  // Notifications that came in after the Notifications tab was last opened.
  int _unviewed = 0;
  DateTime? _newestNotification;
  Timer? _notifTimer;
  static const _seenKey = 'notif_seen_at';

  final _feedKey = GlobalKey<FeedViewState>();
  final _notificationsKey = GlobalKey<NotificationsViewState>();
  final _inboxKey = GlobalKey<ChatTabState>();

  @override
  void initState() {
    super.initState();
    // Per-account settings, blocks/mutes and this phone's session.
    // The badge needs the saved "last seen" time, so check after it loaded.
    UserPrefs.instance.load().whenComplete(_checkNotifications);
    Moderation.instance.reload();
    SessionTracker.start();
    _loadMe();
    _notifTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _checkNotifications(),
    );
    Api.profileVersion.addListener(_loadMe);
    AiAssist.grokReplied.addListener(_grokReplied);
    AiAssist.grokError.addListener(_grokError);
    final q = widget.initialSearch;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(appRoute(SearchScreen(initialQuery: q)));
        }
      });
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    Api.profileVersion.removeListener(_loadMe);
    AiAssist.grokReplied.removeListener(_grokReplied);
    AiAssist.grokError.removeListener(_grokError);
    super.dispose();
  }

  void _grokReplied() {
    if (mounted) showInfo(context, 'Grok replied to your post.');
  }

  void _grokError() {
    final msg = AiAssist.grokError.value;
    if (msg == null || !mounted) return;
    AiAssist.grokError.value = null;
    showInfo(context, 'Grok could not answer: $msg');
  }

  Future<void> _loadMe() async {
    try {
      final me = await Api.getProfile(Api.uid);
      final requests = await Api.followRequestCount();
      if (mounted) {
        setState(() {
          _me = me;
          _requestCount = requests;
        });
      }
      // Remember this account for the "Log in" screen.
      if (Api.email.isNotEmpty) {
        await SavedAccounts.remember(SavedAccount(
          email: Api.email,
          name: me.name,
          username: me.username,
          avatarUrl: me.avatarUrl,
          userId: Api.uid,
          refreshToken: Api.refreshToken,
        ));
      }
    } catch (_) {
      // Only the avatar / drawer header depend on this; keep going.
    }
  }

  // ---- unviewed notifications -------------------------------------------

  DateTime? _seenAt() {
    final raw = UserPrefs.instance.text(_seenKey);
    return raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  /// Remember that everything up to [upTo] was seen (the Notifications tab
  /// is open) and clear the badge.
  void _markNotificationsSeen(DateTime? upTo) {
    if (upTo != null) {
      final seen = _seenAt();
      if (seen == null || upTo.isAfter(seen)) {
        UserPrefs.instance.set(_seenKey, upTo.toUtc().toIso8601String());
      }
    }
    if (_unviewed != 0 && mounted) setState(() => _unviewed = 0);
  }

  /// Gets the latest notifications and counts the ones newer than the last
  /// time the tab was opened. Called now, every 45 s and by the tab itself.
  Future<void> _checkNotifications([List<AppNotification>? known]) async {
    try {
      final list = known ?? await Api.fetchNotifications();
      if (!mounted) return;
      DateTime? newest;
      for (final n in list) {
        if (newest == null || n.createdAt.isAfter(newest)) newest = n.createdAt;
      }
      _newestNotification = newest;
      if (_index == 3) {
        // Looking at them right now.
        _markNotificationsSeen(newest);
        return;
      }
      final seen = _seenAt();
      final count = seen == null
          ? list.length
          : list.where((n) => n.createdAt.isAfter(seen)).length;
      if (count != _unviewed) setState(() => _unviewed = count);
    } catch (_) {
      // Badge only; try again on the next tick.
    }
  }

  // ---- drawer ------------------------------------------------------------

  void _openDrawer() {
    _loadMe();
    setState(() => _drawerOpen = true);
  }

  void _closeDrawer() {
    if (_drawerOpen) setState(() => _drawerOpen = false);
  }

  /// Closes the drawer, then runs [action].
  void _fromDrawer(VoidCallback action) {
    _closeDrawer();
    action();
  }

  void _push(Widget page) => Navigator.of(context).push(appRoute(page));

  void _openMyProfile() {
    Navigator.of(context)
        .push(appRoute(ProfileScreen(userId: Api.uid)))
        .then((_) => _loadMe());
  }

  void _info({
    required String title,
    required String headline,
    required String body,
    List<String> points = const [],
  }) {
    _push(InfoScreen(
      title: title,
      headline: headline,
      body: body,
      points: points,
    ));
  }

  /// The account switcher: switch to another account on this phone, or add
  /// one without logging out of this one.
  Future<void> _switchAccount() async {
    final choice = await showAccountsSheet(context);
    if (choice == null || !mounted) return;
    switch (choice.action) {
      case AccountsAction.switchTo:
        try {
          await AccountSessions.switchTo(choice.account!);
          // AuthGate swaps to the other account's app.
        } catch (e) {
          if (mounted) showError(context, e);
        }
      case AccountsAction.addExisting:
        _push(const AuthScreen(addAccount: true));
      case AccountsAction.createNew:
        _push(const AuthScreen(addAccount: true, startAtCreate: true));
    }
  }

  // ---- actions -----------------------------------------------------------

  Future<void> _compose() async {
    final posted = await Navigator.of(context).push<bool>(
      appRoute(const ComposePostScreen(), fullscreen: true),
    );
    if (posted == true) {
      _feedKey.currentState?.reload();
      _loadMe();
    }
  }

  void _onTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (i == 3) _markNotificationsSeen(_newestNotification);
    // Refresh the tab that just came into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (i == 3) _notificationsKey.currentState?.reload();
      if (i == 4) _inboxKey.currentState?.reload();
    });
  }

  // ---- UI ----------------------------------------------------------------

  /// Round-cornered compose button (pen with a +), above the tab bar.
  Widget? _fab(AppPalette p) {
    // Chat draws its own new-chat button (hidden on the Welcome screens).
    if (_index == 4) return null;
    // Grok has its own message box at the bottom.
    if (_index == 2) return null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _compose,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: XIcon(XIcons.compose, size: 26, color: Color(0xFFFFFFFF)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    // The compose button hides while the keyboard is open.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final fab = keyboardOpen ? null : _fab(p);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;

    final pages = IndexedStack(
      index: _index,
      children: [
        FeedView(
          key: _feedKey,
          me: _me,
          onOpenDrawer: _openDrawer,
          onMeChanged: _loadMe,
        ),
        ExploreView(me: _me, onOpenDrawer: _openDrawer),
        GrokTab(me: _me, onOpenDrawer: _openDrawer),
        NotificationsView(
          key: _notificationsKey,
          me: _me,
          onLoaded: _checkNotifications,
          onOpenDrawer: _openDrawer,
        ),
        ChatTab(
          key: _inboxKey,
          me: _me,
          onOpenDrawer: _openDrawer,
          onOpenSettings: () => _push(const SettingsScreen()),
        ),
      ],
    );

    // Flat tab bar (no iOS 26 liquid glass). Icons are the X vectors: outline
    // when not selected, filled / bolder when selected, black in light mode
    // and white in dark mode. The Notifications tab carries the badge.
    Widget icon(List<XShape> shapes) =>
        XIcon(shapes, size: 26, color: p.text);
    final unviewedText = _unviewed > 99 ? '99+' : null;

    final app = AdaptiveScaffold(
      backgroundColor: p.background,
      floatingActionButton: fab,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: false,
        selectedIndex: _index,
        onTap: _onTab,
        // iOS: the label of the open tab is black / white, not blue.
        selectedItemColor: ios ? p.text : null,
        items: [
          AdaptiveNavigationDestination(
            icon: icon(XIcons.home),
            selectedIcon: icon(XIcons.homeFill),
            label: 'Home',
          ),
          AdaptiveNavigationDestination(
            icon: icon(XIcons.search),
            selectedIcon: icon(XIcons.searchBold),
            label: 'Search',
          ),
          AdaptiveNavigationDestination(
            icon: icon(XIcons.grok),
            selectedIcon: icon(XIcons.grokBold),
            label: 'Grok',
          ),
          AdaptiveNavigationDestination(
            icon: icon(XIcons.bell),
            selectedIcon: icon(XIcons.bellFill),
            label: 'Notifications',
            badgeCount: _unviewed > 0 ? _unviewed : null,
            badgeText: unviewedText,
            badgeColor: p.accent,
            badgeTextColor: const Color(0xFFFFFFFF),
          ),
          AdaptiveNavigationDestination(
            icon: icon(XIcons.chat),
            selectedIcon: icon(XIcons.chatFill),
            label: 'Chat',
          ),
        ],
      ),
      body: pages,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: PushDrawer(
            open: _drawerOpen,
            onClose: _closeDrawer,
            drawer: DrawerMenu(
              me: _me,
              requestCount: _requestCount,
              onProfile: () => _fromDrawer(_openMyProfile),
              onAddAccount: () => _fromDrawer(_switchAccount),
              onSubscription: () => _fromDrawer(() => Navigator.of(context)
                  .push(appRoute(const SubscriptionScreen(), fullscreen: true))),
              onBookmarks: () =>
                  _fromDrawer(() => _push(const BookmarksScreen())),
              onCommunities: () =>
                  _fromDrawer(() => _push(const CommunitiesScreen())),
              onLists: () => _fromDrawer(() => _push(const ListsScreen())),
              onFollowList: (followers) => _fromDrawer(() async {
                final me = _me;
                if (me == null) return;
                await Navigator.of(context).push(appRoute(FollowListsScreen(
                  userId: me.id,
                  title: me.name,
                  initial:
                      followers ? FollowTab.followers : FollowTab.following,
                )));
                if (mounted) _loadMe();
              }),
              onFollowerRequests: () => _fromDrawer(() async {
                await Navigator.of(context)
                    .push(appRoute(const FollowerRequestsScreen()));
                if (mounted) _loadMe();
              }),
              onCreatorStudio: () =>
                  _fromDrawer(() => _push(const CreatorStudioScreen())),
              onDeveloper: () =>
                  _fromDrawer(() => _push(const DeveloperInfoScreen())),
              onSettings: () =>
                  _fromDrawer(() => _push(const SettingsScreen())),
              onHelp: () => _fromDrawer(() => _info(
                    title: 'Help Center',
                    headline: 'How things work',
                    body: 'A quick tour of the app.',
                    points: const [
                      'Post: tap the blue button on Home. Add a photo and up '
                          'to 280 characters.',
                      'Follow: use Who to follow on the Search tab or open '
                          'someone\'s profile.',
                      'Grok: ask the assistant questions or make pictures '
                          'on the Grok tab.',
                      'Messages: open the Chat tab; messages arrive in real '
                          'time.',
                      'Password: Settings and privacy → Change password.',
                    ],
                  )),
              onLogout: () => _fromDrawer(() => logOutWithConfirm(context)),
            ),
            child: app,
          ),
        ),
        // Swipe in from the left edge to open the drawer.
        if (!_drawerOpen && _index != 4)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 18,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 200) _openDrawer();
              },
            ),
          ),
      ],
    );
  }
}
