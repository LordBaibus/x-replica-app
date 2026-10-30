import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/profile_view.dart';
import '../services/api.dart';
import 'person_tile.dart';
import 'state_views.dart';

/// "Who to follow": real members I don't follow yet, with Follow buttons.
///
/// * [maxItems] == null: a scrolling list (sign-up step, "Connect" page).
/// * [maxItems] set: a short non-scrolling column to embed in another page.
class SuggestedList extends StatefulWidget {
  const SuggestedList({
    super.key,
    this.maxItems,
    this.bottomPadding = 24,
    this.onFollowChanged,
    this.emptyText = 'No one else is here yet. Invite your classmates to join!',
  });

  final int? maxItems;
  final double bottomPadding;

  /// Called with the number of accounts followed from this list so far.
  final ValueChanged<int>? onFollowChanged;
  final String emptyText;

  @override
  State<SuggestedList> createState() => SuggestedListState();
}

class SuggestedListState extends State<SuggestedList> {
  List<Suggestion> _items = const [];
  bool _loading = true;
  Object? _error;
  int _followed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.suggestedProfiles(limit: widget.maxItems ?? 30);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _toggle(Suggestion s) async {
    final i = _items.indexWhere((x) => x.profile.id == s.profile.id);
    if (i < 0) return;
    final next = s.profile.afterFollowTap();
    final now = next.followedByMe || next.requestedByMe;
    final updated = s.copyWith(profile: next);
    setState(() {
      _items = [..._items]..[i] = updated;
      _followed += now ? 1 : -1;
    });
    widget.onFollowChanged?.call(_followed);
    try {
      await Api.setFollow(s.profile.id, follow: now);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [..._items]..[i] = s;
        _followed += now ? -1 : 1;
      });
      widget.onFollowChanged?.call(_followed);
      showError(context, e);
    }
  }

  Widget _tile(Suggestion s) => PersonTile(
        key: ValueKey(s.profile.id),
        profile: s.profile,
        contextLabel: s.context,
        onTap: () => Navigator.of(context)
            .push(appRoute(ProfileScreen(userId: s.profile.id))),
        onToggleFollow: () => _toggle(s),
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final embedded = widget.maxItems != null;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: embedded ? 24 : 60),
        child: const LoadingView(),
      );
    }
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.people, size: 40, color: p.subtext),
            const SizedBox(height: 12),
            Text(
              widget.emptyText,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 15, height: 1.35),
            ),
          ],
        ),
      );
    }

    if (embedded) {
      final shown = _items.take(widget.maxItems!).toList();
      return Column(children: [for (final s in shown) _tile(s)]);
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      itemCount: _items.length,
      itemBuilder: (context, i) => _tile(_items[i]),
    );
  }
}
