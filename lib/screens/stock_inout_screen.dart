import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';
import '../services/item_transaction_service.dart';
import '../services/cloudinary_service.dart';
import 'barcode_scanner_screen.dart';

class StockInOutScreen extends StatefulWidget {
  final String token;

  const StockInOutScreen({super.key, required this.token});

  @override
  State<StockInOutScreen> createState() => _StockInOutScreenState();
}

class _StockInOutScreenState extends State<StockInOutScreen> {
  // ── Tab ───────────────────────────────────────────────
  bool _isConsumableTab = true;

  // ── Consumable state ──────────────────────────────────
  late final ItemService _itemService;
  late final ItemTransactionService _txService;
  final _cloudinary = CloudinaryService();
  final _picker     = ImagePicker();

  List<ItemModel> _allItems      = [];
  List<ItemModel> _filteredItems = [];
  bool _isLoading   = false;
  bool _isStockIn   = true; // true = Stock In, false = Stock Out
  String _searchQuery = '';

  // Cart: itemId → {item, qty}
  final Map<String, _CartEntry> _cart = {};

  // Confirm mode
  bool  _confirmMode = false;
  File? _proofImage;
  bool  _isSubmitting = false;

  // ── Non-consumable state ──────────────────────────────
  final _barcodeCtrl = TextEditingController();
  final List<ItemScanResultModel> _scannedItems = [];
  bool _isScanning   = false;
  bool _isIssuing    = false;

  @override
  void initState() {
    super.initState();
    _itemService = ItemService(token: widget.token);
    _txService   = ItemTransactionService(token: widget.token);
    _loadConsumableItems();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    super.dispose();
  }

