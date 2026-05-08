import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';

// ── Export time range options ──────────────────────────
enum ExportDateRange {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  allTime,
}

extension ExportDateRangeExt on ExportDateRange {
  String get label {
    switch (this) {
      case ExportDateRange.oneMonth:    return '1 Month';
      case ExportDateRange.threeMonths: return '3 Months';
      case ExportDateRange.sixMonths:   return '6 Months';
      case ExportDateRange.oneYear:     return '1 Year';
      case ExportDateRange.allTime:     return 'All Time';
    }
  }

  /// Returns the cutoff DateTime. Items AFTER this are included.
  /// Returns null for allTime (no filter).
  DateTime? get cutoff {
    final now = DateTime.now();
    switch (this) {
      case ExportDateRange.oneMonth:    return now.subtract(const Duration(days: 30));
      case ExportDateRange.threeMonths: return now.subtract(const Duration(days: 90));
      case ExportDateRange.sixMonths:   return now.subtract(const Duration(days: 180));
      case ExportDateRange.oneYear:     return now.subtract(const Duration(days: 365));
      case ExportDateRange.allTime:     return null;
    }
  }
}

// ── Result returned from the sheet ────────────────────
class ExportSheetResult {
  final ExportDateRange range;
  final bool isExcel;      // true = Excel, false = PDF
  final bool isDownload;   // true = save to Downloads, false = share

  const ExportSheetResult({
    required this.range,
    required this.isExcel,
    this.isDownload = false,
  });
}

// ── Bottom Sheet ───────────────────────────────────────
class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({super.key});

  /// Show the sheet and return selection. Returns null if dismissed.
  static Future<ExportSheetResult?> show(BuildContext context) {
    return showModalBottomSheet<ExportSheetResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ExportBottomSheet(),
    );
  }

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  ExportDateRange _selected    = ExportDateRange.allTime;


  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Container(
      padding: EdgeInsets.fromLTRB(SU.md, SU.md, SU.md, SU.md + 16),
      decoration: const BoxDecoration(
        color: Color(AppConstants.backgroundColorValue),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: SU.md),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ────────────────────────────────────
          Center(
            child: Text(
              'Export Data',
              style: TextStyle(
                fontSize:   SU.textLg,
                fontWeight: FontWeight.w700,
                color:      Colors.black87,
              ),
            ),
          ),
          SizedBox(height: SU.xs),
          Center(
            child: Text(
              'Select a time range then choose format',
              style: TextStyle(fontSize: SU.textSm, color: Colors.black45),
            ),
          ),

          SizedBox(height: SU.md),

          // ── Time Range Label ─────────────────────────
          Text(
            'Time Range',
            style: TextStyle(
              fontSize:   SU.textSm,
              fontWeight: FontWeight.w700,
              color:      Colors.black87,
            ),
          ),
          SizedBox(height: SU.xs),

          // ── Range Chips ──────────────────────────────
          Wrap(
            spacing:    SU.xs,
            runSpacing: SU.xs,
            children: ExportDateRange.values.map((range) {
              final isActive = _selected == range;
              return GestureDetector(
                onTap: () => setState(() => _selected = range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: SU.sm,
                    vertical:   SU.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(AppConstants.primaryColorValue)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(SU.radiusLg),
                    border: Border.all(
                      color: isActive
                          ? const Color(AppConstants.primaryColorValue)
                          : Colors.black26,
                    ),
                  ),
                  child: Text(
                    range.label,
                    style: TextStyle(
                      fontSize:   SU.textSm,
                      fontWeight: FontWeight.w600,
                      color:      isActive ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: SU.xs),

          // ── Range hint text ──────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selected.cutoff != null
                ? Padding(
                    key: ValueKey(_selected),
                    padding: EdgeInsets.symmetric(vertical: SU.xs * 0.5),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: SU.textSm, color: Colors.black38),
                        SizedBox(width: SU.xs),
                        Text(
                          'Includes records from the last '
                          '${_selected.label.toLowerCase()}',
                          style: TextStyle(
                              fontSize: SU.textXs, color: Colors.black38),
                        ),
                      ],
                    ),
                  )
                : SizedBox(key: const ValueKey('all'), height: SU.xs),
          ),

          SizedBox(height: SU.sm),
          Divider(color: Colors.black12, height: SU.xs),
          SizedBox(height: SU.sm),

          // ── Format Label ─────────────────────────────
          Text(
            'Format & Action',
            style: TextStyle(
              fontSize:   SU.textSm,
              fontWeight: FontWeight.w700,
              color:      Colors.black87,
            ),
          ),
          SizedBox(height: SU.sm),

          // ── Excel — Share tile ────────────────────────
          _ExportOptionTile(
            icon:      Icons.table_chart_outlined,
            iconColor: const Color(0xFF1D6F42),
            iconBg:    const Color(0xFFE8F5E9),
            label:     'Share as Excel',
            subtitle:  'Best for sorting & filtering data',
            onTap: () => Navigator.pop(
              context,
              ExportSheetResult(
                range:      _selected,
                isExcel:    true,
                isDownload: false,
              ),
            ),
          ),

          SizedBox(height: SU.sm),

          // ── PDF — Share tile ──────────────────────────
          _ExportOptionTile(
            icon:      Icons.picture_as_pdf_outlined,
            iconColor: const Color(0xFFD32F2F),
            iconBg:    const Color(0xFFFFEBEE),
            label:     'Share as PDF',
            subtitle:  'Best for printing & sharing',
            onTap: () => Navigator.pop(
              context,
              ExportSheetResult(
                range:      _selected,
                isExcel:    false,
                isDownload: false,
              ),
            ),
          ),

          SizedBox(height: SU.sm),
],
      ),
    );
  }
}

// ── Tile widget ────────────────────────────────────────
class _ExportOptionTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final Color        iconBg;
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;

  const _ExportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SU.sm,
          vertical:   SU.sm,
        ),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(SU.radiusLg),
          border:       Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              width:  SU.wp(0.115),
              height: SU.wp(0.115),
              decoration: BoxDecoration(
                color:        iconBg,
                borderRadius: BorderRadius.circular(SU.radius),
              ),
              child: Icon(icon, color: iconColor, size: SU.iconMd),
            ),
            SizedBox(width: SU.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   SU.textMd,
                      color:      Colors.black87,
                    ),
                  ),
                  SizedBox(height: SU.xs * 0.5),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: SU.textXs, color: Colors.black45),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: SU.textSm, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}