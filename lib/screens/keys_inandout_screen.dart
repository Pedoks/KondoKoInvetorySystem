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

  // ── Row Check-In button → direct scan for security ──────────────────
  void _showRowCheckInScan(KeyTransactionModel tx) async {
    // Force re-scan for security
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          hintLabel: 'Scan key barcode to check in',
        ),
      ),
    );
    
    if (scanned == null || !mounted) return;
    
    // Verify the scanned barcode matches the transaction
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
                  flex: 2,
                  child: Text(
                    _showGlobal ? 'User' : 'Unit Name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _showGlobal ? 'Unit' : 'Check-Out',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
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

  String _formatDate(DateTime date) {
    return DateFormat('MM/dd/yy hh:mm a').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    String col1, col2;
    Widget col3;

    switch (filter) {
      case _TableFilter.checkedOut:
        col1 = tx.unit;
        col2 = _formatDate(tx.checkOutDate);
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
        col2 = _formatDate(tx.checkOutDate);
        if (tx.checkInDate != null) {
          col3 = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.login, size: 12, color: const Color(AppConstants.successColorValue)),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(tx.checkInDate!),
                    style: const TextStyle(fontSize: 11),
                  ),
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
                  _calculateDuration(tx.checkOutDate, tx.checkInDate!),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.successColorValue),
                  ),
                ),
              ),
            ],
          );
        } else {
          col3 = Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(AppConstants.primaryColorValue).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PENDING',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          );
        }
        break;
        
      case _TableFilter.globalHistory:
        col1 = tx.userName;
        col2 = tx.unit;
        // Timeline style showing both dates
        col3 = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.primaryColorValue),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, size: 10, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(tx.checkOutDate),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (tx.checkInDate != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.successColorValue),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.login, size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(tx.checkInDate!),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
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
                  _calculateDuration(tx.checkOutDate, tx.checkInDate!),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.successColorValue),
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
                    Text(
                      'CURRENTLY OUT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
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
            flex: 2,
            child: Text(col1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
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

  String _calculateDuration(DateTime start, DateTime end) {
    final difference = end.difference(start);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours.remainder(24)}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inSeconds}s';
    }
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