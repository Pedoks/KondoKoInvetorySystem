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

// ── Palette (matches KeyDashboard modal) ─────────────────
const _kModalBg     = Color(AppConstants.modalBgValue);
const _kModalCardBg = Color(AppConstants.modalCardBgValue);

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
        isCheckOut:   true,
        unit:         result.unit,
        keyType:      result.keyType,
        barcode:      result.barcode,
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

  // ── Row check-in: show confirmation first, then scan ──
  void _showRowCheckInConfirm(KeyTransactionModel tx) {
    showDialog(
      context: context,
      builder: (_) => _RichKeyConfirmDialog(
        isCheckOut:   false,
        unit:         tx.unit,
        keyType:      tx.keyType,
        barcode:      tx.barcode,
        checkedOutBy: tx.userName,
        checkOutDate: tx.checkOutDate,
        onConfirm: () async {
          Navigator.pop(context);
          await _doRowCheckInScan(tx);
        },
      ),
    );
  }

  Future<void> _doRowCheckInScan(KeyTransactionModel tx) async {
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

    final result = await ExportBottomSheet.show(context);
    if (result == null || !mounted) return;

    final cutoff = result.range.cutoff;
    final filtered = cutoff == null
        ? _tableData
        : _tableData.where((t) => t.checkOutDate.isAfter(cutoff)).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No transactions found for ${result.range.label}.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
if (result.isExcel) {
  await helper.ExportHelper.exportTransactionsToExcel(
    context,
    filtered,
    download: result.isDownload,
  );
} else {
  await helper.ExportHelper.exportTransactionsToPdf(
    context,
    filtered,
    download: result.isDownload,
  );
}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(AppConstants.errorColorValue)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(AppConstants.errorColorValue)),
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
                Padding(
                  padding: EdgeInsets.only(right: SU.md),
                  child: SizedBox(
                    width: SU.iconSm,
                    height: SU.iconSm,
                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                    size: SU.iconMd,
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
                  SizedBox(height: SU.sm),

                  Container(
                    padding: EdgeInsets.all(SU.md),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.lightOrangeValue),
                      borderRadius: BorderRadius.circular(SU.radiusLg),
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
                        SizedBox(width: SU.sm),
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

                  SizedBox(height: SU.sm),

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
                              onCheckIn: _showRowCheckInConfirm,
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
//  RICH CONFIRM DIALOG — Beige style
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

  Color get _accentColor => isCheckOut
      ? const Color(AppConstants.primaryColorValue)
      : const Color(AppConstants.successColorValue);

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: SU.md,
        vertical:   SU.hp(0.1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _kModalBg,
          borderRadius: BorderRadius.circular(SU.radiusXl),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Beige header (matches KeyDashboard modal) ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: SU.md,
                vertical:   SU.sm + 4,
              ),
              decoration: BoxDecoration(
                color: _kModalCardBg,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(SU.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width:  SU.wp(0.10),
                    height: SU.wp(0.10),
                    decoration: BoxDecoration(
                      color:        _accentColor,
                      borderRadius: BorderRadius.circular(SU.radius - 2),
                    ),
                    child: Icon(
                      isCheckOut ? Icons.logout : Icons.login,
                      color: Colors.white,
                      size: SU.iconSm,
                    ),
                  ),
                  SizedBox(width: SU.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCheckOut ? 'Check Out Key' : 'Check In Key',
                        style: TextStyle(
                          fontSize:   SU.textLg,
                          fontWeight: FontWeight.w700,
                          color:      Colors.black87,
                        ),
                      ),
                      Text(
                        isCheckOut
                            ? 'Key is currently available'
                            : 'Key is currently checked out',
                        style: TextStyle(
                          fontSize: SU.textXs,
                          color:    Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Info grid ───────────────────────────
            Padding(
              padding: EdgeInsets.all(SU.md),
              child: Column(
                children: [
                  _InfoRow(label: 'Unit',     value: unit,    icon: Icons.apartment),
                  const _InfoDivider(),
                  _InfoRow(label: 'Key Type', value: keyType, icon: Icons.vpn_key_outlined),
                  const _InfoDivider(),
                  _InfoRow(
                    label:  'Barcode',
                    value:  barcode,
                    icon:   Icons.qr_code,
                    isCode: true,
                  ),

                  if (!isCheckOut) ...[
                    if (checkedOutBy != null) ...[
                      const _InfoDivider(),
                      _InfoRow(
                        label: 'Checked Out By',
                        value: checkedOutBy!,
                        icon:  Icons.person_outline,
                      ),
                    ],
                    if (checkOutDate != null) ...[
                      const _InfoDivider(),
                      _InfoRow(
                        label: 'Checked Out At',
                        value: _dateFormat.format(checkOutDate!.toLocal()),
                        icon:  Icons.schedule,
                      ),
                    ],
                    if (_durationText != null) ...[
                      SizedBox(height: SU.sm),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: SU.sm,
                          vertical:   SU.xs,
                        ),
                        decoration: BoxDecoration(
                          color:        _accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(SU.radius),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time,
                                size:  SU.textSm,
                                color: _accentColor),
                            SizedBox(width: SU.xs),
                            Text(
                              _durationText!,
                              style: TextStyle(
                                fontSize:   SU.textXs,
                                fontWeight: FontWeight.w600,
                                color:      _accentColor,
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
              padding: EdgeInsets.fromLTRB(SU.md, 0, SU.md, SU.md),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: SU.hp(0.058),
                        decoration: BoxDecoration(
                          color:        _kModalCardBg,
                          borderRadius: BorderRadius.circular(30),
                          border:       Border.all(color: Colors.black26),
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
                  Expanded(
                    child: GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        height: SU.hp(0.058),
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
                            isCheckOut ? 'Check Out' : 'Check In',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final bool    isCode;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SU.xs + 2),
      child: Row(
        children: [
          Icon(icon, size: SU.iconSm, color: const Color(AppConstants.primaryColorValue)),
          SizedBox(width: SU.sm),
          Text(
            label,
            style: TextStyle(
              fontSize:   SU.textXs,
              color:      Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize:   SU.textSm,
              fontWeight: FontWeight.w600,
              color:      Colors.black87,
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
  final String   label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Row(
      children: [
        Container(
          width:  SU.wp(0.09),
          height: SU.wp(0.09),
          decoration: BoxDecoration(
            color:        const Color(AppConstants.primaryColorValue),
            borderRadius: BorderRadius.circular(SU.radius - 2),
          ),
          child: Icon(icon, color: Colors.white, size: SU.iconSm),
        ),
        SizedBox(width: SU.sm),
        Text(
          label,
          style: TextStyle(
            fontSize:   SU.textLg,
            fontWeight: FontWeight.w700,
            color:      Colors.black87,
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
    SU.init(context);
    return PopupMenuButton<_TableFilter>(
      onSelected: onSelect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SU.radiusLg)),
      color: const Color(AppConstants.backgroundColorValue),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: SU.sm, vertical: SU.xs),
        decoration: BoxDecoration(
          color:        const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(SU.radiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize:   SU.textSm,
                fontWeight: FontWeight.w600,
                color:      Colors.black87,
              ),
            ),
            SizedBox(width: SU.xs),
            Icon(Icons.keyboard_arrow_down_rounded, size: SU.iconSm, color: Colors.black87),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _pill('Checked-Out',    _TableFilter.checkedOut),
        _pill('History',        _TableFilter.history),
        _pill('Global History', _TableFilter.globalHistory),
      ],
    );
  }

  PopupMenuItem<_TableFilter> _pill(String label, _TableFilter value) {
    return PopupMenuItem(
      value: value,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Transaction Table ──────────────────────────────────
class _TransactionTable extends StatelessWidget {
  final List<KeyTransactionModel> data;
  final _TableFilter              filter;
  final void Function(KeyTransactionModel) onCheckIn;

  const _TransactionTable({
    required this.data,
    required this.filter,
    required this.onCheckIn,
  });

  // ── Flex ratios per filter ────────────────────────────
  // checkedOut:    Unit/Key | Check-Out date | Action button
  // history:       Unit/Key | Check-Out date | Check-In date
  // globalHistory: User     | Unit/Key       | Transaction Period (needs most space)
  int get _col1Flex => filter == _TableFilter.globalHistory ? 2 : 3;
  int get _col2Flex => 3;
  int get _col3Flex => filter == _TableFilter.globalHistory ? 4 : 3;

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      decoration: BoxDecoration(
        color:        const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(SU.radius + 4),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical:   SU.sm,
              horizontal: SU.md,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: _col1Flex,
                  child: Text(
                    filter == _TableFilter.globalHistory ? 'User' : 'Unit / Key',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   SU.textSm,
                    ),
                  ),
                ),
                Expanded(
                  flex: _col2Flex,
                  child: Text(
                    filter == _TableFilter.globalHistory ? 'Unit / Key' : 'Check-Out',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   SU.textSm,
                    ),
                  ),
                ),
                Expanded(
                  flex: _col3Flex,
                  child: Text(
                    filter == _TableFilter.history
                        ? 'Check-In'
                        : filter == _TableFilter.globalHistory
                            ? 'Transaction Period'
                            : 'Action',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   SU.textSm,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...data.asMap().entries.map((entry) {
            final isLast = entry.key == data.length - 1;
            final tx     = entry.value;
            return _TransactionRow(
              tx:        tx,
              isLast:    isLast,
              filter:    filter,
              col1Flex:  _col1Flex,
              col2Flex:  _col2Flex,
              col3Flex:  _col3Flex,
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
  final bool         isLast;
  final _TableFilter filter;
  final int          col1Flex;
  final int          col2Flex;
  final int          col3Flex;
  final VoidCallback onCheckIn;

  const _TransactionRow({
    required this.tx,
    required this.isLast,
    required this.filter,
    required this.col1Flex,
    required this.col2Flex,
    required this.col3Flex,
    required this.onCheckIn,
  });

  // ── Shorter date: MM/dd h:mma  e.g. "05/05 6:14PM" ──
  static final _dateFormat = DateFormat('MM/dd h:mma');

  String _fmt(DateTime date) => _dateFormat.format(date.toLocal());

  String _dur(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays > 0)    return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0)   return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  // ── Unit + KeyType subtitle cell ─────────────────────
  Widget _unitCell(String unit, String keyType) {
    return Builder(builder: (context) {
      SU.init(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            unit,
            textAlign: TextAlign.center,
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
            style: TextStyle(
              fontSize:   SU.textSm,
              fontWeight: FontWeight.w600,
              color:      Colors.black87,
            ),
          ),
          if (keyType.isNotEmpty) ...[
            SizedBox(height: SU.xs * 0.5),
            Text(
              keyType,
              textAlign: TextAlign.center,
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SU.textXs,
                color:    Colors.black45,
              ),
            ),
          ],
        ],
      );
    });
  }

  // ── Date line: small icon dot + date text ─────────────
  Widget _dateLine(BuildContext context, IconData icon, Color color, DateTime date) {
    SU.init(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width:  SU.textXs + 2,
          height: SU.textXs + 2,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: SU.textXs * 0.8, color: Colors.white),
        ),
        SizedBox(width: SU.xs * 0.6),
        Flexible(
          child: Text(
            _fmt(date),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: SU.textXs, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // ── Duration badge ────────────────────────────────────
  Widget _durBadge(BuildContext context, DateTime start, DateTime end, Color color) {
    SU.init(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SU.xs, vertical: SU.xs * 0.4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(SU.xs),
      ),
      child: Text(
        _dur(start, end),
        style: TextStyle(
          fontSize:   SU.textXs * 0.85,
          fontWeight: FontWeight.w600,
          color:      color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    Widget col1;
    Widget col2;
    Widget col3;

    const primaryColor = Color(AppConstants.primaryColorValue);
    const successColor = Color(AppConstants.successColorValue);

    switch (filter) {
      // ── Checked-Out tab ──────────────────────────────
      case _TableFilter.checkedOut:
        col1 = _unitCell(tx.unit, tx.keyType);
        col2 = Text(
          _fmt(tx.checkOutDate),
          textAlign: TextAlign.center,
          overflow:  TextOverflow.ellipsis,
          style: TextStyle(fontSize: SU.textXs),
        );
        col3 = GestureDetector(
          onTap: onCheckIn,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: SU.sm, vertical: SU.xs),
            decoration: BoxDecoration(
              color:        successColor,
              borderRadius: BorderRadius.circular(SU.radiusLg),
            ),
            child: Text(
              'Check-In',
              style: TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w600,
                fontSize:   SU.textXs,
              ),
            ),
          ),
        );
        break;

      // ── History tab ──────────────────────────────────
      case _TableFilter.history:
        col1 = _unitCell(tx.unit, tx.keyType);
        col2 = Text(
          _fmt(tx.checkOutDate),
          textAlign: TextAlign.center,
          overflow:  TextOverflow.ellipsis,
          style: TextStyle(fontSize: SU.textXs),
        );
        col3 = tx.checkInDate != null
            ? Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dateLine(context, Icons.login, successColor, tx.checkInDate!),
                  SizedBox(height: SU.xs * 0.5),
                  _durBadge(context, tx.checkOutDate, tx.checkInDate!, successColor),
                ],
              )
            : Container(
                padding: EdgeInsets.symmetric(horizontal: SU.xs, vertical: SU.xs),
                decoration: BoxDecoration(
                  color:        primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(SU.xs),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize:   SU.textXs * 0.85,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
        break;

      // ── Global History tab ───────────────────────────
      case _TableFilter.globalHistory:
        col1 = Text(
          tx.userName,
          textAlign: TextAlign.center,
          maxLines:  2,
          overflow:  TextOverflow.ellipsis,
          style: TextStyle(fontSize: SU.textSm),
        );
        col2 = _unitCell(tx.unit, tx.keyType);
        col3 = Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Check-out line
            _dateLine(context, Icons.logout, primaryColor, tx.checkOutDate),

            if (tx.checkInDate != null) ...[
              SizedBox(height: SU.xs * 0.6),
              // Check-in line
              _dateLine(context, Icons.login, successColor, tx.checkInDate!),
              SizedBox(height: SU.xs * 0.4),
              // Duration badge
              _durBadge(context, tx.checkOutDate, tx.checkInDate!, successColor),
            ] else ...[
              SizedBox(height: SU.xs * 0.6),
              // Currently out badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SU.xs,
                  vertical:   SU.xs * 0.4,
                ),
                decoration: BoxDecoration(
                  color:        primaryColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(SU.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: SU.textXs * 0.9),
                    SizedBox(width: SU.xs * 0.4),
                    Text(
                      'OUT',
                      style: TextStyle(
                        fontSize:   SU.textXs * 0.85,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
            ? BorderRadius.vertical(bottom: Radius.circular(SU.radius + 4))
            : BorderRadius.zero,
        border: const Border(top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(vertical: SU.sm, horizontal: SU.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: col1Flex, child: Center(child: col1)),
          Expanded(flex: col2Flex, child: Center(child: col2)),
          Expanded(flex: col3Flex, child: col3),   // left-aligned for dates
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
    SU.init(context);
    final msgs = {
      _TableFilter.checkedOut:    'No keys currently checked out.',
      _TableFilter.history:       'No transaction history yet.',
      _TableFilter.globalHistory: 'No global transactions yet.',
    };
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SU.xl),
        child: Text(
          msgs[filter] ?? 'No data.',
          style: TextStyle(color: Colors.grey, fontSize: SU.textSm),
        ),
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
    SU.init(context);
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(AppConstants.successColorValue),
        shape:           const StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: SU.md,
          vertical:   SU.sm,
        ),
        elevation: 0,
      ),
      child: Text(
        'Scan',
        style: TextStyle(
          color:      Colors.white,
          fontWeight: FontWeight.w700,
          fontSize:   SU.textMd,
        ),
      ),
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