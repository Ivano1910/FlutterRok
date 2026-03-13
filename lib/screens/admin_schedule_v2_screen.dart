import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';

class AdminScheduleV2Screen extends ConsumerStatefulWidget {
  const AdminScheduleV2Screen({super.key});

  @override
  ConsumerState<AdminScheduleV2Screen> createState() => _AdminScheduleV2ScreenState();
}

class _AdminScheduleV2ScreenState extends ConsumerState<AdminScheduleV2Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Schedule'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Tjedni(fiksni)'),
            Tab(text: 'Iznimke(prepravi fiksni)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _WeeklyScheduleTab(),
          _OverrideDateTab(),
        ],
      ),
    );
  }
}

// ---------------- WEEKLY TAB ----------------

class _WeeklyScheduleTab extends ConsumerStatefulWidget {
  const _WeeklyScheduleTab();

  @override
  ConsumerState<_WeeklyScheduleTab> createState() => _WeeklyScheduleTabState();
}

class _WeeklyScheduleTabState extends ConsumerState<_WeeklyScheduleTab> {
  bool _loading = true;
  String? _error;

  // weekday -> list of periods {"start_time":"08:00:00","end_time":"13:00:00"}
  final Map<int, List<Map<String, dynamic>>> _weekly = {
    0: [],
    1: [],
    2: [],
    3: [],
    4: [],
    5: [],
    6: [],
  };

  final _weekdayLabels = const [
    'Ponedjeljak', 'Utorak', 'Srijeda', 'Četvrtak', 'Petak', 'Subota', 'Nedjelja'
  ];

  @override
  void initState() {
    super.initState();
    _fetchWeekly();
  }

