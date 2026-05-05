import 'package:flutter/material.dart';
import '../utils/screen_util.dart';
import '../utils/constants.dart';
import '../screens/settings_screen.dart';


class KondoAppBar extends StatelessWidget {
  final String        title;
  final bool          showBack;
  final bool          showLogo;
  final bool          showSettings;
  final List<Widget>? actions;
  final VoidCallback? onBackTap;

  const KondoAppBar({
    super.key,
    required this.title,
    this.showBack     = false,
    this.showLogo     = true,
    this.showSettings = true,
    this.actions,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Container(
      color: const Color(AppConstants.primaryColorValue),
      padding: EdgeInsets.only(
        top:    SU.topSafe + SU.sm,
        bottom: SU.sm + 4,
        left:   showBack ? 4 : SU.md,
        right:  SU.md,
      ),
      child: Row(
        children: [
          // ── Back button ─────────────────────────
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 20),
              onPressed: onBackTap ?? () => Navigator.pop(context),
            ),

          
          if (showLogo && !showBack) ...[
            Image.asset(
              'lib/assets/KondoKoLogo2.png',
              width: 50,
              height: 50,
            ),
            const SizedBox(width: 2),
          ],

          // ── Title ────────────────────────────────
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: SU.textXl,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),

          // ── Custom actions ────────────────────────
          if (actions != null) ...actions!,

          // ── Navigates to SettingsScreen ──
          if (showSettings && actions == null)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              ),
              icon: Icon(Icons.settings_outlined,
                  color: Colors.white, size: SU.iconMd),
            ),
        ],
      ),
    );
  }
}