  // ── Load consumable items ─────────────────────────────
  Future<void> _loadConsumableItems() async {
    setState(() => _isLoading = true);
    try {
      final all = await _itemService.getAllItems();
      final consumable = all.where((i) => i.isConsumable).toList();
      setState(() {
        _allItems      = consumable;
        _filteredItems = consumable;
        _isLoading     = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('$e');
    }
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery   = q;
      _filteredItems = _allItems.where((i) =>
          i.itemName.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  // ── Cart helpers ──────────────────────────────────────
  void _addToCart(ItemModel item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.qty++;
      } else {
        _cart[item.id] = _CartEntry(item: item, qty: 1);
      }
    });
  }

  void _removeFromCart(String itemId) {
    setState(() => _cart.remove(itemId));
  }

  void _incrementCart(String itemId) {
    setState(() => _cart[itemId]!.qty++);
  }

  void _decrementCart(String itemId) {
    setState(() {
      if (_cart[itemId]!.qty > 1) {
        _cart[itemId]!.qty--;
      } else {
        _cart.remove(itemId);
      }
    });
  }

  int get _totalCartItems =>
      _cart.values.fold(0, (sum, e) => sum + e.qty);

  // ── Pick proof image ──────────────────────────────────
  Future<void> _pickProofImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _proofImage = File(picked.path));
    }
  }

  // ── Confirm stock in/out ──────────────────────────────
  Future<void> _confirmStock() async {
    if (_proofImage == null) {
      _showError('Please upload proof image first.');
      return;
    }
    if (_cart.isEmpty) {
      _showError('No items in cart.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final proofUrl = await _cloudinary.uploadImage(_proofImage!);
      for (final entry in _cart.values) {
        if (_isStockIn) {
          await _txService.stockIn(
            barcode:      entry.item.barcode,
            quantity:     entry.qty,
            photoProofUrl: proofUrl,
          );
        } else {
          await _txService.stockOut(
            barcode:      entry.item.barcode,
            quantity:     entry.qty,
            photoProofUrl: proofUrl,
          );
        }
      }
      _showSuccess(
          '${_isStockIn ? "Stock In" : "Stock Out"} confirmed successfully!');
      setState(() {
        _cart.clear();
        _proofImage  = null;
        _confirmMode = false;
      });
      _loadConsumableItems();
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Non-consumable: scan ──────────────────────────────
  Future<void> _scanNonConsumable() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const BarcodeScannerScreen(hintLabel: 'Scan item barcode'),
      ),
    );
    if (scanned == null || !mounted) return;

    setState(() {
      _barcodeCtrl.text = scanned;
      _isScanning       = true;
    });

    try {
      final result = await _txService.scanBarcode(scanned);
      if (!mounted) return;
      if (result.isAvailable) {
        setState(() => _scannedItems.add(result));
      } else {
        _showError(
            'Item "${result.itemName}" is already issued to ${result.issuedTo ?? "someone"}.');
      }
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning       = false;
          _barcodeCtrl.text = '';
        });
      }
    }
  }

  // ── Non-consumable: confirm issue ─────────────────────
  Future<void> _confirmIssue() async {
    if (_scannedItems.isEmpty) {
      _showError('No items scanned.');
      return;
    }
    setState(() => _isIssuing = true);
    try {
      for (final item in _scannedItems) {
        await _txService.issueItem(item.barcode);
      }
      _showSuccess('Items issued successfully!');
      setState(() => _scannedItems.clear());
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _isIssuing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade600,
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(AppConstants.successColorValue),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final top  = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColorValue),
      body: Column(
        children: [
          // ── App Bar ──────────────────────────────────
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
                  'Stock In/Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 24),
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

                  // ── Section Header + Search ──────────
                  Row(
                    children: [
                      _SectionHeader(
                          icon: Icons.inventory_2, label: 'Item List'),
                      const Spacer(),
                      SizedBox(
                        width: size.width * 0.38,
                        height: 38,
                        child: TextField(
                          onChanged: _onSearch,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search,
                                size: 18, color: Colors.black45),
                            filled:     true,
                            fillColor:
                                const Color(AppConstants.lightOrangeValue),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Tab Pills ────────────────────────
                  Row(
                    children: [
                      _TabPill(
                        label:    'Consumable',
                        isActive: _isConsumableTab,
                        onTap:    () => setState(() {
                          _isConsumableTab = true;
                          _cart.clear();
                          _confirmMode = false;
                        }),
                      ),
                      const SizedBox(width: 4),
                      const Text('|',
                          style: TextStyle(color: Colors.black45)),
                      const SizedBox(width: 4),
                      _TabPill(
                        label:    'Non-Consumable',
                        isActive: !_isConsumableTab,
                        onTap:    () => setState(
                            () => _isConsumableTab = false),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Tab Content ──────────────────────
                  _isConsumableTab
                      ? _buildConsumableTab(size)
                      : _buildNonConsumableTab(size),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CONSUMABLE TAB
  // ══════════════════════════════════════════════════════
  Widget _buildConsumableTab(Size size) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            color: Color(AppConstants.primaryColorValue),
          ),
        ),
      );
    }

    return Column(
      children: [
        // ── Item Table ─────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: const Color(AppConstants.lightOrangeValue),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Table header
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 12),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text('Item',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text('Quantity',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    // Stock In / Stock Out dropdown header
                    Expanded(
                      flex: 3,
                      child: PopupMenuButton<bool>(
                        onSelected: (val) =>
                            setState(() => _isStockIn = val),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: const Color(
                            AppConstants.backgroundColorValue),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isStockIn
                                ? const Color(
                                    AppConstants.successColorValue)
                                : Colors.red.shade500,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isStockIn
                                    ? 'Stock In'
                                    : 'Stock Out',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 14),
                            ],
                          ),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: true,
                            child: Row(children: [
                              Icon(Icons.add_circle_outline,
                                  color: const Color(
                                      AppConstants.successColorValue),
                                  size: 16),
                              const SizedBox(width: 8),
                              const Text('Stock In',
                                  style: TextStyle(fontSize: 13)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: false,
                            child: Row(children: [
                              Icon(Icons.remove_circle_outline,
                                  color: Colors.red.shade500,
                                  size: 16),
                              const SizedBox(width: 8),
                              const Text('Stock Out',
                                  style: TextStyle(fontSize: 13)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Rows
              if (_filteredItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No consumable items found.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ..._filteredItems.asMap().entries.map((entry) {
                  final isLast =
                      entry.key == _filteredItems.length - 1;
                  final item = entry.value;
                  final inCart = _cart.containsKey(item.id);
                  final cartQty =
                      inCart ? _cart[item.id]!.qty : 0;

                  return _ConsumableRow(
                    item:      item,
                    isLast:    isLast,
                    isStockIn: _isStockIn,
                    inCart:    inCart,
                    cartQty:   cartQty,
                    onAdd:     () => _addToCart(item),
                    onDelete:  () => _removeFromCart(item.id),
                    onInc:     () => _incrementCart(item.id),
                    onDec:     () => _decrementCart(item.id),
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Upload Proof (always visible when cart not empty) ──
        if (_cart.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.photo_camera_outlined, label: 'Upload Proof'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickProofImage,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(AppConstants.lightOrangeValue),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black26),
              ),
              child: _proofImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_proofImage!,
                          fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 36, color: Colors.black38),
                        SizedBox(height: 8),
                        Text('Upload Picture',
                            style: TextStyle(
                                color: Colors.black45, fontSize: 13)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Total + Confirm ────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(AppConstants.lightOrangeValue),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Items:',
                      style: TextStyle(
                          fontSize: 13, color: Colors.black54)),
                  Text(
                    '$_totalCartItems',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: (_cart.isEmpty || _isSubmitting)
                      ? null
                      : _confirmStock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(AppConstants.successColorValue),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // NON-CONSUMABLE TAB
  // ══════════════════════════════════════════════════════
  Widget _buildNonConsumableTab(Size size) {
    return Column(
      children: [
        // ── Scan Row ───────────────────────────────────
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
                  controller: _barcodeCtrl,
                  readOnly:   true,
                  decoration:
                      _scanFieldDeco('Scan Barcode'),
                ),
              ),
              const SizedBox(width: 10),
              _GreenScanBtn(onTap: _scanNonConsumable),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Scanned Item Cards ─────────────────────────
        if (_isScanning)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
              color: Color(AppConstants.primaryColorValue),
            ),
          ),

        ..._scannedItems.asMap().entries.map((entry) {
          final i    = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ScannedItemCard(
              item:      item,
              onDismiss: () =>
                  setState(() => _scannedItems.removeAt(i)),
            ),
          );
        }),

        if (_scannedItems.isNotEmpty) ...[
          // "+ Add another" button
          GestureDetector(
            onTap: _scanNonConsumable,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(AppConstants.lightOrangeValue),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '+ Add another',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Total + Confirm Issue ──────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(AppConstants.lightOrangeValue),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Items:',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54)),
                    Text(
                      '${_scannedItems.length}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed:
                        _isIssuing ? null : _confirmIssue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                          AppConstants.successColorValue),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24),
                      elevation: 0,
                    ),
                    child: _isIssuing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5))
                        : const Text(
                            'Confirm Issue',
                            style: TextStyle(
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

        if (_scannedItems.isEmpty && !_isScanning)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner,
                    size: 48,
                    color: Colors.black.withOpacity(0.2)),
                const SizedBox(height: 12),
                const Text(
                  'Scan a barcode to issue a non-consumable item.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Cart Entry ─────────────────────────────────────────
class _CartEntry {
  final ItemModel item;
  int qty;
  _CartEntry({required this.item, required this.qty});
}

// ── Consumable Row ─────────────────────────────────────
class _ConsumableRow extends StatelessWidget {
  final ItemModel    item;
  final bool         isLast;
  final bool         isStockIn;
  final bool         inCart;
  final int          cartQty;
  final VoidCallback onAdd;
  final VoidCallback onDelete;
  final VoidCallback onInc;
  final VoidCallback onDec;

  const _ConsumableRow({
    required this.item,
    required this.isLast,
    required this.isStockIn,
    required this.inCart,
    required this.cartQty,
    required this.onAdd,
    required this.onDelete,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
            top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          // Item col
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(item.imageUrl,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ThumbPlaceholder())
                      : _ThumbPlaceholder(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.itemName,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),

          // Quantity col: - qty +
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('-',
                    style: TextStyle(
                        fontSize: 14, color: Colors.black54)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    inCart ? '$cartQty' : '${item.quantity}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const Text('+',
                    style: TextStyle(
                        fontSize: 14, color: Colors.black54)),
              ],
            ),
          ),

          // Action col
          Expanded(
            flex: 3,
            child: Center(
              child: inCart
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Qty controls in cart
                        GestureDetector(
                          onTap: onDec,
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.remove,
                                size: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                          child: Text('$cartQty',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        GestureDetector(
                          onTap: onInc,
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: const Color(
                                  AppConstants.primaryColorValue),
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Delete
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: const Text('Delete',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isStockIn
                              ? const Color(
                                  AppConstants.successColorValue)
                              : Colors.red.shade500,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          isStockIn ? '+ Add' : '- Out',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scanned Item Card (Non-Consumable) ─────────────────
class _ScannedItemCard extends StatelessWidget {
  final ItemScanResultModel item;
  final VoidCallback        onDismiss;

  const _ScannedItemCard({
    required this.item,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // X button
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  size: 22, color: Colors.black54),
            ),
          ),

          // Image
          Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: const Color(AppConstants.backgroundColorValue),
                borderRadius: BorderRadius.circular(16),
              ),
              child: item.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            size: 40,
                            color: Colors.black26),
                      ),
                    )
                  : const Icon(Icons.inventory_2_outlined,
                      size: 40, color: Colors.black26),
            ),
          ),

          const SizedBox(height: 12),

          // Item Name
          const Text('Item Name:',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          _ReadOnlyField(text: item.itemName),

          const SizedBox(height: 10),

          // Item Description (use itemType as fallback label)
          const Text('Item Description:',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          _ReadOnlyField(
            text: item.itemType,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

// ── Tab Pill ───────────────────────────────────────────
class _TabPill extends StatelessWidget {
  final String       label;
  final bool         isActive;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(AppConstants.successColorValue)
              : const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            )),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────
class _ThumbPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          size: 16, color: Colors.black45),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String text;
  final int    maxLines;

  const _ReadOnlyField({required this.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

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
      child: const Text('Scan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
    );
  }
}

InputDecoration _scanFieldDeco(String hint) => InputDecoration(
  hintText:  hint,
  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
  filled:    true,
  fillColor: const Color(AppConstants.backgroundColorValue),
  contentPadding:
      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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