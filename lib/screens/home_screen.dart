import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/providers.dart';
import '../services/jwt_utils.dart';
import 'admin_bookings_screen.dart';
import 'booking_screen.dart';
import 'my_bookings_screen.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';
import 'admin_schedule_v2_screen.dart';
import '../services/notifications_service.dart';

final hrDateFmt = DateFormat('EEEE, dd-MM-yyyy', 'hr');
final hrTimeFmt = DateFormat('HH:mm');

String formatHrDateTime(String iso, {bool dateOnly = false}) {
  final dt = DateTime.parse(iso).toLocal();
  final d = hrDateFmt.format(dt);
  if (dateOnly) return d;
  final t = hrTimeFmt.format(dt);
  return '$d  $t';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenFuture = ref.watch(tokenStorageProvider).getToken();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barber Rok'),
        actions: [
          // ✅ TEST NOTIFICATION BUTTON
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () async {
              await NotificationsService.debugNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notifikacija poslana')),
                );
              }
            },
          ),

          // ✅ LOGOUT BUTTON
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              // ✅ No navigation here. main.dart will rebuild to LoginScreen.
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Container(
                    height: 200,
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Icon(Icons.storefront, size: 80, color: Colors.white24),
                    ),
                  ),
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Barber Rok',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rezervirajte svoje mjesto već danas',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BookingScreen()),
                );
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Rezerviraj termin'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
                );
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Moje rezervacije'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
            ),

            const SizedBox(height: 16),

            FutureBuilder<String?>(
              future: tokenFuture,
              builder: (context, snapshot) {
                final token = snapshot.data;
                final role = (token == null) ? null : jwtRole(token);

                if (role != 'admin') {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminScheduleV2Screen()),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Admin - Raspored'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminBookingsScreen()),
                        );
                      },
                      icon: const Icon(Icons.people_alt),
                      label: const Text('Admin - Klijenti'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}