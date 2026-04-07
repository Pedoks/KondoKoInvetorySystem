import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/key_transaction_model.dart';
import '../services/key_transaction_service.dart';
import 'barcode_scanner_screen.dart';

class KeysInAndOutScreen extends StatefulWidget {
  final String token;

  const KeysInAndOutScreen({super.key, required this.token});

  @override
  State<KeysInAndOutScreen> createState() => _KeysInAndOutScreenState();
}

// Dropdown filter options
enum _TableFilter { checkedOut, history, globalHistory }

class _KeysInAndOutScreenState extends State<KeysInAndOutScreen> {
  late final KeyTransactionService _service;

  // Top scan barcode field
  final _topBarcodeCtrl = TextEditingController();

  // Table data & filter
  _TableFilter _filter        = _TableFilter.checkedOut;
  List<KeyTransactionModel> _tableData = [];
  bool _isLoadingTable        = false;

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

  // ── Load table based on filter ─────────────────────────
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
      setState(() {
        _tableData      = data;
        _isLoadingTable = false;
      });
    } catch (e) {
      setState(() => _isLoadingTable = false);
      _showError('$e');
    }
  }

  // ── Top section: scan to check out or in ──────────────
  Future<void> _scanTopBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          hintLabel: 'Scan key barcode',
        ),
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

  // ── Check-Out confirm dialog ───────────────────────────
  void _showCheckOutConfirm(KeyScanResultModel result) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title:   'Check Out Key',
        message: 'Are you sure you want to check out key for\n'
                 '"${result.unit}" (${result.keyType})?',
        confirmLabel: 'Check Out',
        confirmColor: const Color(AppConstants.primaryColorValue),
        onConfirm: () async {
          Navigator.pop(context);
          await _doCheckOut(result.barcode);
        },
      ),
    );
  }

  // ── Check-In confirm dialog ────────────────────────────
  void _showCheckInConfirm(KeyScanResultModel result) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title:   'Check In Key',
        message: 'Key "${result.unit}" is currently checked out'
                 '${result.checkedOutBy != null ? " by ${result.checkedOutBy}" : ""}.\n\n'
                 'Are you sure you want to check it in?',
        confirmLabel: 'Check In',
        confirmColor: const Color(AppConstants.successColorValue),
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

  // ── Row Check-In button → scan modal ──────────────────
  void _showRowCheckInModal(KeyTransactionModel tx) {
    showDialog(
      context: context,
      builder: (_) => _ScanCheckInModal(
        unit:    tx.unit,
        service: _service,
        onSuccess: () {
          _showSuccess('Key checked in successfully!');
          _loadTable();
        },
        onError: _showError,
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
      ),
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

  // ── Filter label ───────────────────────────────────────
  String get _filterLabel {
    switch (_filter) {
      case _TableFilter.checkedOut:    return 'Checked-Out';
      case _TableFilter.history:       return 'History';
      case _TableFilter.globalHistory: return 'Global History';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final top  = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColorValue),
      body: Column(
        children: [
          // ── Orange App Bar ──────────────────────────
          Container(
            color: const Color(AppConstants.primaryColorValue),
            padding: EdgeInsets.only(
                top: top + 12, bottom: 16, left: 4, right: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Keys In & Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(size.width * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.015),

                  // ── Check-Out/In Section ─────────────
                  _SectionHeader(
                    icon:  Icons.compare_arrows,
                    label: 'Check- Out/In  Key',
                  ),

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
                            readOnly:   true,
                            decoration: _scanFieldDeco('Scan Barcode'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _GreenScanBtn(onTap: _scanTopBarcode),
                      ],
                    ),
                  ),

                  SizedBox(height: size.height * 0.025),

                  // ── Checked-Out Keys Section ──────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionHeader(
                        icon:  Icons.key,
                        label: 'Checked-Out Keys',
                      ),
                      // Filter dropdown pill
                      _FilterPill(
                        label:    _filterLabel,
                        onSelect: (filter) {
                          setState(() => _filter = filter);
                          _loadTable();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Table ────────────────────────────
                  _isLoadingTable
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              color: Color(AppConstants.primaryColorValue),
                            ),
                          ),
                        )
                      : _tableData.isEmpty
                          ? _EmptyState(filter: _filter)
                          : _TransactionTable(
                              data:     _tableData,
                              filter:   _filter,
                              onCheckIn: _showRowCheckInModal,
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

// ── Section Header ─────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ── Filter Pill Dropdown ───────────────────────────────
class _FilterPill extends StatelessWidget {
  final String                        label;
  final void Function(_TableFilter)   onSelect;

  const _FilterPill({required this.label, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TableFilter>(
      onSelected: onSelect,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: const Color(AppConstants.backgroundColorValue),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Colors.black87),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _pillItem('Checked-Out',   _TableFilter.checkedOut),
        _pillItem('History',       _TableFilter.history),
        _pillItem('Global History',_TableFilter.globalHistory),
      ],
    );
  }

  PopupMenuItem<_TableFilter> _pillItem(
      String label, _TableFilter value) {
    return PopupMenuItem(
      value: value,
      child: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Transaction Table ──────────────────────────────────
class _TransactionTable extends StatelessWidget {
  final List<KeyTransactionModel>            data;
  final _TableFilter                         filter;
  final void Function(KeyTransactionModel)   onCheckIn;

  const _TransactionTable({
    required this.data,
    required this.filter,
    required this.onCheckIn,
  });

  bool get _showCheckIn => filter == _TableFilter.checkedOut;
  bool get _showGlobal  => filter == _TableFilter.globalHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    _showGlobal ? 'User' : 'Unit Name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _showGlobal ? 'Unit' : 'Time Out Date',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    filter == _TableFilter.history
                        ? 'Check-In Date'
                        : filter == _TableFilter.globalHistory
                            ? 'Status'
                            : 'Action',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          ...data.asMap().entries.map((entry) {
            final isLast = entry.key == data.length - 1;
            final tx     = entry.value;
            return _TransactionRow(
              tx:          tx,
              isLast:      isLast,
              filter:      filter,
              onCheckIn:   () => onCheckIn(tx),
            );
          }),
        ],
      ),
    );
  }
}

// ── Transaction Row ────────────────────────────────────
class _TransactionRow extends StatelessWidget {
  final KeyTransactionModel            tx;
  final bool                           isLast;
  final _TableFilter                   filter;
  final VoidCallback                   onCheckIn;

  const _TransactionRow({
    required this.tx,
    required this.isLast,
    required this.filter,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd/yy');

    String col1, col2;
    Widget col3;

    switch (filter) {
      case _TableFilter.checkedOut:
        col1 = tx.unit;
        col2 = fmt.format(tx.checkOutDate.toLocal());
        col3 = GestureDetector(
          onTap: onCheckIn,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(AppConstants.successColorValue),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Check-In',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        );
        break;
      case _TableFilter.history:
        col1 = tx.unit;
        col2 = fmt.format(tx.checkOutDate.toLocal());
        col3 = Text(
          tx.checkInDate != null
              ? fmt.format(tx.checkInDate!.toLocal())
              : '—',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        );
        break;
      case _TableFilter.globalHistory:
        col1 = tx.userName;
        col2 = tx.unit;
        col3 = Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tx.isCheckedOut
                ? const Color(AppConstants.primaryColorValue)
                    .withOpacity(0.15)
                : const Color(AppConstants.successColorValue)
                    .withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tx.isCheckedOut ? 'Out' : 'In',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tx.isCheckedOut
                  ? const Color(AppConstants.primaryColorValue)
                  : const Color(AppConstants.successColorValue),
            ),
          ),
        );
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
          top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(col1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(col2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Center(child: col3),
          ),
        ],
      ),
    );
  }
}

