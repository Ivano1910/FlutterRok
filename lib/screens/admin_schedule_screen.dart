import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import 'package:intl/intl.dart';

final hrDateFmt = DateFormat('EEEE, dd-MM-yyyy', 'hr');
final hrTimeFmt = DateFormat('HH:mm');

String formatHrDateTime(String iso, {bool dateOnly = false}) {
  final dt = DateTime.parse(iso).toLocal();
  final d = hrDateFmt.format(dt);
  if (dateOnly) return d;
  final t = hrTimeFmt.format(dt);
  return '$d  $t';
}

class AdminScheduleScreen extends ConsumerStatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  ConsumerState<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends ConsumerState<AdminScheduleScreen> {
  final _apiDateFmt = DateFormat('yyyy-MM-dd');
  final _hrDateFmt = DateFormat('EEEE, dd-MM-yyyy', 'hr');

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30)); // ✅ month default

  bool _loading = true;
  String? _error;

  // dayStr -> list of periods [{start_time:"08:00:00", end_time:"10:00:00", id:...}]
  final Map<String, List<Map<String, dynamic>>> _periodsByDay = {};

  @override
  void initState() {
    super.initState();
    _fetchRange();
  }

  String _dApi(DateTime dt) => _apiDateFmt.format(dt);
  String _dHr(DateTime dt) => _hrDateFmt.format(dt);

  List<String> _rangeDays() {
    final out = <String>[];
    var cur = DateTime(_start.year, _start.month, _start.day);
    final end = DateTime(_end.year, _end.month, _end.day);

    while (!cur.isAfter(end)) {
      out.add(_dApi(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return out;
  }

  String _hhmm(dynamic t, {String fallback = '08:00'}) {
    if (t == null) return fallback;
    final s = t.toString(); // "08:00:00"
    return s.length >= 5 ? s.substring(0, 5) : fallback;
  }

  Future<void> _fetchRange() async {
    setState(() {
      _loading = true;
      _error = null;
      _periodsByDay.clear();
    });

    try {
      final api = ref.read(apiServiceProvider);
      final days = _rangeDays();

      // Fetch sequentially (simple MVP). If you want faster later, we can parallelize.
      for (final day in days) {
        final periods = await api.adminGetPeriods(day);
        _periodsByDay[day] = periods;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _start = picked);
    if (_end.isBefore(_start)) setState(() => _end = _start);
    await _fetchRange();
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _end = picked);
    await _fetchRange();
  }

  Future<String?> _pickTime(BuildContext context, String initialHHmm) async {
    final parts = initialHHmm.split(':');
    final init = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final t = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (t == null) return null;

    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<Map<String, dynamic>> _ensureDay(String day) {
    return _periodsByDay.putIfAbsent(day, () => []);
  }

  bool _validatePeriods(List<Map<String, dynamic>> periods) {
    // convert & sort by start
    final list = periods
        .map((p) => {'start': _hhmm(p['start_time']), 'end': _hhmm(p['end_time'])})
        .toList();

    list.sort((a, b) => a['start']!.compareTo(b['start']!));

    // start < end and no overlaps
    for (final p in list) {
      if (p['end']!.compareTo(p['start']!) <= 0) return false;
    }
    for (int i = 1; i < list.length; i++) {
      if (list[i]['start']!.compareTo(list[i - 1]['end']!) < 0) return false;
    }
    return true;
  }

  Future<void> _saveDay(String day) async {
    final periods = _ensureDay(day);

    if (!_validatePeriods(periods)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid periods (overlap or end <= start)')),
      );
      return;
    }

    final payload = periods.map((p) {
      final s = _hhmm(p['start_time'], fallback: '08:00');
      final e = _hhmm(p['end_time'], fallback: '17:00');
      return {'start': s, 'end': e};
    }).toList();

    try {
      final api = ref.read(apiServiceProvider);

      if (payload.isEmpty) {
        await api.adminClearPeriods(day);
      } else {
        await api.adminSetPeriods(day, payload);
      }

      // reload just that day from server
      final fresh = await api.adminGetPeriods(day);
      setState(() => _periodsByDay[day] = fresh);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${day}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  void _addPeriod(String day) {
    final list = _ensureDay(day);

    setState(() {
      list.add({
        'start_time': '08:00:00',
        'end_time': '10:00:00',
      });
    });
  }

  void _removePeriod(String day, int index) {
    final list = _ensureDay(day);
    setState(() {
      list.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _rangeDays();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Raspored (Periods)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRange),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickStart,
                            child: Text('Start: ${_dHr(_start)}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickEnd,
                            child: Text('End: ${_dHr(_end)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...days.map((day) {
                      final periods = _ensureDay(day);
                      final isClosed = periods.isEmpty;

                      // Convert API day (yyyy-MM-dd) to hr label
                      final parsed = DateTime.parse(day);
                      final dayLabel = _dHr(parsed);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      dayLabel,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  Text(isClosed ? 'Zatvoreno' : 'Otvoreno'),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (periods.isEmpty)
                                const Text('No periods set (closed)')
                              else
                                Column(
                                  children: List.generate(periods.length, (i) {
                                    final p = periods[i];
                                    final s = _hhmm(p['start_time'], fallback: '08:00');
                                    final e = _hhmm(p['end_time'], fallback: '10:00');

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                final picked = await _pickTime(context, s);
                                                if (picked == null) return;
                                                setState(() {
                                                  p['start_time'] = '$picked:00';
                                                });
                                              },
                                              child: Text('Start: $s'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                final picked = await _pickTime(context, e);
                                                if (picked == null) return;
                                                setState(() {
                                                  p['end_time'] = '$picked:00';
                                                });
                                              },
                                              child: Text('End: $e'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () => _removePeriod(day, i),
                                            icon: const Icon(Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),

                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _addPeriod(day),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add period'),
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: () => _saveDay(day),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),

                              if (periods.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Tip: Split shift example: 08:00–10:00 and 13:00–17:00',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}