import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';
import '../widgets/kondo_app_bar.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';
import '../services/item_transaction_service.dart';
import 'barcode_scanner_screen.dart';

// ── Palette ──────────────────────────────────────────────
const _kBg        = Color(AppConstants.backgroundColorValue);
const _kCardBg    = Color(0xFFF2EADF);
const _kInnerCard = Color(0xFFE8DDD0);
const _kFieldBg   = Colors.white;
const _kBorder    = Colors.black26;
const _kPrimary   = Color(AppConstants.primaryColorValue);
const _kSuccess   = Color(AppConstants.successColorValue);
const _kOrange    = Color(AppConstants.lightOrangeValue);

class IssuedItemsScreen extends StatefulWidget {
  final String token;
  const IssuedItemsScreen({super.key, required this.token});

  @override
  State<IssuedItemsScreen> createState() => _IssuedItemsScreenState();
}

enum _IssuedFilter { myIssued, myHistory, globalHistory }

class _IssuedItemsScreenState extends State<IssuedItemsScreen> {
  late final ItemTransactionService _txService;
  late final ItemService            _itemService;

  _IssuedFilter _filter = _IssuedFilter.myIssued;
  List<ItemTransactionModel> _allData      = [];
  List<ItemTransactionModel> _filteredData = [];

  final Map<String, ItemModel> _itemCache = {};

  bool   _isLoading   = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _txService   = ItemTransactionService(token: widget.token);
    _itemService = ItemService(token: widget.token);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      List<ItemTransactionModel> data;
      switch (_filter) {
        case _IssuedFilter.myIssued:
          data = await _txService.getMyIssued();
          break;
        case _IssuedFilter.myHistory:
          data = await _txService.getMyHistory();
          break;
        case _IssuedFilter.globalHistory:
          data = await _txService.getGlobalHistory();
          break;
      }

      if (_filter == _IssuedFilter.myIssued) {
        final Map<String, ItemModel> cache = {};
        for (final tx in data) {
          if (!cache.containsKey(tx.itemId)) {
            try {
              final item = await _itemService.getItemById(tx.itemId);
              if (item != null) cache[tx.itemId] = item;
            } catch (_) {}
          }
        }
        if (mounted) {
          setState(() {
            _itemCache.clear();
            _itemCache.addAll(cache);
          });
        }
      }

