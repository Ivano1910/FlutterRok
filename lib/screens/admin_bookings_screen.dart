import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';

final _apiDateFmt = DateFormat('yyyy-MM-dd');
final _hrDateFmt = DateFormat('EEEE, dd-MM-yyyy', 'hr');
final _hrTimeFmt = DateFormat('HH:mm');

class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen> {
  DateTime _selectedDay = DateTime.now();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
      final api = ref.read(apiServiceProvider);
      final dayStr = _apiDateFmt.format(_selectedDay);
      final list = await api.adminGetBookings(dayStr);

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _selectedDay = picked);
    _load();
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Otkaži termin'),
        content: const Text('Jeste li sigurni da želite otkazati ovaj termin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ne'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Da'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.cancelBooking(booking['id'] as int);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Termin je otkazan.'),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška: $e'),
        ),
      );
    }
  }

  String _displayName(Map<String, dynamic> b) {
    final customerName = (b['customer_name'] ?? '').toString().trim();
    if (customerName.isNotEmpty) return customerName;

    final parentName = (b['parent_name'] ?? '').toString().trim();
    if (parentName.isNotEmpty) return parentName;

    final first = (b['first_name'] ?? '').toString().trim();
    final last = (b['last_name'] ?? '').toString().trim();
    final full = ('$first $last').trim();
    if (full.isNotEmpty) return full;

    final email = (b['user_email'] ?? b['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;

    return 'Nepoznato';
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = _hrDateFmt.format(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Klijenti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDay,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Greška: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dayLabel,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _pickDay,
                            icon: const Icon(Icons.edit_calendar),
                            label: const Text('Promjeni'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(child: Text('Nema rezervacija za odabrani dan'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final b = _items[i];
                                final startStr = (b['start_time'] ?? '').toString();
                                final endStr = (b['end_time'] ?? '').toString();

                                DateTime? start;
                                DateTime? end;
                                try {
                                  start = DateTime.parse(startStr).toLocal();
                                  end = DateTime.parse(endStr).toLocal();
                                } catch (_) {}

                                final timeText = (start == null || end == null)
                                    ? '?'
                                    : '${_hrTimeFmt.format(start)}–${_hrTimeFmt.format(end)}';

                                final name = _displayName(b);
                                final phone = (b['phone'] ?? '').toString().trim();
                                final email = (b['user_email'] ?? '').toString().trim();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 96,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            color: Colors.black.withOpacity(0.10),
                                          ),
                                          child: Text(
                                            timeText,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: Theme.of(context).textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 6),
                                              if (phone.isNotEmpty) Text('📞 $phone'),
                                              if (email.isNotEmpty) Text('✉️ $email'),
                                              const SizedBox(height: 12),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  onPressed: () => _cancelBooking(b),
                                                  icon: const Icon(Icons.cancel),
                                                  label: const Text('Otkaži termin'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}