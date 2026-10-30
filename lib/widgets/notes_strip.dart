import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../models/models.dart';
import 'avatar.dart';

/// The row of Notes at the top of the Chat tab: first "Your note", then the
/// notes of the people I follow, newest first. Each one is a round picture
/// with the short text in a speech bubble above it.
class NotesStrip extends StatelessWidget {
  const NotesStrip({
    super.key,
    required this.me,
    required this.mine,
    required this.notes,
    required this.onMine,
    required this.onNote,
  });

  final Profile? me;

  /// My own active note, if any.
  final StatusNote? mine;

  /// Notes of other people.
  final List<StatusNote> notes;

  final VoidCallback onMine;
  final ValueChanged<StatusNote> onNote;

  static const double _itemWidth = 84;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: notes.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _NoteItem(
              text: mine?.content,
              placeholder: 'Share a thought',
              url: me?.avatarUrl,
              name: me?.name ?? 'You',
              label: 'Your note',
              addBadge: mine == null,
              onTap: onMine,
            );
          }
          final n = notes[i - 1];
          return _NoteItem(
            text: n.content,
            url: n.avatarUrl,
            name: n.name,
            label: n.name,
            square: Avatar.isSquare(n.verified),
            onTap: () => onNote(n),
          );
        },
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  const _NoteItem({
    required this.text,
    required this.url,
    required this.name,
    required this.label,
    required this.onTap,
    this.placeholder = '',
    this.addBadge = false,
    this.square = false,
  });

  final String? text;
  final String placeholder;
  final String? url;
  final String name;
  final String label;
  final bool addBadge;
  final bool square;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasText = (text ?? '').isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: NotesStrip._itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Speech bubble.
            Container(
              constraints: const BoxConstraints(maxWidth: 78, minWidth: 40),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border, width: 0.5),
              ),
              child: Text(
                hasText ? text! : placeholder,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasText ? p.text : p.subtext,
                  fontSize: 12,
                  height: 1.2,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            // Two small circles make the "thought bubble" tail.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: p.field, shape: BoxShape.circle),
                  ),
                  const SizedBox(height: 1),
                  Container(
                    width: 4,
                    height: 4,
                    decoration:
                        BoxDecoration(color: p.field, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Avatar(url: url, name: name, size: 56, square: square),
                  if (addBadge)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.background, width: 2),
                        ),
                        child: const Icon(
                          CupertinoIcons.add,
                          size: 13,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.subtext,
                fontSize: 12,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
