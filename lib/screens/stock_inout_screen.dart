import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';
import '../utils/uom_helper.dart';
import '../widgets/kondo_app_bar.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';
import '../services/item_transaction_service.dart';
import '../services/cloudinary_service.dart';
import 'barcode_scanner_screen.dart';

// ── Palette ──────────────────────────────────────────────
const _kBg        = Color(AppConstants.backgroundColorValue);
const _kCardBg    = Color(AppConstants.modalBgValue);
const _kInnerCard = Color(AppConstants.modalCardBgValue);
const _kFieldBg   = Colors.white;
const _kBorder    = Colors.black26;
const _kPrimary   = Color(AppConstants.primaryColorValue);
const _kStockIn   = Color(AppConstants.successColorValue);
const _kStockOut  = Color(AppConstants.errorColorValue);
const _kRemove    = Color(AppConstants.errorColorValue);

class StockInOutScreen extends StatefulWidget {
  final String token;
  const StockInOutScreen({super.key, required this.token});

  @override
  State<StockInOutScreen> createState() => _StockInOutScreenState();
}

class _StockInOutScreenState extends State<StockInOutScreen> {
  bool _isConsumableTab = true;

  late final ItemService            _itemService;
  late final ItemTransactionService _txService;
  final _cloudinary = CloudinaryService();
  final _picker     = ImagePicker();

  List<ItemModel> _allItems      = [];
  List<ItemModel> _filteredItems = [];
  bool   _isLoading   = false;
  bool   _isStockIn   = true;
  String _searchQuery = '';

  final Map<String, _CartEntry> _cart = {};
  File? _proofImage;
  bool  _isSubmitting = false;

  final _barcodeCtrl = TextEditingController();
  final List<ItemScanResultModel> _scannedItems = [];
  bool _isScanning = false;
  bool _isIssuing  = false;

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

  Future<void> _loadConsumableItems() async {
    setState(() => _isLoading = true);
    try {
      final all        = await _itemService.getAllItems();
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
      _filteredItems = _allItems
          .where((i) => i.itemName.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  void _addToCart(ItemModel item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.qty++;
      } else {
        // Default to preferredUnit so display matches item list
        _cart[item.id] = _CartEntry(
          item:         item,
          qty:          1,
          selectedUnit: item.preferredUnit,
        );
      }
    });
  }

  void _removeFromCart(String itemId) => setState(() => _cart.remove(itemId));
  void _incrementCart(String itemId)  => setState(() => _cart[itemId]!.qty++);

  void _decrementCart(String itemId) {
    setState(() {
      if (_cart[itemId]!.qty > 1) {
        _cart[itemId]!.qty--;
      } else {
        _cart.remove(itemId);
      }
    });
  }

  void _setCartUnit(String itemId, String unit) =>
      setState(() => _cart[itemId]!.selectedUnit = unit);

  int get _totalCartItems =>
      _cart.values.fold(0, (s, e) => s + e.qty);

  Future<void> _pickProofImage() async {
    final picked = await _picker.pickImage(
        source:                ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth:              1024,
        imageQuality:          80);
    if (picked != null && mounted) {
      setState(() => _proofImage = File(picked.path));
    }
  }

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
        // Base qty — what gets sent to backend for stock calculation
        final baseQty = UOM.toBase(
          entry.qty.toDouble(),
          entry.selectedUnit,
          conversionFactor: entry.item.conversionFactor,
        );

        // Display values — what gets stored for history display
        final displayQty  = entry.qty.toDouble();
        final displayUnit = entry.selectedUnit;

