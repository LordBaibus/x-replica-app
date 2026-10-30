import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/image_picker_service.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import 'create_list_screen.dart' show ListMembersEditor;

/// "Edit List": banner, name, description, Private switch, "Manage members"
/// and "Delete List". Pops with `saved` or `deleted`.
class EditListScreen extends StatefulWidget {
  const EditListScreen({super.key, required this.list});

  final UserList list;

  @override
  State<EditListScreen> createState() => _EditListScreenState();
}

class _EditListScreenState extends State<EditListScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.list.name);
  late final TextEditingController _desc =
      TextEditingController(text: widget.list.description);
  late bool _private = widget.list.isPrivate;
  PickedImage? _banner;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    try {
      final img = await pickGalleryImage();
      if (img != null && mounted) setState(() => _banner = img);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _save() async {
    if (_busy || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.updateList(
        widget.list.id,
        name: _name.text,
        description: _desc.text,
        isPrivate: _private,
        newBanner: _banner,
      );
      if (mounted) Navigator.of(context).pop('saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete List?',
      message: 'This can’t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.deleteList(widget.list.id);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _members() async {
    await Navigator.of(context).push(
      appRoute(
        AdaptiveScaffold(
          backgroundColor: AppPalette.of(context).background,
          appBar: const AdaptiveAppBar(title: 'Manage members'),
          body: SafeArea(child: ListMembersEditor(listId: widget.list.id)),
        ),
      ),
    );
  }

  Widget _label(AppPalette p, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Text(
          t,
          style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      );

  Widget _input(AppPalette p, TextEditingController c, String hint,
      {int maxLength = 25, int lines = 1}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: CupertinoTextField(
        controller: c,
        placeholder: hint,
        maxLength: maxLength,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 4,
        onChanged: (_) => setState(() {}),
        cursorColor: p.accent,
        padding: EdgeInsets.zero,
        decoration: const BoxDecoration(),
        style: TextStyle(color: p.text, fontSize: 19),
        placeholderStyle: TextStyle(color: p.subtext, fontSize: 19),
      ),
    );
  }

  Widget _row(AppPalette p, String title, VoidCallback onTap,
      {bool danger = false, IconData? icon}) {
    final color = danger ? p.danger : p.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (icon != null) Icon(icon, size: 15, color: p.subtext),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final banner = _banner;
    final url = widget.list.bannerUrl;
    final canSave = _name.text.trim().isNotEmpty && !_busy;

    return PlainScaffold(
      child: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Cancel',
                            style: TextStyle(color: p.text, fontSize: 17)),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Edit List',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canSave ? _save : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _busy
                            ? const CupertinoActivityIndicator()
                            : Text(
                                'Save',
                                style: TextStyle(
                                  color: canSave ? p.accent : p.subtext,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickBanner,
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (banner != null)
                              Image.memory(banner.bytes, fit: BoxFit.cover)
                            else if (url != null && url.isNotEmpty)
                              CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                            else
                              const ColoredBox(color: Color(0xFFB2B2B2)),
                            Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Color(0x99000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.camera,
                                  size: 24,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _label(p, 'Name'),
                    _input(p, _name, 'Enter a name'),
                    _label(p, 'Description'),
                    _input(p, _desc, 'Enter a brief description',
                        maxLength: 100, lines: 3),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Private',
                                  style: TextStyle(
                                    color: p.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'When you make a List private, only you can see it.',
                                  style: TextStyle(color: p.subtext, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: _private,
                            activeTrackColor: p.accent,
                            onChanged: (v) => setState(() => _private = v),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 0.5, color: p.border),
                    _row(p, 'Manage members', _members,
                        icon: CupertinoIcons.chevron_right),
                    _row(p, 'Delete List', _delete, danger: true),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