  Future<void> _fetchWeekly() async {
    setState(() {
      _loading = true;
      _error = null;
      for (final k in _weekly.keys) {
        _weekly[k] = [];
      }
    });

    try {
      final api = ref.read(apiServiceProvider);
      final rows = await api.adminGetWeeklyPeriods();
      for (final r in rows) {
        final wd = (r['weekday'] as num?)?.toInt();
        if (wd != null && _weekly.containsKey(wd)) {
          _weekly[wd]!.add(Map<String, dynamic>.from(r));
        }
      }
      // sort each day
      for (final wd in _weekly.keys) {
        _weekly[wd]!.sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hhmm(dynamic t) {
    if (t == null) return '00:00';
    final s = t.toString(); // "08:00:00"
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay init) async {
    return showTimePicker(
      context: context,
      initialTime: init,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
  }

  Future<void> _addBlock(int weekday) async {
    final start = await _pickTime(const TimeOfDay(hour: 9, minute: 0));
    if (start == null) return;

    final end = await _pickTime(TimeOfDay(hour: start.hour + 1, minute: start.minute));
    if (end == null) return;

    final st = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00';
    final et = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:00';

    setState(() {
      _weekly[weekday]!.add({'weekday': weekday, 'start_time': st, 'end_time': et});
      _weekly[weekday]!.sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));
    });
  }

  void _removeBlock(int weekday, int index) {
    setState(() {
      _weekly[weekday]!.removeAt(index);
    });
  }

  Future<void> _saveDay(int weekday) async {
    try {
      final api = ref.read(apiServiceProvider);

      final periods = _weekly[weekday]!
          .map((p) => {
                'start_time': p['start_time'].toString(),
                'end_time': p['end_time'].toString(),
              })
          .toList();

      final saved = await api.adminPutWeeklyPeriods(
        weekday: weekday,
        periods: periods.cast<Map<String, String>>(),
      );

      // refresh local list from server response
      setState(() {
        _weekly[weekday] = saved;
        _weekly[weekday]!.sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${_weekdayLabels[weekday]}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, wd) {
        final periods = _weekly[wd]!;
        final closed = periods.isEmpty;

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
                        _weekdayLabels[wd],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(closed ? 'Zatvoreno' : 'Otvoreno'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchWeekly,
                      tooltip: 'Reload',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (closed)
                  const Text('No blocks set (closed).')
                else
                  Column(
                    children: [
                      for (int i = 0; i < periods.length; i++)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.access_time),
                          title: Text('${_hhmm(periods[i]['start_time'])} – ${_hhmm(periods[i]['end_time'])}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeBlock(wd, i),
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addBlock(wd),
                        icon: const Icon(Icons.add),
                        label: const Text('Add block'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _saveDay(wd),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------- OVERRIDE TAB ----------------

class _OverrideDateTab extends ConsumerStatefulWidget {
  const _OverrideDateTab();

  @override
  ConsumerState<_OverrideDateTab> createState() => _OverrideDateTabState();
}

class _OverrideDateTabState extends ConsumerState<_OverrideDateTab> {
  DateTime _day = DateTime.now();
  bool _loading = true;
  String? _error;

  bool _hasOverride = false;
  bool _isClosed = false;
  final TextEditingController _note = TextEditingController();
  List<Map<String, dynamic>> _periods = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _dayStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _label(DateTime d) => DateFormat('EEEE, dd-MM-yyyy', 'hr').format(d);

  String _hhmm(dynamic t) {
    if (t == null) return '00:00';
    final s = t.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _day = picked);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasOverride = false;
      _isClosed = false;
      _note.text = '';
      _periods = [];
    });

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.adminGetOverride(_dayStr(_day));

      final override = res['override'];
      final periods = (res['periods'] as List?) ?? [];

      if (override == null) {
        _hasOverride = false;
        _isClosed = false;
        _note.text = '';
        _periods = [];
      } else {
        _hasOverride = true;
        _isClosed = override['is_closed'] == true;
        _note.text = (override['note'] ?? '').toString();
        _periods = periods.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay init) async {
    return showTimePicker(context: context, initialTime: init);
  }

  Future<void> _addBlock() async {
    final start = await _pickTime(const TimeOfDay(hour: 9, minute: 0));
    if (start == null) return;

    final end = await _pickTime(TimeOfDay(hour: start.hour + 1, minute: start.minute));
    if (end == null) return;

    final st = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00';
    final et = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:00';

    setState(() {
      _periods.add({'start_time': st, 'end_time': et});
      _periods.sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));
    });
  }

  void _removeBlock(int idx) {
    setState(() => _periods.removeAt(idx));
  }

  Future<void> _saveOverride() async {
    try {
      final api = ref.read(apiServiceProvider);
      final day = _dayStr(_day);

      final periods = _periods
          .map((p) => {
                'start_time': p['start_time'].toString(),
                'end_time': p['end_time'].toString(),
              })
          .toList()
          .cast<Map<String, String>>();

      await api.adminPutOverride(
        day: day,
        isClosed: _isClosed,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        periods: periods,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved override for $day')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _deleteOverride() async {
    final day = _dayStr(_day);
    try {
      final api = ref.read(apiServiceProvider);
      await api.adminDeleteOverride(day);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed override for $day')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    final dayLabel = _label(_day);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today),
                label: Text(dayLabel),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        const SizedBox(height: 16),

        SwitchListTile(
          value: _hasOverride,
          onChanged: (v) => setState(() => _hasOverride = v),
          title: const Text('Omogućite iznimno radno vrijeme za ovaj datum'),
          subtitle: const Text('Ako je isključeno, koristi se tjedni(fiksni) raspored'),
        ),

        if (_hasOverride) ...[
          SwitchListTile(
            value: _isClosed,
            onChanged: (v) => setState(() => _isClosed = v),
            title: const Text('Zatvoreno'),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Razlog(opcionalno)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          if (!_isClosed) ...[
            const Text('Prilagođeno radno vrijeme', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (_periods.isEmpty)
              const Text('Nije postavljeno')
            else
              Column(
                children: [
                  for (int i = 0; i < _periods.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: Text('${_hhmm(_periods[i]['start_time'])} – ${_hhmm(_periods[i]['end_time'])}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeBlock(i),
                      ),
                    )
                ],
              ),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addBlock,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj radno vrijeme'),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saveOverride,
                  child: const Text('Spremi'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _deleteOverride,
                child: const Text('Ukloni'),
              ),
            ],
          ),
        ] else ...[
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Odabir za iznimke isključen, tjedni(fiksni) raspored se koristi.'),
          ),
        ],
      ],
    );
  }
}