      if (mounted) {
        setState(() {
          _allData      = data;
          _filteredData = data;
          _isLoading    = false;
        });
        _applySearch(_searchQuery);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('$e');
    }
  }

  void _applySearch(String q) {
    setState(() {
      _searchQuery  = q;
      _filteredData = _allData
          .where((tx) =>
              tx.itemName.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  String get _filterLabel {
    switch (_filter) {
      case _IssuedFilter.myIssued:      return 'My Issued';
      case _IssuedFilter.myHistory:     return 'My History';
      case _IssuedFilter.globalHistory: return 'Global History';
    }
  }

  void _showReturnModal(ItemTransactionModel tx) {
    showDialog(
      context: context,
      builder: (_) => _ScanReturnModal(
        itemName:  tx.itemName,
        service:   _txService,
        onSuccess: () {
          _showSuccess('Item returned successfully!');
          _loadData();
        },
        onError: _showError,
      ),
    );
  }

  void _showProofImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: Colors.red.shade600));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: _kSuccess));
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          KondoAppBar(
            title:    'Issued Items',
            showBack: true,
            showLogo: false,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(SU.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: SU.hp(0.015)),

                  // ── Header row ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _kPrimary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.output_outlined,
                                  color: Colors.white, size: SU.iconMd),
                            ),
                            SizedBox(width: SU.xs),
                            Flexible(
                              child: Text(
                                'Issued Items',
                                style: TextStyle(
                                  fontSize:   SU.textLg,
                                  fontWeight: FontWeight.w700,
                                  color:      Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: SU.xs),
                      // Search — constrained width
                      SizedBox(
                        width: SU.wp(0.26),
                        height: 36,
                        child: TextField(
                          onChanged: _applySearch,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search,
                                size: SU.iconSm,
                                color: Colors.black45),
                            filled:    true,
                            fillColor: _kOrange,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: SU.xs),
                      _FilterPill(
                        label:    _filterLabel,
                        onSelect: (f) {
                          setState(() => _filter = f);
                          _loadData();
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: SU.md),

                  // ── Content ───────────────────────────
                  _isLoading
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(SU.xl),
                            child: const CircularProgressIndicator(
                              color: _kPrimary,
                            ),
                          ),
                        )
                      : _filteredData.isEmpty
                          ? _EmptyState(filter: _filter)
                          : _filter == _IssuedFilter.myIssued
                              ? _buildIssuedCards()
                              : _filter == _IssuedFilter.myHistory
                                  ? _buildHistoryTable()
                                  : _buildGlobalTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── My Issued Cards ────────────────────────────────────
  Widget _buildIssuedCards() {
    return Column(
      children: _filteredData.map((tx) {
        final item = _itemCache[tx.itemId];
        return Padding(
          padding: EdgeInsets.only(bottom: SU.sm),
          child: _IssuedCard(
              tx: tx, item: item, onReturn: () => _showReturnModal(tx)),
        );
      }).toList(),
    );
  }

  // ── My History Table ───────────────────────────────────
  Widget _buildHistoryTable() {
    return Container(
      decoration: BoxDecoration(
        color: _kOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: SU.sm, horizontal: SU.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('Item Name',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
                // Fixed-width badge column
                SizedBox(
                  width: SU.wp(0.22),
                  child: Text('Type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Date',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
              ],
            ),
          ),
          ..._filteredData.asMap().entries.map((entry) =>
              _HistoryRow(
                tx:     entry.value,
                isLast: entry.key == _filteredData.length - 1,
              )),
        ],
      ),
    );
  }

  // ── Global History Table ───────────────────────────────
  Widget _buildGlobalTable() {
    return Container(
      decoration: BoxDecoration(
        color: _kOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: SU.sm, horizontal: SU.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('User',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textXs)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Item',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textXs)),
                ),
                // Fixed-width badge column — won't push siblings
                SizedBox(
                  width: SU.wp(0.18),
                  child: Text('Type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textXs)),
                ),
                SizedBox(
                  width: SU.wp(0.12),
                  child: Text('Proof',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textXs)),
                ),
              ],
            ),
          ),
          ..._filteredData.asMap().entries.map((entry) =>
              _GlobalRow(
                tx:          entry.value,
                isLast:      entry.key == _filteredData.length - 1,
                onViewProof: entry.value.photoProofUrl != null
                    ? () => _showProofImage(entry.value.photoProofUrl!)
                    : null,
              )),
        ],
      ),
    );
  }
}

// ── Issued Card ────────────────────────────────────────
class _IssuedCard extends StatelessWidget {
  final ItemTransactionModel tx;
  final ItemModel?           item;
  final VoidCallback         onReturn;

