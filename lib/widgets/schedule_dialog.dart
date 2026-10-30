import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import 'dialog_card.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "Mon, Oct 26 at 11:45"
String formatScheduled(DateTime d) {
  final t = d.toLocal();
  return '${_weekdays[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day} '
      'at ${_two(t.hour)}:${_two(t.minute)}';
}

/// "Today at 11:45", "Tomorrow at 09:00" or "Oct 26 at 11:45"
String friendlyScheduled(DateTime d) {
  final t = d.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = day.difference(today).inDays;
  final time = '${_two(t.hour)}:${_two(t.minute)}';
  if (diff == 0) return 'Today at $time';
  if (diff == 1) return 'Tomorrow at $time';
  return '${_months[t.month - 1]} ${t.day} at $time';
}

/// What the schedule dialog returns: a time, [scheduleClear] or
/// [scheduleView] (open the scheduled posts list).
const String scheduleClear = 'clear';
const String scheduleView = 'view';

/// Two-step "Schedule post" dialog: pick a day on a month calendar, then a
/// time on 24-hour wheels. Resolves to a [DateTime], [scheduleClear],
/// [scheduleView] or null when closed.
Future<Object?> showScheduleDialog(BuildContext context, {DateTime? initial}) {
  return showCardDialog<Object>(
    context,
    builder: (ctx) => _ScheduleCard(initial: initial),
  );
}

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard({this.initial});

  final DateTime? initial;

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  late DateTime _selected; // date + time
  late DateTime _month; // first day of the shown month
  bool _timeStep = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    final base = widget.initial ?? DateTime.now().add(const Duration(hours: 1));
    _selected = DateTime(base.year, base.month, base.day, base.hour, base.minute);
    _month = DateTime(_selected.year, _selected.month);
  }

  bool get _canGoBack {
    final t = _today;
    return _month.isAfter(DateTime(t.year, t.month));
  }

  bool get _canGoForward {
    final t = _today;
    return _month.isBefore(DateTime(t.year, t.month + 17));
  }

  void _shiftMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  void _pickDay(DateTime day) => setState(() {
        _selected = DateTime(
            day.year, day.month, day.day, _selected.hour, _selected.minute);
      });

  bool get _futureEnough =>
      _selected.isAfter(DateTime.now().add(const Duration(minutes: 1)));

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardHeader(
          title: _timeStep ? 'Pick a time' : 'Schedule post',
          centered: _timeStep,
          onBack: _timeStep ? () => setState(() => _timeStep = false) : null,
          onClose: () => Navigator.of(context).pop(),
        ),
        if (!_timeStep) _calendar(p) else _timePicker(p),
      ],
    );
  }

  Widget _calendar(AppPalette p) {
    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday-first: Sun=0
    final rows = ((lead + daysInMonth) / 7).ceil();
    const heads = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    Widget arrow(IconData icon, bool enabled, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: enabled ? p.text : p.subtext),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, left: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthNames[first.month - 1]} ${first.year}',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              arrow(CupertinoIcons.chevron_left, _canGoBack, () => _shiftMonth(-1)),
              arrow(CupertinoIcons.chevron_right, _canGoForward, () => _shiftMonth(1)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final h in heads)
              Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: TextStyle(
                      color: p.subtext,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++) _cell(p, r * 7 + c - lead + 1, daysInMonth),
            ],
          ),
        const SizedBox(height: 14),
        DialogPillButton(
          label: 'Next',
          onPressed: () => setState(() => _timeStep = true),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(scheduleView),
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 2),
            child: Center(
              child: Text(
                'Scheduled posts',
                style: TextStyle(
                  color: p.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(AppPalette p, int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return const Expanded(child: SizedBox(height: 46));
    }
    final date = DateTime(_month.year, _month.month, day);
    final past = date.isBefore(_today);
    final selected = date.year == _selected.year &&
        date.month == _selected.month &&
        date.day == _selected.day;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: past ? null : () => _pickDay(date),
        child: SizedBox(
          height: 46,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? p.text : const Color(0x00000000),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  color: selected
                      ? p.background
                      : (past ? p.subtext : p.text),
                  fontSize: 18,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timePicker(AppPalette p) {
    final t = _selected;
    final label = 'Your post will be sent on ${_months[t.month - 1]} ${t.day}, '
        '${t.year} at ${_two(t.hour)}:${_two(t.minute)}.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 16),
          ),
        ),
        if (!_futureEnough)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              'Pick a time in the future.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.danger, fontSize: 14),
            ),
          ),
        SizedBox(
          height: 190,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness:
                  identical(p, AppPalette.dark) ? Brightness.dark : Brightness.light,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(color: p.text, fontSize: 22),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: _selected,
              onDateTimeChanged: (d) => setState(() {
                _selected = DateTime(
                    _selected.year, _selected.month, _selected.day, d.hour, d.minute);
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        DialogPillButton(
          label: 'Schedule',
          onPressed: _futureEnough ? () => Navigator.of(context).pop(_selected) : null,
        ),
        if (widget.initial != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(scheduleClear),
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              child: Center(
                child: Text(
                  'Remove schedule',
                  style: TextStyle(
                    color: p.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
