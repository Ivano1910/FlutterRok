import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../services/notifications_service.dart';
import '../widgets/app_shell.dart';

final _hrDateFmt = DateFormat('EEEE, dd-MM-yyyy', 'hr');
final _hrTimeFmt = DateFormat('HH:mm');

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final list = await api.getMyBookings();

      if (!mounted) return;
      setState(() {
        _bookings = list;
        _isLoading = false;
      });

      for (final b in list) {
        final id = b['id'];
        final startIso = b['start_time'];

        if (id is int && startIso is String) {
          final startLocal = DateTime.parse(startIso).toLocal();
          if (startLocal.isAfter(DateTime.now())) {
            await NotificationsService.scheduleBookingReminders(
              bookingId: id,
              bookingStartLocal: startLocal,
              titleName: (b['customer_name'] ?? 'Termin').toString(),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješno učitane rezervacije: $e')),
      );
    }
  }

  Future<void> _cancelBooking(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Otkažite rezervaciju'),
        content: const Text('Jeste li sigurni da želite otkazati ovu rezervaciju?'),
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

    if (confirm != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.cancelBooking(id);
      await NotificationsService.cancelBookingReminders(id);

      if (!mounted) return;
      setState(() {
        _bookings.removeWhere((b) => b['id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervacija otkazana')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješno otkazivanje rezervacije: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje rezervacije'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBookings,
          ),
        ],
      ),
      body: AppShell(
        maxWidth: 1100,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookings.isEmpty
                ? const Center(child: Text('Nisu pronađene rezervacije'))
                : isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.all(0),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.3,
                        ),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          return _BookingCard(
                            booking: _bookings[index],
                            onCancel: _cancelBooking,
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(0),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _BookingCard(
                              booking: _bookings[index],
                              onCancel: _cancelBooking,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Future<void> Function(int id) onCancel;

  const _BookingCard({
    required this.booking,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final id = booking['id'];
    final customerName = (booking['customer_name'] ?? 'Booking').toString();
    final startIso = (booking['start_time'] ?? '').toString();
    final endIso = (booking['end_time'] ?? '').toString();

    if (id is! int || startIso.isEmpty || endIso.isEmpty) {
      return const SizedBox.shrink();
    }

    DateTime? start;
    DateTime? end;

    try {
      start = DateTime.parse(startIso).toLocal();
      end = DateTime.parse(endIso).toLocal();
    } catch (_) {}

    final dateLabel = start == null ? '?' : _hrDateFmt.format(start);
    final startTime = start == null ? '?' : _hrTimeFmt.format(start);
    final endTime = end == null ? '?' : _hrTimeFmt.format(end);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    customerName,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => onCancel(id),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '$startTime – $endTime',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}