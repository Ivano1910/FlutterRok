import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../services/notifications_service.dart';
import '../widgets/app_shell.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  final _nameController = TextEditingController();

  List<String> _availableSlots = [];
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;
  bool _prefilled = false;

  final _apiDateFmt = DateFormat('yyyy-MM-dd');
  final _hrDateFmt = DateFormat('EEEE, dd-MM-yyyy', 'hr');
  final _hrDowFmt = DateFormat('EEE', 'hr');
  final _hrTimeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();

    _nameController.addListener(() {
      if (mounted) setState(() {});
    });

    _prefillName();
    _fetchAvailability();
  }

  Future<void> _prefillName() async {
    if (_prefilled) return;
    _prefilled = true;

    try {
      final api = ref.read(apiServiceProvider);
      final profile = await api.getMe();

      final first = (profile['first_name'] ?? '').toString().trim();
      final last = (profile['last_name'] ?? '').toString().trim();

      final full = ('$first $last').trim();

      if (mounted && full.isNotEmpty && _nameController.text.trim().isEmpty) {
        _nameController.text = full;
      }
    } catch (_) {
      // If profile fetch fails, user can still type the name manually.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailability() async {
    setState(() {
      _isLoadingSlots = true;
      _selectedSlot = null;
      _availableSlots = [];
    });

    try {
      final api = ref.read(apiServiceProvider);
      final dayStr = _apiDateFmt.format(_selectedDate);
      final slots = await api.getAvailability(dayStr);

      if (!mounted) return;
      setState(() {
        _availableSlots = slots;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješno učitani termini: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  DateTime _slotToDateTime(DateTime day, String slot) {
    try {
      return DateTime.parse(slot).toLocal();
    } catch (_) {
      final parts = slot.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(day.year, day.month, day.day, hour, minute);
    }
  }

  String _slotLabel(String slot) {
    try {
      final dt = DateTime.parse(slot).toLocal();
      return _hrTimeFmt.format(dt);
    } catch (_) {
      return slot;
    }
  }

  Future<void> _createBooking() async {
    if (_selectedSlot == null) return;
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);
      final startDt = _slotToDateTime(_selectedDate, _selectedSlot!);

      final booking = await api.createBooking(
        customerName: _nameController.text.trim(),
        startTime: startDt,
      );

      final id = booking['id'];
      final startIso = booking['start_time'];
      if (id is int && startIso is String) {
        final startLocal = DateTime.parse(startIso).toLocal();
        await NotificationsService.scheduleBookingReminders(
          bookingId: id,
          bookingStartLocal: startLocal,
          titleName: _nameController.text.trim(),
        );
      }

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervacija potvrđena!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješna rezervacija: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    final leftPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Odaberite datum',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
          isWide
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(60, (index) {
                    final date = DateTime.now().add(Duration(days: index));
                    final isSelected = DateUtils.isSameDay(date, _selectedDate);

                    return ChoiceChip(
                      label: SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_hrDowFmt.format(date).toUpperCase()),
                            Text(
                              DateFormat('dd.MM', 'hr').format(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedDate = date);
                          _fetchAvailability();
                        }
                      },
                    );
                  }),
                )
              : SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 60,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final date = DateTime.now().add(Duration(days: index));
                      final isSelected = DateUtils.isSameDay(date, _selectedDate);

                      return ChoiceChip(
                        label: SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_hrDowFmt.format(date).toUpperCase()),
                              Text(
                                DateFormat('dd.MM', 'hr').format(date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedDate = date);
                            _fetchAvailability();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slobodni termini za ${_hrDateFmt.format(_selectedDate)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_isLoadingSlots)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ))
                else if (_availableSlots.isEmpty)
                  WaitlistCard(
                    selectedDate: _selectedDate,
                    hrDateFmt: _hrDateFmt,
                    onJoined: () {},
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _availableSlots.map((slot) {
                      return ChoiceChip(
                        label: Text(_slotLabel(slot)),
                        selected: _selectedSlot == slot,
                        onSelected: (selected) {
                          setState(() => _selectedSlot = selected ? slot : null);
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    final rightPanel = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Podaci rezervacije',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ime i prezime klijenta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Datum'),
              subtitle: Text(_hrDateFmt.format(_selectedDate)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Termin'),
              subtitle: Text(
                _selectedSlot == null ? 'Nije odabran' : _slotLabel(_selectedSlot!),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_selectedSlot != null &&
                      _nameController.text.trim().isNotEmpty &&
                      !_isSubmitting)
                  ? _createBooking
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text('Potvrdi rezervaciju'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Nova rezervacija')),
      body: AppShell(
        maxWidth: 1200,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isWide) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: leftPanel),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: rightPanel),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              children: [
                leftPanel,
                const SizedBox(height: 16),
                rightPanel,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------- WAITLIST CARD ----------------

class WaitlistCard extends ConsumerStatefulWidget {
  const WaitlistCard({
    super.key,
    required this.selectedDate,
    required this.hrDateFmt,
    required this.onJoined,
  });

  final DateTime selectedDate;
  final DateFormat hrDateFmt;
  final VoidCallback onJoined;

  @override
  ConsumerState<WaitlistCard> createState() => _WaitlistCardState();
}

class _WaitlistCardState extends ConsumerState<WaitlistCard> {
  bool _loading = true;
  Map<String, dynamic>? _activeWaitlist;

  int _days = 3;
  bool _useWindow = false;
  String? _windowStart;
  String? _windowEnd;
  bool _submitting = false;

  final _hrDayDate = DateFormat('EEEE, dd-MM-yyyy', 'hr');
  final _hrDateOnly = DateFormat('dd-MM-yyyy', 'hr');

  String _fmtDate(DateTime d) => _hrDateOnly.format(d);

  @override
  void initState() {
    super.initState();
    _loadWaitlist();
  }

  Future<void> _loadWaitlist() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getMyWaitlist();
      setState(() {
        _activeWaitlist = data['waitlist'];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _pickTime(BuildContext context, TimeOfDay initial) async {
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
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

  Future<void> _join() async {
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);

      await api.joinWaitlist(
        days: _days,
        windowStart: _useWindow ? _windowStart : null,
        windowEnd: _useWindow ? _windowEnd : null,
      );

      if (!mounted) return;
      await _loadWaitlist();

      widget.onJoined();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodani ste u listu čekanja')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspjelo priključivanje listi čekanja: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _leave() async {
    final id = _activeWaitlist?['id'];
    if (id == null) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.leaveWaitlist(id);

      if (!mounted) return;
      setState(() => _activeWaitlist = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lista čekanja uklonjena')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješno napuštanje liste čekanja: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_activeWaitlist != null) {
      final start = _activeWaitlist!['start_date']?.toString();
      final end = _activeWaitlist!['end_date']?.toString();
      final ws = _activeWaitlist!['window_start']?.toString();
      final we = _activeWaitlist!['window_end']?.toString();

      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Na listi čekanja ste',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (start != null && end != null)
                Text(
                  'Raspon: ${_fmtDate(DateTime.parse(start))} → ${_fmtDate(DateTime.parse(end))}',
                ),
              if (ws != null && we != null)
                Text('Vremenski period: $ws → $we'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _submitting ? null : _leave,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Napustite listu čekanja'),
              ),
            ],
          ),
        ),
      );
    }

    final selectedLabel = _hrDayDate.format(widget.selectedDate);
    final canJoin =
        !_submitting && (!_useWindow || (_windowStart != null && _windowEnd != null));

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nema termina za: $selectedLabel'),
            const SizedBox(height: 8),
            const Text(
              'Priključi se listi čekanja na:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('3 dana'),
                  selected: _days == 3,
                  onSelected: (_) => setState(() => _days = 3),
                ),
                ChoiceChip(
                  label: const Text('7 dana'),
                  selected: _days == 7,
                  onSelected: (_) => setState(() => _days = 7),
                ),
                ChoiceChip(
                  label: const Text('14 dana'),
                  selected: _days == 14,
                  onSelected: (_) => setState(() => _days = 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Koristi vremenski period'),
              value: _useWindow,
              onChanged: (v) => setState(() {
                _useWindow = v;
                if (!v) {
                  _windowStart = null;
                  _windowEnd = null;
                }
              }),
            ),
            if (_useWindow) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () async {
                              final t = await _pickTime(
                                context,
                                const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (t != null) setState(() => _windowStart = t);
                            },
                      child: Text(_windowStart == null ? 'Početno vrijeme' : _windowStart!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () async {
                              final t = await _pickTime(
                                context,
                                const TimeOfDay(hour: 17, minute: 0),
                              );
                              if (t != null) setState(() => _windowEnd = t);
                            },
                      child: Text(_windowEnd == null ? 'Kraj' : _windowEnd!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Savjet: Odaberi vrijeme poput 13:00–17:00'),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: canJoin ? _join : null,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Priključi se listi čekanja'),
            ),
          ],
        ),
      ),
    );
  }
}