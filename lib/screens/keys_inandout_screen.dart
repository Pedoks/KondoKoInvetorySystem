import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';
import '../models/key_transaction_model.dart';
import '../services/key_transaction_service.dart';
import '../widgets/kondo_app_bar.dart';
import '../widgets/export_bottom_sheet.dart';
import '../utils/export_helper.dart' as helper;
import 'barcode_scanner_screen.dart';

enum _TableFilter { checkedOut, history, globalHistory }

class KeysInAndOutScreen extends StatefulWidget {
  final String token;
  const KeysInAndOutScreen({super.key, required this.token});

  @override
  State<KeysInAndOutScreen> createState() => _KeysInAndOutScreenState();
}

class _KeysInAndOutScreenState extends State<KeysInAndOutScreen> {
  late final KeyTransactionService _service;

  final _topBarcodeCtrl = TextEditingController();

  _TableFilter _filter    = _TableFilter.checkedOut;
  List<KeyTransactionModel> _tableData = [];
  bool _isLoadingTable    = false;
  bool _isExporting       = false;

  @override
  void initState() {
    super.initState();
    _service = KeyTransactionService(token: widget.token);
    _loadTable();
  }

  @override
  void dispose() {
    _topBarcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTable() async {
    setState(() => _isLoadingTable = true);
    try {
      List<KeyTransactionModel> data;
      switch (_filter) {
        case _TableFilter.checkedOut:
          data = await _service.getMyActive();
          break;
        case _TableFilter.history:
          data = await _service.getMyHistory();
          break;
        case _TableFilter.globalHistory:
          data = await _service.getGlobalHistory();
          break;
      }
      setState(() { _tableData = data; _isLoadingTable = false; });
    } catch (e) {
      setState(() => _isLoadingTable = false);
      _showError('$e');
    }
  }

  Future<void> _scanTopBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(hintLabel: 'Scan key barcode'),
      ),
    );
    if (scanned == null || !mounted) return;
    setState(() => _topBarcodeCtrl.text = scanned);

    try {
      final result = await _service.scanBarcode(scanned);
      if (!mounted) return;
      if (result.isAvailable) {
        _showCheckOutConfirm(result);
      } else {
        _showCheckInConfirm(result);
      }
    } catch (e) {
      _showError('$e');
    }
  }

  // ── Rich Check-Out confirmation ────────────────────────
  void _showCheckOutConfirm(KeyScanResultModel result) {
    showDialog(
      context: context,
      builder: (_) => _RichKeyConfirmDialog(
        isCheckOut:  true,
        unit:        result.unit,
        keyType:     result.keyType,
        barcode:     result.barcode,
        checkedOutBy: null,
        checkOutDate: null,
        onConfirm: () async {
          Navigator.pop(context);
          await _doCheckOut(result.barcode);
        },
      ),
    );
  }

  // ── Rich Check-In confirmation ─────────────────────────
  void _showCheckInConfirm(KeyScanResultModel result) {
    // Find the transaction to get checkOutDate
    final existingTx = _tableData.where(
      (t) => t.barcode == result.barcode && t.isCheckedOut,
    ).firstOrNull;

    showDialog(
      context: context,
      builder: (_) => _RichKeyConfirmDialog(
        isCheckOut:   false,
        unit:         result.unit,
        keyType:      result.keyType,
        barcode:      result.barcode,
        checkedOutBy: result.checkedOutBy,
        checkOutDate: existingTx?.checkOutDate,
        onConfirm: () async {
          Navigator.pop(context);
          await _doCheckIn(result.barcode);
        },
      ),
    );
  }

  Future<void> _doCheckOut(String barcode) async {
    try {
      await _service.checkOut(barcode);
      _topBarcodeCtrl.clear();
      _showSuccess('Key checked out successfully!');
      _loadTable();
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _doCheckIn(String barcode) async {
    try {
      await _service.checkIn(barcode);
      _topBarcodeCtrl.clear();
      _showSuccess('Key checked in successfully!');
      _loadTable();
    } catch (e) {
      _showError('$e');
    }
  }

  void _showRowCheckInScan(KeyTransactionModel tx) async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(hintLabel: 'Scan key barcode to check in'),
      ),
    );
    if (scanned == null || !mounted) return;
    if (scanned != tx.barcode) {
      _showError('Barcode mismatch! Please scan the correct key.');
      return;
    }
    try {
      await _service.checkIn(scanned);
      _showSuccess('Key checked in successfully!');
      _loadTable();
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _handleExport() async {
    if (_filter != _TableFilter.globalHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switch to Global History to export transactions.')),
      );
      return;
    }
    if (_tableData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }

    // Show sheet — returns null if dismissed
    final result = await ExportBottomSheet.show(context);
    if (result == null || !mounted) return;

    // Apply date filter to transactions based on selected range
    final cutoff = result.range.cutoff;
    final filtered = cutoff == null
        ? _tableData
        : _tableData.where((t) => t.checkOutDate.isAfter(cutoff)).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No transactions found for ${result.range.label}.'),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      if (result.isExcel) {
        await helper.ExportHelper.exportTransactionsToExcel(context, filtered);
      } else {
        await helper.ExportHelper.exportTransactionsToPdf(context, filtered);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(AppConstants.successColorValue),
      ),
    );
  }

  String get _filterLabel {
    switch (_filter) {
      case _TableFilter.checkedOut:    return 'Checked-Out';
      case _TableFilter.history:       return 'History';
      case _TableFilter.globalHistory: return 'Global History';
    }
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColorValue),
      body: Column(
        children: [
          KondoAppBar(
            title:    'Keys In & Out',
            showBack: true,
            showLogo: false,
            showSettings: false,
            actions: [
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: _handleExport,
                  icon: Icon(
                    Icons.upload_file,
                    color: _filter == _TableFilter.globalHistory
                        ? Colors.white
                        : Colors.white54,
                    size: 22,
                  ),
                  tooltip: 'Export Global History',
                ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(SU.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: SU.hp(0.015)),

                  // ── Scan section ─────────────────────
                  _SectionHeader(icon: Icons.compare_arrows, label: 'Check-Out / In Key'),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.lightOrangeValue),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _topBarcodeCtrl,
                            readOnly: true,
                            decoration: _scanFieldDeco('Scan Barcode'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _GreenScanBtn(onTap: _scanTopBarcode),
                      ],
                    ),
                  ),

                  SizedBox(height: SU.hp(0.025)),

                  // ── Table section ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionHeader(icon: Icons.key, label: 'Checked-Out Keys'),
                      _FilterPill(
                        label:    _filterLabel,
                        onSelect: (f) { setState(() => _filter = f); _loadTable(); },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _isLoadingTable
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(SU.xl),
                            child: const CircularProgressIndicator(
                              color: Color(AppConstants.primaryColorValue),
                            ),
                          ),
                        )
                      : _tableData.isEmpty
                          ? _EmptyState(filter: _filter)
                          : _TransactionTable(
                              data:      _tableData,
                              filter:    _filter,
                              onCheckIn: _showRowCheckInScan,
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

// ═══════════════════════════════════════════════════════
//  RICH CONFIRM DIALOG
// ═══════════════════════════════════════════════════════
class _RichKeyConfirmDialog extends StatelessWidget {
  final bool isCheckOut;
  final String unit;
  final String keyType;
  final String barcode;
  final String? checkedOutBy;
  final DateTime? checkOutDate;
  final VoidCallback onConfirm;

  static final _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

  const _RichKeyConfirmDialog({
    required this.isCheckOut,
    required this.unit,
    required this.keyType,
    required this.barcode,
    this.checkedOutBy,
    this.checkOutDate,
    required this.onConfirm,
  });

  String? get _durationText {
    if (checkOutDate == null) return null;
    final diff = DateTime.now().difference(checkOutDate!);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h checked out';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m checked out';
    return '${diff.inMinutes}m checked out';
  }

  @override
  Widget build(BuildContext context) {
    final actionColor = isCheckOut
        ? const Color(AppConstants.primaryColorValue)
        : const Color(AppConstants.successColorValue);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2EADF),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Colored header ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: actionColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCheckOut ? Icons.logout : Icons.login,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isCheckOut ? 'Check Out Key' : 'Check In Key',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCheckOut
                        ? 'Key is currently available'
                        : 'Key is currently checked out',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // ── Info grid ───────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoRow(label: 'Unit', value: unit, icon: Icons.apartment),
                  const _InfoDivider(),
                  _InfoRow(label: 'Key Type', value: keyType, icon: Icons.vpn_key_outlined),
                  const _InfoDivider(),
                  _InfoRow(
                    label: 'Barcode',
                    value: barcode,
                    icon: Icons.qr_code,
                    isCode: true,
                  ),

                  // Check-In extras: who has it + duration
                  if (!isCheckOut) ...[
                    if (checkedOutBy != null) ...[
                      const _InfoDivider(),
                      _InfoRow(
                        label: 'Checked Out By',
                        value: checkedOutBy!,
                        icon: Icons.person_outline,
                      ),
                    ],
                    if (checkOutDate != null) ...[
                      const _InfoDivider(),
                      _InfoRow(
                        label: 'Checked Out At',
                        value: _dateFormat.format(checkOutDate!.toLocal()),
                        icon: Icons.schedule,
                      ),
                    ],
                    if (_durationText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.primaryColorValue).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time, size: 14,
                                color: Color(AppConstants.primaryColorValue)),
                            const SizedBox(width: 6),
                            Text(
                              _durationText!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(AppConstants.primaryColorValue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // ── Actions ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                        backgroundColor: Colors.black.withOpacity(0.06),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        isCheckOut ? 'Check Out' : 'Check In',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isCode;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(AppConstants.primaryColorValue)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontFamily: isCode ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Colors.black12);
}

// ── Section Header ─────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(AppConstants.primaryColorValue),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: SU.textLg,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ── Filter Pill ────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String label;
  final void Function(_TableFilter) onSelect;

  const _FilterPill({required this.label, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TableFilter>(
      onSelected: onSelect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(AppConstants.backgroundColorValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.black87),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _pill('Checked-Out',   _TableFilter.checkedOut),
        _pill('History',       _TableFilter.history),
        _pill('Global History',_TableFilter.globalHistory),
      ],
    );
  }

  PopupMenuItem<_TableFilter> _pill(String label, _TableFilter value) {
    return PopupMenuItem(
      value: value,
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Transaction Table ──────────────────────────────────
class _TransactionTable extends StatelessWidget {
  final List<KeyTransactionModel> data;
  final _TableFilter filter;
  final void Function(KeyTransactionModel) onCheckIn;

  const _TransactionTable({
    required this.data,
    required this.filter,
    required this.onCheckIn,
  });

  bool get _showGlobal => filter == _TableFilter.globalHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _showGlobal ? 'User' : 'Unit Name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _showGlobal ? 'Unit' : 'Check-Out',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    filter == _TableFilter.history
                        ? 'Check-In'
                        : filter == _TableFilter.globalHistory
                            ? 'Transaction Period'
                            : 'Action',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          ...data.asMap().entries.map((entry) {
            final isLast = entry.key == data.length - 1;
            final tx     = entry.value;
            return _TransactionRow(
              tx:       tx,
              isLast:   isLast,
              filter:   filter,
              onCheckIn: () => onCheckIn(tx),
            );
          }),
        ],
      ),
    );
  }
}

// ── Transaction Row ────────────────────────────────────
class _TransactionRow extends StatelessWidget {
  final KeyTransactionModel tx;
  final bool isLast;
  final _TableFilter filter;
  final VoidCallback onCheckIn;

  const _TransactionRow({
    required this.tx,
    required this.isLast,
    required this.filter,
    required this.onCheckIn,
  });

  static final _dateFormat = DateFormat('MM/dd/yy hh:mm a');

  String _fmt(DateTime date) => _dateFormat.format(date.toLocal());

  String _dur(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    String col1, col2;
    Widget col3;

    switch (filter) {
      case _TableFilter.checkedOut:
        col1 = tx.unit;
        col2 = _fmt(tx.checkOutDate);
        col3 = GestureDetector(
          onTap: onCheckIn,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(AppConstants.successColorValue),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Check-In',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        );
        break;

      case _TableFilter.history:
        col1 = tx.unit;
        col2 = _fmt(tx.checkOutDate);
        col3 = tx.checkInDate != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login, size: 12,
                          color: const Color(AppConstants.successColorValue)),
                      const SizedBox(width: 4),
                      Text(_fmt(tx.checkInDate!), style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.successColorValue).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _dur(tx.checkOutDate, tx.checkInDate!),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConstants.successColorValue),
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.primaryColorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('PENDING',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              );
        break;

      case _TableFilter.globalHistory:
        col1 = tx.userName;
        col2 = tx.unit;
        col3 = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(AppConstants.primaryColorValue),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, size: 10, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Text(_fmt(tx.checkOutDate),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
            if (tx.checkInDate != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(AppConstants.successColorValue),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.login, size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(_fmt(tx.checkInDate!),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.successColorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _dur(tx.checkOutDate, tx.checkInDate!),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConstants.successColorValue),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.primaryColorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 10),
                    SizedBox(width: 4),
                    Text('CURRENTLY OUT',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        );
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2,
              child: Text(col1,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2,
              child: Text(col2,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
          Expanded(flex: 3, child: Center(child: col3)),
        ],
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _TableFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msgs = {
      _TableFilter.checkedOut:    'No keys currently checked out.',
      _TableFilter.history:       'No transaction history yet.',
      _TableFilter.globalHistory: 'No global transactions yet.',
    };
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SU.xl),
        child: Text(msgs[filter] ?? 'No data.',
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────
class _GreenScanBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _GreenScanBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(AppConstants.successColorValue),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        elevation: 0,
      ),
      child: const Text('Scan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}

InputDecoration _scanFieldDeco(String hint) => InputDecoration(
  hintText:  hint,
  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
  filled:    true,
  fillColor: const Color(AppConstants.backgroundColorValue),
  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.black26),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.black26),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(
        color: Color(AppConstants.primaryColorValue), width: 1.5),
  ),
);