        if (_isStockIn) {
          await _txService.stockIn(
            barcode:         entry.item.id,
            quantity:        baseQty,
            displayQuantity: displayQty,
            displayUnit:     displayUnit,
            photoProofUrl:   proofUrl,
          );
        } else {
          await _txService.stockOut(
            barcode:         entry.item.id,
            quantity:        baseQty,
            displayQuantity: displayQty,
            displayUnit:     displayUnit,
            photoProofUrl:   proofUrl,
          );
        }
      }

      _showSuccess('${_isStockIn ? "Stock In" : "Stock Out"} confirmed!');
      setState(() {
        _cart.clear();
        _proofImage = null;
      });
      _loadConsumableItems();
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _scanNonConsumable() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const BarcodeScannerScreen(hintLabel: 'Scan item barcode')),
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
        _showError('Item "${result.itemName}" already issued to '
            '${result.issuedTo ?? "someone"}.');
      }
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() {
        _isScanning       = false;
        _barcodeCtrl.text = '';
      });
    }
  }

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
        backgroundColor: const Color(AppConstants.errorColorValue)));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: _kStockIn));
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          KondoAppBar(title: 'Stock In/Out', showBack: true, showLogo: false),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(SU.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: SU.sm),

                  // ── Header + search ───────────────────
                  Row(
                    children: [
                      _SectionIcon(Icons.inventory_2),
                      SizedBox(width: SU.sm),
                      Text('Item List',
                          style: TextStyle(
                              fontSize:   SU.textLg,
                              fontWeight: FontWeight.w700,
                              color:      Colors.black87)),
                      const Spacer(),
                      SizedBox(
                        width: SU.wp(0.38), height: 38,
                        child: TextField(
                          onChanged: _onSearch,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search,
                                size: SU.iconSm, color: Colors.black45),
                            filled:     true,
                            fillColor:  _kCardBg,
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

                  SizedBox(height: SU.sm),

                  // ── Tab pills ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TabPill(
                          label:    'Consumable',
                          isActive: _isConsumableTab,
                          onTap: () => setState(() {
                            _isConsumableTab = true;
                            _cart.clear();
                          }),
                        ),
                        _TabPill(
                          label:    'Non-Consumable',
                          isActive: !_isConsumableTab,
                          onTap: () =>
                              setState(() => _isConsumableTab = false),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: SU.md),

                  _isConsumableTab
                      ? _buildConsumableTab()
                      : _buildNonConsumableTab(),
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
  Widget _buildConsumableTab() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(SU.xl),
          child: const CircularProgressIndicator(color: _kPrimary),
        ),
      );
    }

    return Column(
      children: [
        // ── Item Table ──────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
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
            children: [
              // Table header
              Container(
                padding: EdgeInsets.symmetric(
                    vertical: SU.sm, horizontal: SU.sm),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.lightOrangeValue),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(SU.radiusLg)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text('Item',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize:   SU.textSm,
                              color:      Colors.black87)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Stock',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize:   SU.textSm,
                              color:      Colors.black87)),
                    ),
                    // Stock In / Out toggle
                    Expanded(
                      flex: 4,
                      child: PopupMenuButton<bool>(
                        onSelected: (val) =>
                            setState(() => _isStockIn = val),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: _kCardBg,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: SU.sm, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isStockIn ? _kStockIn : _kStockOut,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isStockIn
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size:  SU.iconSm - 4,
                              ),
                              SizedBox(width: SU.xs),
                              Flexible(
                                child: Text(
                                  _isStockIn ? 'Stock In' : 'Stock Out',
                                  style: TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize:   SU.textXs),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: true,
                            child: Row(children: [
                              const Icon(Icons.arrow_downward_rounded,
                                  color: _kStockIn, size: 16),
                              SizedBox(width: SU.sm),
                              Text('Stock In',
                                  style: TextStyle(fontSize: SU.textSm)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: false,
                            child: Row(children: [
                              const Icon(Icons.arrow_upward_rounded,
                                  color: _kStockOut, size: 16),
                              SizedBox(width: SU.sm),
                              Text('Stock Out',
                                  style: TextStyle(fontSize: SU.textSm)),
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
                Padding(
                  padding: EdgeInsets.all(SU.xl),
                  child: Text('No consumable items found.',
                      style: TextStyle(
                          color: Colors.grey, fontSize: SU.textSm)),
                )
              else
                ..._filteredItems.asMap().entries.map((entry) {
                  final isLast = entry.key == _filteredItems.length - 1;
                  final item   = entry.value;
                  final inCart = _cart.containsKey(item.id);
                  final ce     = _cart[item.id];
                  return _ConsumableRow(
                    item:         item,
                    isLast:       isLast,
                    isStockIn:    _isStockIn,
                    inCart:       inCart,
                    cartEntry:    ce,
                    onAdd:        () => _addToCart(item),
                    onDelete:     () => _removeFromCart(item.id),
                    onInc:        () => _incrementCart(item.id),
                    onDec:        () => _decrementCart(item.id),
                    onUnitChange: (u) => _setCartUnit(item.id, u),
                  );
                }),
            ],
          ),
        ),

        SizedBox(height: SU.md),

        // ── Proof upload (only when cart has items) ───
        if (_cart.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(SU.md),
            decoration: BoxDecoration(
              color: _kCardBg,
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
                Row(children: [
                  _SectionIcon(Icons.photo_camera_outlined),
                  SizedBox(width: SU.sm),
                  Text('Upload Proof',
                      style: TextStyle(
                          fontSize:   SU.textMd,
                          fontWeight: FontWeight.w700,
                          color:      Colors.black87)),
                ]),
                SizedBox(height: SU.sm),
                GestureDetector(
                  onTap: _pickProofImage,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      color: _kInnerCard,
                      borderRadius: BorderRadius.circular(SU.radiusLg),
                      border: Border.all(color: _kBorder),
                    ),
                    child: _proofImage != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(SU.radiusLg),
                            child: Image.file(_proofImage!,
                                fit: BoxFit.cover))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: SU.xl, color: Colors.black38),
                              SizedBox(height: SU.xs),
                              Text('Tap to upload',
                                  style: TextStyle(
                                      color:    Colors.black45,
                                      fontSize: SU.textSm)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: SU.md),
        ],

        // ── Total + Confirm ───────────────────────
        _TotalConfirmBar(
          total:        _totalCartItems,
          confirmLabel: _isStockIn ? 'Confirm Stock In' : 'Confirm Stock Out',
          isLoading:    _isSubmitting,
          disabled:     _cart.isEmpty,
          onConfirm:    _confirmStock,
          isStockIn:    _isStockIn,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // NON-CONSUMABLE TAB
  // ══════════════════════════════════════════════════════
  Widget _buildNonConsumableTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(SU.md),
          decoration: BoxDecoration(
            color: _kCardBg,
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
              Row(children: [
                _SectionIcon(Icons.qr_code_scanner),
                SizedBox(width: SU.sm),
                Text('Scan to Issue',
                    style: TextStyle(
                        fontSize:   SU.textMd,
                        fontWeight: FontWeight.w700,
                        color:      Colors.black87)),
              ]),
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
                        _barcodeCtrl.text.isNotEmpty
                            ? _barcodeCtrl.text
                            : 'Scan a barcode...',
                        style: TextStyle(
                          fontSize: SU.textMd,
                          color:    _barcodeCtrl.text.isNotEmpty
                              ? Colors.black87 : Colors.black38,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(width: SU.sm),
                  _ScanButton(onTap: _scanNonConsumable),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: SU.sm),

        if (_isScanning)
          Padding(
            padding: EdgeInsets.all(SU.md),
            child: const CircularProgressIndicator(color: _kPrimary),
          ),

        ..._scannedItems.asMap().entries.map((entry) {
          final i    = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: SU.sm),
            child: _ScannedItemCard(
              item:      item,
              onDismiss: () => setState(() => _scannedItems.removeAt(i)),
            ),
          );
        }),

        if (_scannedItems.isNotEmpty) ...[
          GestureDetector(
            onTap: _scanNonConsumable,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: SU.lg, vertical: SU.sm),
              decoration: BoxDecoration(
                color:        _kCardBg,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: _kBorder),
              ),
              child: Text('+ Add another',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:      Colors.black87,
                      fontSize:   SU.textMd)),
            ),
          ),
          SizedBox(height: SU.md),
          _TotalConfirmBar(
            total:        _scannedItems.length,
            confirmLabel: 'Confirm Issue',
            isLoading:    _isIssuing,
            disabled:     _scannedItems.isEmpty,
            onConfirm:    _confirmIssue,
            isStockIn:    true,
          ),
        ],

        if (_scannedItems.isEmpty && !_isScanning)
          Padding(
            padding: EdgeInsets.all(SU.xl),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_scanner,
                      size:  36,
                      color: Colors.black.withOpacity(0.2)),
                ),
                SizedBox(height: SU.sm),
                Text(
                  'Scan a barcode to issue a\nnon-consumable item.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color:    Colors.black45,
                      fontSize: SU.textSm),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
