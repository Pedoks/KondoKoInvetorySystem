import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';
import '../services/item_transaction_service.dart';
import 'barcode_scanner_screen.dart';

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

  // itemId -> ItemModel cache (for image + description in My Issued cards)
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

      // For My Issued: fetch full ItemModel for each tx to get imageUrl + description
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
        if (mounted) setState(() { _itemCache.clear(); _itemCache.addAll(cache); });
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
          .where((tx) => tx.itemName.toLowerCase().contains(q.toLowerCase()))
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg),
          backgroundColor: const Color(AppConstants.successColorValue)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final top  = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColorValue),
      body: Column(
        children: [
          // App Bar
          Container(
            color: const Color(AppConstants.primaryColorValue),
            padding: EdgeInsets.only(top: top + 12, bottom: 16, left: 4, right: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('Issued Items',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(size.width * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.015),

                  // Header row
                  Row(
                    children: [
                      const _SectionHeader(icon: Icons.output_outlined, label: 'Issued Items'),
                      const Spacer(),
                      SizedBox(
                        width: size.width * 0.30,
                        height: 36,
                        child: TextField(
                          onChanged: _applySearch,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 16, color: Colors.black45),
                            filled:    true,
                            fillColor: const Color(AppConstants.lightOrangeValue),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label:    _filterLabel,
                        onSelect: (f) { setState(() => _filter = f); _loadData(); },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _isLoading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                              color: Color(AppConstants.primaryColorValue))))
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

  Widget _buildIssuedCards() {
    return Column(
      children: _filteredData.map((tx) {
        final item = _itemCache[tx.itemId];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _IssuedCard(tx: tx, item: item, onReturn: () => _showReturnModal(tx)),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('Item Name',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(flex: 3, child: Text('Type',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(flex: 3, child: Text('Date',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              ],
            ),
          ),
          ..._filteredData.asMap().entries.map((entry) =>
              _HistoryRow(tx: entry.value, isLast: entry.key == _filteredData.length - 1)),
        ],
      ),
    );
  }

  Widget _buildGlobalTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('User',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 3, child: Text('Item',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 2, child: Text('Type',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 2, child: Text('Proof',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
            ),
          ),
          ..._filteredData.asMap().entries.map((entry) => _GlobalRow(
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

  const _IssuedCard({required this.tx, required this.item, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final fmt         = DateFormat('dd/MM/yy');
    final imageUrl    = item?.imageUrl    ?? '';
    final description = item?.description ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Center(
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: const Color(AppConstants.backgroundColorValue),
                borderRadius: BorderRadius.circular(20),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined, size: 44, color: Colors.black26)))
                  : const Icon(Icons.inventory_2_outlined, size: 44, color: Colors.black26),
            ),
          ),

          const SizedBox(height: 16),

          // Item Name
          const Text('Item Name',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 6),
          _ReadOnlyField(text: tx.itemName),

          const SizedBox(height: 12),

          // Item Description
          const Text('Item Description',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 6),
          _ReadOnlyField(
            text:     description.isNotEmpty ? description : '—',
            maxLines: 4,
            hasIcon:  true,
          ),

          const SizedBox(height: 12),

          // Issued Date
          const Text('Issued Date:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 6),
          _ReadOnlyField(text: fmt.format(tx.checkOutDate.toLocal())),

          const SizedBox(height: 16),

          // Return button
          SizedBox(
            width: 120, height: 40,
            child: ElevatedButton(
              onPressed: onReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text('Return',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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
    final fmt = DateFormat('MM/dd/yy');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(tx.itemName,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Center(child: _TxTypeBadge(type: tx.transactionType))),
          Expanded(flex: 3, child: Text(fmt.format(tx.checkOutDate.toLocal()),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
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

  const _GlobalRow({required this.tx, required this.isLast, this.onViewProof});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(tx.userName,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(tx.itemName,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Center(child: _TxTypeBadge(type: tx.transactionType))),
          Expanded(
            flex: 2,
            child: Center(
              child: tx.photoProofUrl != null
                  ? GestureDetector(
                      onTap: onViewProof,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(tx.photoProofUrl!,
                            width: 36, height: 36, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                size: 20, color: Colors.black38)),
                      ),
                    )
                  : const Text('—', style: TextStyle(color: Colors.black38, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Type Badge ─────────────────────────────
class _TxTypeBadge extends StatelessWidget {
  final String type;
  const _TxTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case 'StockIn':
      case 'Returned':
        color = const Color(AppConstants.successColorValue);
        break;
      case 'StockOut':
      case 'Issued':
        color = const Color(AppConstants.primaryColorValue);
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(type,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _scan() async {
    Navigator.pop(context);
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(hintLabel: 'Scan to Return')),
    );
    if (scanned == null || !mounted) return;
    setState(() { _ctrl.text = scanned; _isLoading = true; });
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
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.06, vertical: size.height * 0.32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(24),
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
                        color: const Color(AppConstants.primaryColorValue),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text('Scan Item Barcode',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    readOnly:   true,
                    decoration: _scanFieldDeco('Scan to Return'),
                  ),
                ),
                const SizedBox(width: 10),
                _GreenScanBtn(onTap: _isLoading ? () {} : _scan),
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
    return PopupMenuButton<_IssuedFilter>(
      onSelected: onSelect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(AppConstants.backgroundColorValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black87),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(value: _IssuedFilter.myIssued,
            child: const Text('My Issued', style: TextStyle(fontSize: 13))),
        PopupMenuItem(value: _IssuedFilter.myHistory,
            child: const Text('My History', style: TextStyle(fontSize: 13))),
        PopupMenuItem(value: _IssuedFilter.globalHistory,
            child: const Text('Global History', style: TextStyle(fontSize: 13))),
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
    final msgs = {
      _IssuedFilter.myIssued:      'No items currently issued to you.',
      _IssuedFilter.myHistory:     'No transaction history yet.',
      _IssuedFilter.globalHistory: 'No global transactions yet.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(msgs[filter] ?? 'No data.',
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(AppConstants.primaryColorValue),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
      ],
    );
  }
}

// ── Read Only Field ────────────────────────────────────
class _ReadOnlyField extends StatelessWidget {
  final String text;
  final int    maxLines;
  final bool   hasIcon;

  const _ReadOnlyField({required this.text, this.maxLines = 1, this.hasIcon = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasIcon) ...[
            const Icon(Icons.description_outlined, size: 16, color: Colors.black38),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(text,
                maxLines: maxLines, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Shared Helpers ─────────────────────────────────────
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
      borderSide: const BorderSide(color: Colors.black26)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.black26)),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(AppConstants.primaryColorValue), width: 1.5)),
);