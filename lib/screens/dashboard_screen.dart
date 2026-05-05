import 'package:flutter/material.dart';
import 'package:kondokoinventorysystem/screens/itemdashboard_screen.dart';
import 'package:kondokoinventorysystem/screens/settings_screen.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';
import '../widgets/kondo_app_bar.dart';
import '../widgets/navbar.dart';
import '../services/key_service.dart';
import '../services/item_service.dart';
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
      _HomeTab(firstName: widget.firstName, token: widget.token),
      KeyDashboardScreen(token: widget.token),
      ItemsScreen(token: widget.token),
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
class _HomeTab extends StatefulWidget {
  final String firstName;
  final String token;

  const _HomeTab({required this.firstName, required this.token});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late final KeyService  _keyService;
  late final ItemService _itemService;

  int  _keyGroupsCount = 0;
  int  _itemsCount     = 0;
  bool _isLoading      = true;

  @override
  void initState() {
    super.initState();
    _keyService  = KeyService(token: widget.token);
    _itemService = ItemService(token: widget.token);
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _keyService.getAllGroups(),
        _itemService.getAllItems(),
      ]);

      if (mounted) {
        setState(() {
          _keyGroupsCount = results[0].length;
          _itemsCount     = results[1].length;
          _isLoading      = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Column(
      children: [
        // ── App Bar ────────────────────────────────────
        KondoAppBar(title: 'Home'),

        // ── Body ───────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(SU.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SU.hp(0.02)),

                // ── Welcome Card ─────────────────────
                _WelcomeCard(firstName: widget.firstName),

                SizedBox(height: SU.md),

                // ── Stat Cards Row ───────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon:      Icons.key,
                        count:     _keyGroupsCount,
                        label:     'Key Groups',
                        isLoading: _isLoading,
                      ),
                    ),
                    SizedBox(width: SU.md),
                    Expanded(
                      child: _StatCard(
                        icon:      Icons.inventory_2,
                        count:     _itemsCount,
                        label:     'Items',
                        isLoading: _isLoading,
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

// ── Welcome Card ───────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final String firstName;

  const _WelcomeCard({required this.firstName});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: SU.md,
        vertical:   SU.sm + 4,
      ),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(SU.radiusLg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_circle_outlined,
            size:  SU.xl,
            color: Colors.black87,
          ),
          SizedBox(width: SU.sm),
          Flexible(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Welcome, ',
                    style: TextStyle(
                      fontSize:   SU.textLg,
                      color:      Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: firstName,
                    style: TextStyle(
                      fontSize:   SU.textLg,
                      color:      Colors.black87,
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
  final int      count;
  final String   label;
  final bool     isLoading;

  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Container(
      height: SU.hp(0.16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(SU.radiusLg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: SU.xl, color: Colors.black87),
          SizedBox(height: SU.xs),
          isLoading
              ? SizedBox(
                  width:  SU.md,
                  height: SU.md,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(AppConstants.primaryColorValue),
                  ),
                )
              : Text(
                  '$count',
                  style: TextStyle(
                    fontSize:   SU.textXl,
                    fontWeight: FontWeight.w700,
                    color:      Colors.black87,
                  ),
                ),
          SizedBox(height: SU.xs / 2),
          Text(
            label,
            style: TextStyle(
              fontSize:   SU.textSm,
              fontWeight: FontWeight.w500,
              color:      Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}