import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/providers.dart';
import '../services/jwt_utils.dart';
import '../widgets/app_shell.dart';
import 'admin_bookings_screen.dart';
import 'booking_screen.dart';
import 'my_bookings_screen.dart';
import 'admin_schedule_v2_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenFuture = ref.watch(tokenStorageProvider).getToken();
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barber Rok'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: AppShell(
        maxWidth: 1100,
        child: FutureBuilder<String?>(
          future: tokenFuture,
          builder: (context, snapshot) {
            final token = snapshot.data;
            final role = (token == null) ? null : jwtRole(token);
            final isAdmin = role == 'admin';

            final actions = <Widget>[
              _HomeActionCard(
                icon: Icons.calendar_month,
                title: 'Rezerviraj termin',
                subtitle: 'Pregled slobodnih termina i nova rezervacija',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookingScreen()),
                  );
                },
              ),
              _HomeActionCard(
                icon: Icons.list_alt,
                title: 'Moje rezervacije',
                subtitle: 'Pregled i otkazivanje postojećih termina',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                  );
                },
              ),
              if (isAdmin)
                _HomeActionCard(
                  icon: Icons.admin_panel_settings,
                  title: 'Admin - Raspored',
                  subtitle: 'Uređivanje radnih dana, perioda i iznimki',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminScheduleV2Screen()),
                    );
                  },
                ),
              if (isAdmin)
                _HomeActionCard(
                  icon: Icons.people_alt,
                  title: 'Admin - Klijenti',
                  subtitle: 'Pregled rezervacija i upravljanje terminima',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminBookingsScreen()),
                    );
                  },
                ),
            ];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      height: 220,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.storefront, size: 56, color: Colors.white24),
                          SizedBox(height: 16),
                          Text(
                            'Barber Rok',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Rezervirajte svoje mjesto brzo i jednostavno',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  isWide
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: actions.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.4,
                          ),
                          itemBuilder: (context, index) => actions[index],
                        )
                      : Column(
                          children: [
                            for (final action in actions) ...[
                              action,
                              const SizedBox(height: 16),
                            ]
                          ],
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}