import 'package:flutter/material.dart';
import 'package:kondokoinventorysystem/screens/item_screen.dart';
import 'package:kondokoinventorysystem/screens/settings_screen.dart';
import '../utils/constants.dart';
import '../widgets/navbar.dart';
import 'keydashboard_screen.dart';


class DashboardScreen extends StatefulWidget {
  final String firstName;
  final String token;

  const DashboardScreen({
    super.key,
    required this.firstName,
    required this.token,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _HomeTab(firstName: widget.firstName),
      KeyDashboardScreen(token: widget.token),
      ItemsScreen(token: widget.token),  // ← token passed, removed const
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColorValue),
      body: _screens[_currentIndex],
      bottomNavigationBar: KondoKoNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// ── Home Tab ───────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String firstName;

  const _HomeTab({required this.firstName});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double horizontalPadding = size.width * 0.05;
    final double cardSpacing = size.width * 0.04;

    return Column(
      children: [
        // ── Orange App Bar ─────────────────────────────
        _KondoAppBar(),

        // ── Body ───────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.02),

                // ── Welcome Card ───────────────────────
                _WelcomeCard(firstName: firstName),

                SizedBox(height: cardSpacing),

                // ── Stat Cards Row ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.key,
                        count: 120,
                        label: 'Keys',
                      ),
                    ),
                    SizedBox(width: cardSpacing),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.inventory_2,
                        count: 98,
                        label: 'Items',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── App Bar ────────────────────────────────────────────
class _KondoAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: const Color(AppConstants.primaryColorValue),
      padding: EdgeInsets.only(
        top: topPadding + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // K Logo + Home text
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    'k',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Home',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Settings icon
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Welcome Card ───────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final String firstName;

  const _WelcomeCard({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_circle_outlined,
            size: 40,
            color: Colors.black87,
          ),
          const SizedBox(width: 14),
          Flexible(
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'Welcome, ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: firstName,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardHeight = size.height * 0.16;

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: size.width * 0.1, color: Colors.black87),
          SizedBox(height: size.height * 0.01),
          Text(
            '$count',
            style: TextStyle(
              fontSize: size.width * 0.07,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}