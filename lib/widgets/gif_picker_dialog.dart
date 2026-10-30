import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../services/gif_service.dart';
import 'dialog_card.dart';

/// "Choose GIF" dialog: search field and a two-column grid of GIFs.
/// Resolves to the chosen GIF's URL (or null when closed).
///
/// Without a GIPHY key (see AppConfig.giphyApiKey) the dialog explains that
/// and offers a field to paste a GIF link instead.
Future<String?> showGifPicker(BuildContext context) {
  return showCardDialog<String>(
    context,
    maxWidth: 520,
    builder: (ctx) => const _GifCard(),
  );
}

class _GifCard extends StatefulWidget {
  const _GifCard();

  @override
  State<_GifCard> createState() => _GifCardState();
}

class _GifCardState extends State<_GifCard> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _link = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  final List<GifItem> _items = [];
  bool _loading = false;
  bool _done = false;
  Object? _error;
  String _term = '';
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _load();
    });
    if (GifService.isConfigured) _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _link.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!GifService.isConfigured) return;
    if (reset) {
      _seq++;
      _items.clear();
      _done = false;
      _error = null;
    } else if (_loading || _done) {
      return;
    }
    final mine = _seq;
    setState(() => _loading = true);
    try {
      final more = _term.isEmpty
          ? await GifService.trending(offset: _items.length)
          : await GifService.search(_term, offset: _items.length);
      if (!mounted || mine != _seq) return;
      setState(() {
        _items.addAll(more);
        if (more.isEmpty) _done = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || mine != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
        _done = true;
      });
    }
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _term = v.trim();
      _load(reset: true);
    });
  }

  void _useLink() {
    final url = _link.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      showError(context, 'Please paste a link that starts with https://');
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return SizedBox(
      height: GifService.isConfigured ? height : null,
      child: Column(
        mainAxisSize:
            GifService.isConfigured ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Choose GIF',
            centered: true,
            circleClose: true,
            divider: false,
            onClose: () => Navigator.of(context).pop(),
          ),
          if (GifService.isConfigured) ...[
            const SizedBox(height: 14),
            CupertinoSearchTextField(
              controller: _query,
              placeholder: 'Search GIFs',
              onChanged: _onQuery,
              onSubmitted: (v) {
                _term = v.trim();
                _load(reset: true);
              },
              style: TextStyle(color: p.text, fontSize: 17),
              placeholderStyle: TextStyle(color: p.subtext, fontSize: 17),
              backgroundColor: p.field,
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            const SizedBox(height: 12),
            Expanded(child: _grid(p)),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Powered by GIPHY',
                  style: TextStyle(color: p.subtext, fontSize: 12),
                ),
              ),
            ),
          ] else
            _noKey(p),
        ],
      ),
    );
  }

  Widget _noKey(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'GIF search isn’t set up yet. Add a free GIPHY key '
          '(--dart-define=GIPHY_API_KEY=…) to search GIFs here.\n\n'
          'For now you can paste a link to a GIF:',
          style: TextStyle(color: p.subtext, fontSize: 15, height: 1.35),
        ),
        const SizedBox(height: 12),
        CupertinoTextField(
          controller: _link,
          placeholder: 'https://…/funny.gif',
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: TextStyle(color: p.text, fontSize: 16),
          placeholderStyle: TextStyle(color: p.subtext, fontSize: 16),
          cursorColor: p.accent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(height: 16),
        DialogPillButton(label: 'Add GIF', onPressed: _useLink),
      ],
    );
  }

  Widget _grid(AppPalette p) {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CupertinoActivityIndicator());
      return Center(
        child: Text(
          _error != null ? friendlyError(_error!) : 'No GIFs found.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.subtext, fontSize: 15),
        ),
      );
    }

    // Two columns; each GIF goes under the shorter column (masonry).
    final left = <GifItem>[];
    final right = <GifItem>[];
    var lh = 0.0;
    var rh = 0.0;
    for (final g in _items) {
      final h = 1 / (g.aspect <= 0 ? 1 : g.aspect);
      if (lh <= rh) {
        left.add(g);
        lh += h;
      } else {
        right.add(g);
        rh += h;
      }
    }

    Widget column(List<GifItem> list) => Expanded(
          child: Column(
            children: [
              for (final g in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(g.url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: g.aspect <= 0 ? 1 : g.aspect,
                        child: CachedNetworkImage(
                          imageUrl: g.previewUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: p.surface),
                          errorWidget: (context, url, error) =>
                              Container(color: p.surface),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [column(left), const SizedBox(width: 8), column(right)],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CupertinoActivityIndicator(),
            ),
        ],
      ),
    );
  }
}