  const _IssuedCard(
      {required this.tx, required this.item, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    final fmt         = DateFormat('dd/MM/yy');
    final imageUrl    = item?.imageUrl    ?? '';
    final description = item?.description ?? '';

    return Container(
      padding: EdgeInsets.all(SU.md),
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(SU.radiusLg),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Center(
            child: Container(
              width: SU.wp(0.28),
              height: SU.wp(0.28),
              decoration: BoxDecoration(
                color:        _kInnerCard,
                borderRadius: BorderRadius.circular(SU.radiusLg),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(SU.radiusLg),
                      child: Image.network(imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              size:  SU.xl,
                              color: Colors.black26)))
                  : Icon(Icons.inventory_2_outlined,
                      size: SU.xl, color: Colors.black26),
            ),
          ),

          SizedBox(height: SU.md),

          _CardLabel('Item Name'),
          SizedBox(height: SU.xs),
          _ReadOnlyField(text: tx.itemName),

          SizedBox(height: SU.sm),

          _CardLabel('Item Description'),
          SizedBox(height: SU.xs),
          _ReadOnlyField(
              text:     description.isNotEmpty ? description : '—',
              maxLines: 4,
              hasIcon:  true),

          SizedBox(height: SU.sm),

          _CardLabel('Issued Date'),
          SizedBox(height: SU.xs),
          _ReadOnlyField(text: fmt.format(tx.checkOutDate.toLocal())),

          SizedBox(height: SU.md),

          SizedBox(
            width: 120, height: 40,
            child: ElevatedButton(
              onPressed: onReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                shape:           const StadiumBorder(),
                elevation:       0,
              ),
              child: Text('Return',
                  style: TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   SU.textMd)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History Row ────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final ItemTransactionModel tx;
  final bool                 isLast;

  const _HistoryRow({required this.tx, required this.isLast});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    final fmt = DateFormat('MM/dd/yy');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
            top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: SU.sm, horizontal: SU.sm),
      child: Row(
        children: [
          // Item name — takes remaining space, clips if too long
          Expanded(
            flex: 4,
            child: Text(
              tx.itemName,
              textAlign: TextAlign.center,
              overflow:  TextOverflow.ellipsis,
              maxLines:  1,
              style: TextStyle(fontSize: SU.textXs),
            ),
          ),
          // Badge — fixed width so it never overflows
          SizedBox(
            width: SU.wp(0.22),
            child: Center(
              child: _TxTypeBadge(type: tx.transactionType),
            ),
          ),
          // Date — takes remaining space
          Expanded(
            flex: 3,
            child: Text(
              fmt.format(tx.checkOutDate.toLocal()),
              textAlign: TextAlign.center,
              overflow:  TextOverflow.ellipsis,
              maxLines:  1,
              style: TextStyle(fontSize: SU.textXs),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Global Row ─────────────────────────────────────────
class _GlobalRow extends StatelessWidget {
  final ItemTransactionModel tx;
  final bool                 isLast;
  final VoidCallback?        onViewProof;

  const _GlobalRow(
      {required this.tx, required this.isLast, this.onViewProof});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
            top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: SU.sm, horizontal: SU.sm),
      child: Row(
        children: [
          // User — flexible, ellipsis
          Expanded(
            flex: 3,
            child: Text(
              tx.userName,
              textAlign: TextAlign.center,
              overflow:  TextOverflow.ellipsis,
              maxLines:  1,
              style: TextStyle(fontSize: SU.textXs),
            ),
          ),
          // Item — flexible, ellipsis
          Expanded(
            flex: 3,
            child: Text(
              tx.itemName,
              textAlign: TextAlign.center,
              overflow:  TextOverflow.ellipsis,
              maxLines:  1,
              style: TextStyle(fontSize: SU.textXs),
            ),
          ),
          // Badge — fixed width, never overflows
          SizedBox(
            width: SU.wp(0.18),
            child: Center(
              child: _TxTypeBadge(type: tx.transactionType),
            ),
          ),
          // Proof — fixed width
          SizedBox(
            width: SU.wp(0.12),
            child: Center(
              child: tx.photoProofUrl != null
                  ? GestureDetector(
                      onTap: onViewProof,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          tx.photoProofUrl!,
                          width: 32, height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported_outlined,
                              size:  SU.iconSm,
                              color: Colors.black38),
                        ),
                      ),
                    )
                  : Text('—',
                      style: TextStyle(
                          color:    Colors.black38,
                          fontSize: SU.textXs)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Type Badge ─────────────────────────────
// Uses FittedBox so the text scales down instead of overflowing
class _TxTypeBadge extends StatelessWidget {
  final String type;
  const _TxTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    Color color;
    switch (type) {
      case 'StockIn':
      case 'Returned':
        color = _kSuccess;
        break;
      case 'StockOut':
      case 'Issued':
        color = _kPrimary;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: SU.xs + 2, vertical: 3),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          type,
          style: TextStyle(
            color:      Colors.white,
            fontSize:   SU.textXs,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Scan Return Modal ──────────────────────────────────
class _ScanReturnModal extends StatefulWidget {
  final String                 itemName;
  final ItemTransactionService service;
  final VoidCallback           onSuccess;
  final void Function(String)  onError;

  const _ScanReturnModal({
    required this.itemName,
    required this.service,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ScanReturnModal> createState() => _ScanReturnModalState();
}

class _ScanReturnModalState extends State<_ScanReturnModal> {
  final _ctrl     = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    Navigator.pop(context);
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const BarcodeScannerScreen(hintLabel: 'Scan to Return')),
    );
    if (scanned == null || !mounted) return;
    setState(() {
      _ctrl.text = scanned;
      _isLoading = true;
    });
    try {
      await widget.service.returnItem(scanned);
      widget.onSuccess();
    } catch (e) {
      widget.onError('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
          horizontal: SU.wp(0.06),
          vertical:   SU.hp(0.32)),
      child: Container(
        padding: EdgeInsets.all(SU.md),
        decoration: BoxDecoration(
          color:        _kCardBg,
          borderRadius: BorderRadius.circular(SU.radiusXl),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color:        _kPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner,
                          color: Colors.white, size: 22),
                    ),
                    SizedBox(width: SU.sm),
                    Text('Scan Item Barcode',
                        style: TextStyle(
                            fontSize:   SU.textLg,
                            fontWeight: FontWeight.w700,
                            color:      Colors.black87)),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _kInnerCard,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        size: 16, color: Colors.black54),
                  ),
                ),
              ],
            ),
            SizedBox(height: SU.sm),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color:        _kFieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: _kBorder),
                    ),
                    child: Text(
                      _ctrl.text.isNotEmpty
                          ? _ctrl.text : 'Scan to Return',
                      style: TextStyle(
                        fontSize: SU.textMd,
                        color:    _ctrl.text.isNotEmpty
                            ? Colors.black87 : Colors.black38,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: SU.sm),
                ElevatedButton(
                  onPressed: _isLoading ? null : _scan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kSuccess,
                    shape:           const StadiumBorder(),
                    padding: EdgeInsets.symmetric(
                        horizontal: SU.lg, vertical: 15),
                    elevation: 0,
                  ),
                  child: Text('Scan',
                      style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textMd)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter Pill ────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String                       label;
  final void Function(_IssuedFilter) onSelect;

  const _FilterPill({required this.label, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return PopupMenuButton<_IssuedFilter>(
      onSelected: onSelect,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: _kCardBg,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: SU.sm, vertical: SU.xs + 2),
        decoration: BoxDecoration(
          color:        _kOrange,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize:   SU.textXs,
                      fontWeight: FontWeight.w600,
                      color:      Colors.black87)),
            ),
            SizedBox(width: SU.xs),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: Colors.black87),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
            value: _IssuedFilter.myIssued,
            child: Text('My Issued',
                style: TextStyle(fontSize: SU.textSm))),
        PopupMenuItem(
            value: _IssuedFilter.myHistory,
            child: Text('My History',
                style: TextStyle(fontSize: SU.textSm))),
        PopupMenuItem(
            value: _IssuedFilter.globalHistory,
            child: Text('Global History',
                style: TextStyle(fontSize: SU.textSm))),
      ],
    );
  }
}

// ── Empty State ────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _IssuedFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    final msgs = {
      _IssuedFilter.myIssued:      'No items currently issued to you.',
      _IssuedFilter.myHistory:     'No transaction history yet.',
      _IssuedFilter.globalHistory: 'No global transactions yet.',
    };
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SU.xl),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _kCardBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_outlined,
                  size: 30, color: Colors.black26),
            ),
            SizedBox(height: SU.sm),
            Text(msgs[filter] ?? 'No data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey, fontSize: SU.textMd)),
          ],
        ),
      ),
    );
  }
}

// ── Card helpers ───────────────────────────────────────
class _CardLabel extends StatelessWidget {
  final String text;
  const _CardLabel(this.text);

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize:   SU.textSm,
            color:      Colors.black87));
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String text;
  final int    maxLines;
  final bool   hasIcon;

  const _ReadOnlyField({
    required this.text,
    this.maxLines = 1,
    this.hasIcon  = false,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: SU.sm, horizontal: SU.sm),
      decoration: BoxDecoration(
        color:        _kFieldBg,
        borderRadius: BorderRadius.circular(SU.radius),
        border:       Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasIcon) ...[
            Icon(Icons.description_outlined,
                size: SU.iconSm, color: Colors.black38),
            SizedBox(width: SU.xs),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: SU.textSm),
            ),
          ),
        ],
      ),
    );
  }
}