// ── Scan Check-In Modal (Image 3) ──────────────────────
class _ScanCheckInModal extends StatefulWidget {
  final String                unit;
  final KeyTransactionService service;
  final VoidCallback          onSuccess;
  final void Function(String) onError;

  const _ScanCheckInModal({
    required this.unit,
    required this.service,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ScanCheckInModal> createState() => _ScanCheckInModalState();
}

class _ScanCheckInModalState extends State<_ScanCheckInModal> {
  final _ctrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    Navigator.pop(context); // close modal first
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          hintLabel: 'Scan to Check-In',
        ),
      ),
    );
    if (scanned == null || !mounted) return;

    setState(() {
      _ctrl.text  = scanned;
      _isLoading  = true;
    });

    try {
      await widget.service.checkIn(scanned);
      widget.onSuccess();
    } catch (e) {
      widget.onError('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.06,
        vertical:   size.height * 0.3,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(
                            AppConstants.primaryColorValue),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Scan Key Barcode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close,
                      size: 22, color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scan row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    readOnly:   true,
                    decoration:
                        _scanFieldDeco('Scan to Check-In'),
                  ),
                ),
                const SizedBox(width: 10),
                _GreenScanBtn(onTap: _scan),
              ],
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(32),
        child: Text(
          msgs[filter] ?? 'No data.',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }
}

// ── Confirm Dialog ─────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String       title;
  final String       message;
  final String       confirmLabel;
  final Color        confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      backgroundColor:
          const Color(AppConstants.backgroundColorValue),
      title: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
        backgroundColor:
            const Color(AppConstants.successColorValue),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
            horizontal: 22, vertical: 15),
        elevation: 0,
      ),
      child: const Text(
        'Scan',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
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
  contentPadding: const EdgeInsets.symmetric(
      vertical: 14, horizontal: 16),
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
      color: Color(AppConstants.primaryColorValue),
      width: 1.5,
    ),
  ),
);