// CART ENTRY
// ══════════════════════════════════════════════════════
class _CartEntry {
  final ItemModel item;
  int    qty;
  String selectedUnit;

  _CartEntry({
    required this.item,
    required this.qty,
    required this.selectedUnit,
  });

  /// Base quantity — sent to backend for stock calculation
  double get baseQty => UOM.toBase(
    qty.toDouble(),
    selectedUnit,
    conversionFactor: item.conversionFactor,
  );

  /// Display quantity — stored in transaction for history
  double get displayQty => qty.toDouble();

  /// Display unit — stored in transaction for history
  String get displayUnit => selectedUnit;

  /// Stock in currently selected unit (for the stock column)
  String get stockInSelectedUnit {
    final converted = UOM.fromBase(
      item.quantity,
      selectedUnit,
      conversionFactor: item.conversionFactor,
    );
    return UOM.formatDisplay(converted, selectedUnit);
  }

  /// Secondary hint — "= X pcs" when unit is pack, or "= X pack" when pcs
  String? get packHint => UOM.packHint(
    qty.toDouble(),
    selectedUnit,
    item.conversionFactor,
  );
}

// ══════════════════════════════════════════════════════
// CONSUMABLE ROW
// ══════════════════════════════════════════════════════
class _ConsumableRow extends StatelessWidget {
  final ItemModel   item;
  final bool        isLast;
  final bool        isStockIn;
  final bool        inCart;
  final _CartEntry? cartEntry;
  final VoidCallback onAdd;
  final VoidCallback onDelete;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final void Function(String) onUnitChange;

