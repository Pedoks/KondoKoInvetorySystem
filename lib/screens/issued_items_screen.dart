import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';
import '../widgets/kondo_app_bar.dart';
import '../widgets/export_bottom_sheet.dart';               
import '../utils/export_helper.dart' as helper;            
import '../models/item_model.dart';
import '../services/item_service.dart';
import '../services/item_transaction_service.dart';
import 'barcode_scanner_screen.dart';

// ── Palette ──────────────────────────────────────────────
const _kBg        = Color(AppConstants.backgroundColorValue);
const _kCardBg    = Color(AppConstants.modalBgValue);
const _kInnerCard = Color(AppConstants.modalCardBgValue);
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
enum _GlobalFilter { all, consumable, nonConsumable }

class _IssuedItemsScreenState extends State<IssuedItemsScreen> {
  late final ItemTransactionService _txService;
  late final ItemService            _itemService;

  _IssuedFilter _filter       = _IssuedFilter.myIssued;
  _GlobalFilter _globalFilter = _GlobalFilter.all;

  List<ItemTransactionModel> _allData      = [];
  List<ItemTransactionModel> _filteredData = [];

  final Map<String, ItemModel> _itemCache = {};

  bool   _isLoading   = false;
  bool   _isExporting = false;   
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
          _allData   = data;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('$e');
    }
  }

  void _applyFilters() {
    List<ItemTransactionModel> result = _allData;

    if (_searchQuery.isNotEmpty) {
      result = result
          .where((tx) =>
              tx.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              tx.userName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_filter == _IssuedFilter.globalHistory) {
      switch (_globalFilter) {
        case _GlobalFilter.consumable:
          result = result
              .where((tx) =>
                  tx.transactionType == 'StockIn' ||
                  tx.transactionType == 'StockOut')
              .toList();
          break;
        case _GlobalFilter.nonConsumable:
          result = result
              .where((tx) =>
                  tx.transactionType == 'Issued' ||
                  tx.transactionType == 'Returned')
              .toList();
          break;
        case _GlobalFilter.all:
          break;
      }
    }

    setState(() => _filteredData = result);
  }

  void _onSearch(String q) {
    _searchQuery = q;
    _applyFilters();
  }

  String get _filterLabel {
    switch (_filter) {
      case _IssuedFilter.myIssued:      return 'My Issued';
      case _IssuedFilter.myHistory:     return 'My History';
      case _IssuedFilter.globalHistory: return 'Global History';
    }
  }

  // ── NEW: Export handler ──────────────────────────────
  Future<void> _handleExport() async {
    // Only export from Global History tab — same restriction as KeysInAndOut
    if (_filter != _IssuedFilter.globalHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Switch to Global History to export transactions.'),
        ),
      );
      return;
    }

    if (_allData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }

    final result = await ExportBottomSheet.show(context);
    if (result == null || !mounted) return;

    // ── Date-range filter on checkOutDate ──────────────
    final cutoff = result.range.cutoff;

    // ── Sub-filter: read the currently active _globalFilter pill ──
    // _allData is the full globalHistory list (no search applied).
    // We start from _allData so the export is not affected by the
    // current search query — consistent with Key module behaviour.
    List<ItemTransactionModel> base = cutoff == null
        ? _allData
        : _allData
            .where((t) => t.checkOutDate.isAfter(cutoff))
            .toList();

    // Apply the active global sub-filter
    List<ItemTransactionModel> toExport;
    switch (_globalFilter) {
      case _GlobalFilter.consumable:
        toExport = base
            .where((t) =>
                t.transactionType == 'StockIn' ||
                t.transactionType == 'StockOut')
            .toList();
        break;
      case _GlobalFilter.nonConsumable:
        toExport = base
            .where((t) =>
                t.transactionType == 'Issued' ||
                t.transactionType == 'Returned')
            .toList();
        break;
      case _GlobalFilter.all:
        toExport = base;
        break;
    }

    if (toExport.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No transactions found for ${result.range.label}.')),
        );
      }
      return;
    }

    setState(() => _isExporting = true);
    try {
      if (result.isExcel) {
        await helper.ExportHelper.exportItemTransactionsToExcel(
          context, toExport,
          download: result.isDownload,
        );
      } else {
        await helper.ExportHelper.exportItemTransactionsToPdf(
          context, toExport,
          download: result.isDownload,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Export failed: $e'),
          backgroundColor: Colors.red.shade600,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
  // ── END NEW ──────────────────────────────────────────

  void _showReturnModal(ItemTransactionModel tx, String expectedBarcode) {
    showDialog(
      context: context,
      builder: (_) => _ScanReturnModal(
        itemName:        tx.itemName,
        expectedBarcode: expectedBarcode,
        service:         _txService,
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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: _kSuccess));
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── App bar with export button ─────────────
          KondoAppBar(
            title:        'Issued Items',
            showBack:     true,
            showLogo:     false,
            showSettings: false,
            actions: [                                      
              if (_isExporting)
                Padding(
                  padding: EdgeInsets.only(right: SU.md),
                  child: SizedBox(
                    width:  SU.iconSm,
                    height: SU.iconSm,
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: _handleExport,
                  icon: Icon(
                    Icons.upload_file,
                    // Dim icon when not on globalHistory tab
                    // (same UX as KeysInAndOut screen)
                    color: _filter == _IssuedFilter.globalHistory
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

                  // ── Header row ──────────────────────
                  Row(
                    children: [
                      Container(
                        width:  36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:        _kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.output_outlined,
                            color: Colors.white, size: SU.iconMd),
                      ),
                      SizedBox(width: SU.xs),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            onChanged: _onSearch,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search,
                                  size:  SU.iconSm,
                                  color: Colors.black45),
                              filled:    true,
                              fillColor: _kOrange,
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: SU.xs),
                      _FilterPill(
                        label:    _filterLabel,
                        onSelect: (f) {
                          setState(() {
                            _filter       = f;
                            _globalFilter = _GlobalFilter.all;
                            _searchQuery  = '';
                          });
                          _loadData();
                        },
                      ),
                    ],
                  ),

                  // ── Global sub-filter pills ──────────
                  if (_filter == _IssuedFilter.globalHistory) ...[
                    SizedBox(height: SU.sm),
                    _GlobalFilterPills(
                      selected: _globalFilter,
                      onSelect: (f) {
                        setState(() => _globalFilter = f);
                        _applyFilters();
                      },
                    ),
                  ],

                  SizedBox(height: SU.md),

                  // ── Content ─────────────────────────
                  _isLoading
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(SU.xl),
                            child: const CircularProgressIndicator(
                                color: _kPrimary),
                          ),
                        )
                      : _filteredData.isEmpty
                          ? _EmptyState(filter: _filter)
                          : _filter == _IssuedFilter.myIssued
                              ? _buildIssuedCards()
                              : _filter == _IssuedFilter.myHistory
                                  ? _buildMyHistoryTable()
                                  : _buildGlobalTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // MY ISSUED CARDS
  // ════════════════════════════════════════════════════
  Widget _buildIssuedCards() {
    return Column(
      children: _filteredData.map((tx) {
        final item = _itemCache[tx.itemId];
        return Padding(
          padding: EdgeInsets.only(bottom: SU.sm),
          child: _IssuedCard(
            tx:   tx,
            item: item,
            onReturn: () {
              if (item != null) {
                _showReturnModal(tx, item.barcode);
              } else {
                _showError('Could not find item details');
              }
            },
          ),
        );
      }).toList(),
    );
  }

  // ════════════════════════════════════════════════════
  // MY HISTORY TABLE
  // ════════════════════════════════════════════════════
  Widget _buildMyHistoryTable() {
    return Container(
      decoration: BoxDecoration(
          color: _kOrange, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
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
                SizedBox(
                  width: SU.wp(0.10),
                  child: Text('Type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Qty',
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
              _MyHistoryRow(
                tx:     entry.value,
                isLast: entry.key == _filteredData.length - 1,
              )),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // GLOBAL HISTORY TABLE
  // ════════════════════════════════════════════════════
  Widget _buildGlobalTable() {
    final isAll = _globalFilter == _GlobalFilter.all;

    return Container(
      decoration: BoxDecoration(
          color: _kOrange, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: SU.sm, horizontal: SU.sm),
            child: _globalFilter == _GlobalFilter.consumable
                ? _GlobalConsumableHeader()
                : _globalFilter == _GlobalFilter.nonConsumable
                    ? _GlobalNonConsumableHeader()
                    : _GlobalAllHeader(),
          ),
          ..._filteredData.asMap().entries.map((entry) {
            final tx     = entry.value;
            final isLast = entry.key == _filteredData.length - 1;
            final isConsumableTx =
                tx.transactionType == 'StockIn' ||
                tx.transactionType == 'StockOut';

            if (_globalFilter == _GlobalFilter.consumable ||
                (isAll && isConsumableTx)) {
              return _GlobalConsumableRow(
                tx:          tx,
                isLast:      isLast,
                onViewProof: tx.photoProofUrl != null
                    ? () => _showProofImage(tx.photoProofUrl!)
                    : null,
              );
            } else {
              return _GlobalNonConsumableRow(
                  tx: tx, isLast: isLast);
            }
          }),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// MY HISTORY ROW
// ════════════════════════════════════════════════════
class _MyHistoryRow extends StatelessWidget {
  final ItemTransactionModel tx;
  final bool                 isLast;

  const _MyHistoryRow({required this.tx, required this.isLast});

  static final _fmt = DateFormat('MM/dd/yy');

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    final isConsumableTx =
        tx.transactionType == 'StockIn' ||
        tx.transactionType == 'StockOut';
    final qtyLabel = isConsumableTx ? tx.displayQtyLabel : '1 pc';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
            top: BorderSide(
                color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: SU.sm, horizontal: SU.sm),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(tx.itemName,
                textAlign: TextAlign.center,
                overflow:  TextOverflow.ellipsis,
                maxLines:  1,
                style: TextStyle(fontSize: SU.textXs)),
          ),
          SizedBox(
            width: SU.wp(0.10),
            child: Center(
                child: _TxTypeIcon(type: tx.transactionType)),
          ),
          Expanded(
            flex: 3,
            child: Text(qtyLabel,
                textAlign: TextAlign.center,
                overflow:  TextOverflow.ellipsis,
                maxLines:  1,
                style: TextStyle(
                    fontSize:   SU.textXs,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
                _fmt.format(tx.checkOutDate.toLocal()),
                textAlign: TextAlign.center,
                overflow:  TextOverflow.ellipsis,
                maxLines:  1,
                style: TextStyle(fontSize: SU.textXs)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// GLOBAL HISTORY HEADERS
// ════════════════════════════════════════════════════
class _GlobalAllHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Row(
      children: [
        Expanded(
            flex: 3,
            child: Text('User',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        Expanded(
            flex: 3,
            child: Text('Item',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        Expanded(
            flex: 4,
            child: Text('Details',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
      ],
    );
  }
}

class _GlobalConsumableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Row(
      children: [
        Expanded(
            flex: 3,
            child: Text('User',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        Expanded(
            flex: 3,
            child: Text('Item',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        SizedBox(
            width: SU.wp(0.09),
            child: Text('',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        Expanded(
            flex: 3,
            child: Text('Qty',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        Expanded(
            flex: 3,
            child: Text('Date',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        SizedBox(
            width: SU.wp(0.08),
            child: Text('Proof',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
      ],
    );
  }
}

class _GlobalNonConsumableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Row(
      children: [
        Expanded(
            flex: 3,
            child: Text('User',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        Expanded(
            flex: 3,
            child: Text('Item',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
        Expanded(
            flex: 4,
            child: Text('Transaction Period',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textXs))),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// GLOBAL CONSUMABLE ROW
// ════════════════════════════════════════════════════
class _GlobalConsumableRow extends StatelessWidget {
  final ItemTransactionModel tx;
  final bool                 isLast;
  final VoidCallback?        onViewProof;

  const _GlobalConsumableRow({
    required this.tx,
    required this.isLast,
    this.onViewProof,
  });

  static final _dateFmt = DateFormat('MM/dd/yy');

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
            top: BorderSide(
                color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: SU.sm, horizontal: SU.sm),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(tx.userName,
                  textAlign: TextAlign.center,
                  overflow:  TextOverflow.ellipsis,
                  maxLines:  1,
                  style: TextStyle(fontSize: SU.textXs))),
          Expanded(
              flex: 3,
              child: Text(tx.itemName,
                  textAlign: TextAlign.center,
                  overflow:  TextOverflow.ellipsis,
                  maxLines:  1,
                  style: TextStyle(fontSize: SU.textXs))),
          SizedBox(
              width: SU.wp(0.09),
              child: Center(
                  child:
                      _TxTypeIcon(type: tx.transactionType))),
          Expanded(
              flex: 3,
              child: Text(tx.displayQtyLabel,
                  textAlign: TextAlign.center,
                  overflow:  TextOverflow.ellipsis,
                  maxLines:  1,
                  style: TextStyle(
                      fontSize:   SU.textXs,
                      fontWeight: FontWeight.w600))),
          Expanded(
              flex: 3,
              child: Text(
                  _dateFmt.format(tx.checkOutDate.toLocal()),
                  textAlign: TextAlign.center,
                  overflow:  TextOverflow.ellipsis,
                  maxLines:  1,
                  style: TextStyle(fontSize: SU.textXs))),
          SizedBox(
            width: SU.wp(0.08),
            child: Center(
              child: tx.photoProofUrl != null
                  ? GestureDetector(
                      onTap: onViewProof,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          tx.photoProofUrl!,
                          width: 28, height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported_outlined,
                              size:  SU.iconSm,
                              color: Colors.black38),
                        ),
                      ),
                    )
                  : Text('—',
                      textAlign: TextAlign.center,
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

// ════════════════════════════════════════════════════
// GLOBAL NON-CONSUMABLE ROW
// ════════════════════════════════════════════════════
class _GlobalNonConsumableRow extends StatelessWidget {
  final ItemTransactionModel tx;
  final bool                 isLast;

  const _GlobalNonConsumableRow(
      {required this.tx, required this.isLast});

  static final _dateFormat = DateFormat('MM/dd/yy hh:mm a');

  String _fmt(DateTime date) =>
      _dateFormat.format(date.toLocal());

  String _dur(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays > 0)
      return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0)
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
            top: BorderSide(
                color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: SU.sm, horizontal: SU.sm),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(tx.userName,
                  textAlign: TextAlign.center,
                  overflow:  TextOverflow.ellipsis,
                  maxLines:  1,
                  style: TextStyle(fontSize: SU.textXs))),
          Expanded(
              flex: 3,
              child: Text(tx.itemName,
                  textAlign: TextAlign.center,
                  overflow:  TextOverflow.ellipsis,
                  maxLines:  1,
                  style: TextStyle(fontSize: SU.textXs))),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.logout,
                          size: 10, color: Colors.white),
                    ),
                    SizedBox(width: SU.xs),
                    Flexible(
                      child: Text(
                        _fmt(tx.checkOutDate),
                        style: TextStyle(
                            fontSize:   SU.textXs - 1,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (tx.checkInDate != null) ...[
                  SizedBox(height: SU.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: _kSuccess,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.login,
                            size: 10, color: Colors.white),
                      ),
                      SizedBox(width: SU.xs),
                      Flexible(
                        child: Text(
                          _fmt(tx.checkInDate!),
                          style: TextStyle(
                              fontSize:   SU.textXs - 1,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SU.xs),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: SU.xs + 2, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kSuccess.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _dur(tx.checkOutDate, tx.checkInDate!),
                      style: TextStyle(
                          fontSize:   SU.textXs - 2,
                          fontWeight: FontWeight.w700,
                          color:      _kSuccess),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: SU.xs),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: SU.xs + 2, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time,
                            size: 10, color: _kPrimary),
                        SizedBox(width: SU.xs),
                        Text(
                          'CURRENTLY OUT',
                          style: TextStyle(
                              fontSize:   SU.textXs - 2,
                              fontWeight: FontWeight.w700,
                              color:      _kPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// TX TYPE ICON
// ════════════════════════════════════════════════════
class _TxTypeIcon extends StatelessWidget {
  final String type;
  const _TxTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    IconData icon;
    Color    bg;
    String   tooltip;

    switch (type) {
      case 'StockIn':
        icon    = Icons.arrow_downward_rounded;
        bg      = _kSuccess;
        tooltip = 'Stock In';
        break;
      case 'StockOut':
        icon    = Icons.arrow_upward_rounded;
        bg      = _kPrimary;
        tooltip = 'Stock Out';
        break;
      case 'Issued':
        icon    = Icons.arrow_upward_rounded;
        bg      = _kPrimary;
        tooltip = 'Issued';
        break;
      case 'Returned':
        icon    = Icons.arrow_downward_rounded;
        bg      = _kSuccess;
        tooltip = 'Returned';
        break;
      default:
        icon    = Icons.swap_horiz_rounded;
        bg      = Colors.grey;
        tooltip = type;
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width:  SU.wp(0.072),
        height: SU.wp(0.072),
        decoration:
            BoxDecoration(color: bg, shape: BoxShape.circle),
        child:
            Icon(icon, color: Colors.white, size: SU.textSm),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// GLOBAL FILTER PILLS
// ════════════════════════════════════════════════════
class _GlobalFilterPills extends StatelessWidget {
  final _GlobalFilter                selected;
  final void Function(_GlobalFilter) onSelect;

  const _GlobalFilterPills(
      {required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color:        _kCardBg,
          borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
              label:    'All',
              isActive: selected == _GlobalFilter.all,
              onTap:    () => onSelect(_GlobalFilter.all)),
          _Pill(
              label:    'Consumable',
              isActive: selected == _GlobalFilter.consumable,
              onTap:    () => onSelect(_GlobalFilter.consumable)),
          _Pill(
              label:    'Non-Consumable',
              isActive: selected == _GlobalFilter.nonConsumable,
              onTap: () =>
                  onSelect(_GlobalFilter.nonConsumable)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String       label;
  final bool         isActive;
  final VoidCallback onTap;

  const _Pill(
      {required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: SU.sm, vertical: SU.xs + 4),
        decoration: BoxDecoration(
          color:        isActive ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(label,
            style: TextStyle(
                color:      isActive ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize:   SU.textXs)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// ISSUED CARD
// ════════════════════════════════════════════════════
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
          Center(
            child: Container(
              width:  SU.wp(0.28),
              height: SU.wp(0.28),
              decoration: BoxDecoration(
                color:        _kInnerCard,
                borderRadius: BorderRadius.circular(SU.radiusLg),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius:
                          BorderRadius.circular(SU.radiusLg),
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
          _ReadOnlyField(
              text: fmt.format(tx.checkOutDate.toLocal())),
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

// ════════════════════════════════════════════════════
// SCAN RETURN MODAL
// ════════════════════════════════════════════════════
class _ScanReturnModal extends StatefulWidget {
  final String                 itemName;
  final String                 expectedBarcode;
  final ItemTransactionService service;
  final VoidCallback           onSuccess;
  final void Function(String)  onError;

  const _ScanReturnModal({
    required this.itemName,
    required this.expectedBarcode,
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
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(
              hintLabel: 'Scan to Return')),
    );

    if (scanned == null || !mounted) return;

    if (scanned != widget.expectedBarcode) {
      widget.onError('Wrong item! Please scan the correct '
          'barcode for "${widget.itemName}".');
      return;
    }

    setState(() {
      _ctrl.text = scanned;
      _isLoading = true;
    });

    try {
      await widget.service.returnItem(scanned);
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      widget.onError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
          horizontal: SU.wp(0.06), vertical: SU.hp(0.32)),
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width:  38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_scanner,
                            color: Colors.white, size: 22),
                      ),
                      SizedBox(width: SU.sm),
                      Expanded(
                        child: Text(
                          'Scan "${widget.itemName}"',
                          style: TextStyle(
                              fontSize:   SU.textMd,
                              fontWeight: FontWeight.w700,
                              color:      Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap:
                      _isLoading ? null : () => Navigator.pop(context),
                  child: Container(
                    width:  28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: _kInnerCard,
                        shape: BoxShape.circle),
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
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text(
                      _ctrl.text.isNotEmpty
                          ? _ctrl.text
                          : 'Scan barcode to return',
                      style: TextStyle(
                        fontSize: SU.textMd,
                        color:    _ctrl.text.isNotEmpty
                            ? Colors.black87
                            : Colors.black38,
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
                  child: _isLoading
                      ? const SizedBox(
                          width:  18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Scan',
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

// ════════════════════════════════════════════════════
// FILTER PILL DROPDOWN
// ════════════════════════════════════════════════════
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

// ════════════════════════════════════════════════════
// EMPTY STATE
// ════════════════════════════════════════════════════
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
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                  color: _kCardBg, shape: BoxShape.circle),
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

// ════════════════════════════════════════════════════
// CARD HELPERS
// ════════════════════════════════════════════════════
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
              style:    TextStyle(fontSize: SU.textSm),
            ),
          ),
        ],
      ),
    );
  }
}