// lib/widgets/export_bottom_sheet.dart

import 'package:flutter/material.dart';
import '../utils/constants.dart';

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
  final bool isExcel; // true = Excel, false = PDF

  const ExportSheetResult({required this.range, required this.isExcel});
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
  ExportDateRange _selected = ExportDateRange.allTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: const BoxDecoration(
        color: Color(AppConstants.backgroundColorValue),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ───────────────────────────────
          const Center(
            child: Text(
              'Export Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Select a time range then choose format',
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ),

          const SizedBox(height: 20),

          // ── Time Range Label ─────────────────────
          const Text(
            'Time Range',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          // ── Range Chips ──────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ExportDateRange.values.map((range) {
              final isActive = _selected == range;
              return GestureDetector(
                onTap: () => setState(() => _selected = range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(AppConstants.primaryColorValue)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? const Color(AppConstants.primaryColorValue)
                          : Colors.black26,
                    ),
                  ),
                  child: Text(
                    range.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // ── Range hint text ──────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selected.cutoff != null
                ? Padding(
                    key: ValueKey(_selected),
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: Colors.black38),
                        const SizedBox(width: 6),
                        Text(
                          'Includes records from the last ${_selected.label.toLowerCase()}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black38),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('all'), height: 8),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.black12),
          const SizedBox(height: 16),

          // ── Format Label ─────────────────────────
          const Text(
            'Format',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // ── Excel tile ───────────────────────────
          _ExportOptionTile(
            icon:      Icons.table_chart_outlined,
            iconColor: const Color(0xFF1D6F42),
            iconBg:    const Color(0xFFE8F5E9),
            label:     'Export as Excel',
            subtitle:  'Best for sorting & filtering data',
            onTap: () => Navigator.pop(
              context,
              ExportSheetResult(range: _selected, isExcel: true),
            ),
          ),

          const SizedBox(height: 12),

          // ── PDF tile ─────────────────────────────
          _ExportOptionTile(
            icon:      Icons.picture_as_pdf_outlined,
            iconColor: const Color(0xFFD32F2F),
            iconBg:    const Color(0xFFFFEBEE),
            label:     'Export as PDF',
            subtitle:  'Best for printing & sharing',
            onTap: () => Navigator.pop(
              context,
              ExportSheetResult(range: _selected, isExcel: false),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile widget ────────────────────────────────────────
class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}