  const _ConsumableRow({
    required this.item,
    required this.isLast,
    required this.isStockIn,
    required this.inCart,
    required this.cartEntry,
    required this.onAdd,
    required this.onDelete,
    required this.onInc,
    required this.onDec,
    required this.onUnitChange,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    // Available units — includes 'pack' when conversionFactor > 1
    final availableUnits = UOM.unitsFor(
      item.unitType,
      conversionFactor: item.conversionFactor,
    );
    final hasMultiUnit = availableUnits.length > 1;

    // Stock display: show in selected unit if in cart, else preferred unit
    String stockDisplay;
    if (inCart && cartEntry != null) {
      stockDisplay = cartEntry!.stockInSelectedUnit;
    } else {
      stockDisplay = UOM.formatDisplay(
        UOM.fromBase(
          item.quantity,
          item.preferredUnit,
          conversionFactor: item.conversionFactor,
        ),
        item.preferredUnit,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _kFieldBg,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
            top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: SU.sm, horizontal: SU.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Col 1: Item name + image
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(item.imageUrl,
                          width: 28, height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _Thumb())
                      : _Thumb(),
                ),
                SizedBox(width: SU.xs),
                Expanded(
                  child: Text(item.itemName,
                      style: TextStyle(fontSize: SU.textXs),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),

          // Col 2: Stock (dynamic — changes with unit selection)
          Expanded(
            flex: 3,
            child: Text(
              stockDisplay,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: SU.textXs, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Col 3: Action
          Expanded(
            flex: 4,
            child: inCart && cartEntry != null
                ? _InCartWidget(
                    cartEntry:      cartEntry!,
                    availableUnits: availableUnits,
                    hasMultiUnit:   hasMultiUnit,
                    onInc:          onInc,
                    onDec:          onDec,
                    onDelete:       onDelete,
                    onUnitChange:   onUnitChange,
                  )
                : GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: SU.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: isStockIn ? _kStockIn : _kStockOut,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isStockIn
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size:  SU.textSm,
                          ),
                          SizedBox(width: 2),
                          Text(
                            isStockIn ? 'Add' : 'Out',
                            style: TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize:   SU.textXs),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// IN-CART WIDGET
// ══════════════════════════════════════════════════════
class _InCartWidget extends StatelessWidget {
  final _CartEntry   cartEntry;
  final List<String> availableUnits;
  final bool         hasMultiUnit;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onDelete;
  final void Function(String) onUnitChange;

  const _InCartWidget({
    required this.cartEntry,
    required this.availableUnits,
    required this.hasMultiUnit,
    required this.onInc,
    required this.onDec,
    required this.onDelete,
    required this.onUnitChange,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    final hint = cartEntry.packHint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Row 1: Unit chips (only if more than 1 unit available)
        if (hasMultiUnit) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: availableUnits.map((unit) {
                final selected = cartEntry.selectedUnit == unit;
                return Padding(
                  padding: EdgeInsets.only(right: SU.xs / 2),
                  child: GestureDetector(
                    onTap: () => onUnitChange(unit),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: SU.xs + 2, vertical: 3),
                      decoration: BoxDecoration(
                        color: selected ? _kPrimary : _kInnerCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _kPrimary : Colors.black26,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        unit,
                        style: TextStyle(
                          color:      selected ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textXs - 1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: SU.xs / 2),
        ],

// Row 2: [−] qty [+]  [X]
Row(
  mainAxisSize: MainAxisSize.max,        // ← was min
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _SmallBtn(
        icon:      Icons.remove,
        color:     Colors.transparent,
        iconColor: Colors.black54,
        onTap:     onDec),
    Flexible(                            // ← wrap in Flexible
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: SU.xs / 2),  // ← tighter padding
        child: FittedBox(                // ← auto-shrinks text to fit
          fit: BoxFit.scaleDown,
          child: Text(
            '${cartEntry.qty} ${cartEntry.selectedUnit}',
            style: TextStyle(
                fontSize:   SU.textSm,
                fontWeight: FontWeight.w800,
                color:      Colors.black87),
            maxLines: 1,
          ),
        ),
      ),
    ),
    _SmallBtn(
        icon:      Icons.add,
        color:     Colors.transparent,
        iconColor: Colors.black54,
        onTap:     onInc),
    SizedBox(width: SU.xs / 2),         // ← tighter gap before X
    GestureDetector(
      onTap: onDelete,
      child: Container(
        width:  SU.wp(0.055),
        height: SU.wp(0.055),
        decoration: BoxDecoration(
          color:        _kRemove,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.close,
            color: Colors.white, size: SU.textXs + 1),
      ),
    ),
  ],
),

        // Row 3: Pack hint — "= 48 pcs" or "= 2 pack"
        if (hint != null) ...[
          SizedBox(height: SU.xs / 2),
          Text(
            hint,
            style: TextStyle(
                fontSize: SU.textXs - 1, color: Colors.black38),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════

class _ScannedItemCard extends StatelessWidget {
  final ItemScanResultModel item;
  final VoidCallback        onDismiss;

  const _ScannedItemCard({required this.item, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      padding: EdgeInsets.all(SU.md),
      decoration: BoxDecoration(
        color: _kCardBg,
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
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kInnerCard, shape: BoxShape.circle),
                child: Icon(Icons.close, size: 16, color: Colors.black54),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: _kInnerCard,
                borderRadius: BorderRadius.circular(SU.radiusLg),
              ),
              child: item.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(SU.radiusLg),
                      child: Image.network(item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              size:  SU.xl,
                              color: Colors.black26)))
                  : Icon(Icons.inventory_2_outlined,
                      size: SU.xl, color: Colors.black26),
            ),
          ),
          SizedBox(height: SU.sm),
          _CardLabel('Item Name'),
          SizedBox(height: SU.xs),
          _CardReadOnly(text: item.itemName),
          SizedBox(height: SU.sm),
          _CardLabel('Item Type'),
          SizedBox(height: SU.xs),
          _CardReadOnly(text: item.itemType),
        ],
      ),
    );
  }
}

class _TotalConfirmBar extends StatelessWidget {
  final int        total;
  final String     confirmLabel;
  final bool       isLoading;
  final bool       disabled;
  final bool       isStockIn;
  final VoidCallback onConfirm;

  const _TotalConfirmBar({
    required this.total,
    required this.confirmLabel,
    required this.isLoading,
    required this.disabled,
    required this.isStockIn,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: SU.md, vertical: SU.md),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Items:',
                  style: TextStyle(
                      fontSize: SU.textSm, color: Colors.black54)),
              Text(
                '$total',
                style: TextStyle(
                    fontSize:   SU.textXl * 1.1,
                    fontWeight: FontWeight.w800,
                    color:      Colors.black87),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: (disabled || isLoading) ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor:        isStockIn ? _kStockIn : _kStockOut,
                disabledBackgroundColor: Colors.grey.shade300,
                shape:                  const StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: SU.lg),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isStockIn
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size:  SU.iconSm,
                        ),
                        SizedBox(width: SU.xs),
                        Text(confirmLabel,
                            style: TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize:   SU.textSm),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String       label;
  final bool         isActive;
  final VoidCallback onTap;

  const _TabPill(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: SU.md, vertical: SU.xs + 4),
        decoration: BoxDecoration(
          color: isActive ? _kStockIn : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(label,
            style: TextStyle(
                color:      isActive ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize:   SU.textSm)),
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  final IconData icon;
  const _SectionIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: _kPrimary, borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, color: Colors.white, size: SU.iconSm),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return ElevatedButton.icon(
      onPressed: onTap,
      icon:  const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white),
      label: Text('Scan',
          style: TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w700,
              fontSize:   SU.textMd)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kStockIn,
        shape:           const StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: SU.md, vertical: 14),
        elevation: 0,
      ),
    );
  }
}

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

class _CardReadOnly extends StatelessWidget {
  final String text;
  const _CardReadOnly({required this.text});
  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: SU.sm, horizontal: SU.sm),
      decoration: BoxDecoration(
        color:        _kFieldBg,
        borderRadius: BorderRadius.circular(SU.radius),
        border:       Border.all(color: _kBorder),
      ),
      child: Text(text,
          style: TextStyle(fontSize: SU.textSm),
          overflow: TextOverflow.ellipsis),
    );
  }
}

class _Thumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: _kCardBg, borderRadius: BorderRadius.circular(6)),
      child: const Icon(Icons.inventory_2_outlined,
          size: 14, color: Colors.black45),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final Color    iconColor;
  final VoidCallback onTap;

  const _SmallBtn({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  SU.wp(0.07),
        height: SU.wp(0.07),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: SU.textMd, color: iconColor),
      ),
    );
  }
}