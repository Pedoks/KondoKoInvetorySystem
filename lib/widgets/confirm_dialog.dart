import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';

// ── Palette (matches KeyDashboard modal) ─────────────────
const _kModalBg     = Color(0xFFF2EADF);
const _kModalCardBg = Color(0xFFE8DDD0);

enum KondoConfirmType { save, delete }

class ConfirmDialog extends StatelessWidget {
  final KondoConfirmType type;
  final String?          customTitle;
  final String?          customMessage;

  const ConfirmDialog({
    super.key,
    required this.type,
    this.customTitle,
    this.customMessage,
  });

  // ── Static convenience launchers ──────────────────────
  static Future<bool> showSave(BuildContext context, {String? message}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => ConfirmDialog(
        type:          KondoConfirmType.save,
        customMessage: message,
      ),
    );
    return result == true;
  }

  static Future<bool> showDelete(BuildContext context, {String? message}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => ConfirmDialog(
        type:          KondoConfirmType.delete,
        customMessage: message,
      ),
    );
    return result == true;
  }

  // ── Config per type ───────────────────────────────────
  String get _title {
    if (customTitle != null) return customTitle!;
    switch (type) {
      case KondoConfirmType.save:   return 'Save Changes?';
      case KondoConfirmType.delete: return 'Delete Item?';
    }
  }

  String get _message {
    if (customMessage != null) return customMessage!;
    switch (type) {
      case KondoConfirmType.save:
        return 'Are you sure you want to save the changes made to this item?';
      case KondoConfirmType.delete:
        return 'Are you sure you want to delete this item? This action cannot be undone.';
    }
  }

  IconData get _icon {
    switch (type) {
      case KondoConfirmType.save:   return Icons.save_alt_rounded;
      case KondoConfirmType.delete: return Icons.delete_outline_rounded;
    }
  }

  Color get _accentColor {
    switch (type) {
      case KondoConfirmType.save:
        return const Color(AppConstants.primaryColorValue);
      case KondoConfirmType.delete:
        return Colors.red.shade500;
    }
  }

  String get _confirmLabel {
    switch (type) {
      case KondoConfirmType.save:   return 'Yes, Save';
      case KondoConfirmType.delete: return 'Yes, Delete';
    }
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: SU.wp(0.08),
        vertical:   SU.hp(0.32),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _kModalBg,
          borderRadius: BorderRadius.circular(SU.radiusXl),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.18),
              blurRadius: 28,
              offset:     const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Coloured header strip ─────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: SU.md, vertical: SU.sm + 4),
              decoration: BoxDecoration(
                color: _kModalCardBg,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(SU.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        _accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: SU.sm),
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize:   SU.textLg,
                      fontWeight: FontWeight.w700,
                      color:      Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────
            Padding(
              padding: EdgeInsets.all(SU.md),
              child: Column(
                children: [
                  SizedBox(height: SU.xs),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SU.textSm,
                      color:    Colors.black54,
                      height:   1.5,
                    ),
                  ),
                  SizedBox(height: SU.md + 4),

                  // ── Buttons ───────────────────────────
                  Row(
                    children: [
                      // Cancel
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: _kModalCardBg,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: Colors.black26, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize:   SU.textMd,
                                  fontWeight: FontWeight.w600,
                                  color:      Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: SU.sm),
                      // Confirm
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color:        _accentColor,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color:      _accentColor.withOpacity(0.35),
                                  blurRadius: 10,
                                  offset:     const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _confirmLabel,
                                style: TextStyle(
                                  fontSize:   SU.textMd,
                                  fontWeight: FontWeight.w700,
                                  color:      Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}