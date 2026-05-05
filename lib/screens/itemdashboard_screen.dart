import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';
import '../utils/uom_helper.dart';
import '../widgets/kondo_app_bar.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';
import '../widgets/confirm_dialog.dart';
import 'add_item_screen.dart';
import 'issued_items_screen.dart';
import 'stock_inout_screen.dart';

// ── Palette (matches KeyDashboard modal) ─────────────────
const _kModalBg     = Color(0xFFF2EADF);
const _kModalCardBg = Color(0xFFE8DDD0);
const _kFieldBg     = Colors.white;
const _kBorderColor = Colors.black38;

class ItemsScreen extends StatefulWidget {
  final String token;
  const ItemsScreen({super.key, required this.token});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late final ItemService _itemService;
  List<ItemModel> _allItems      = [];
  List<ItemModel> _filteredItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _itemService = ItemService(token: widget.token);
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _itemService.getAllItems();
      setState(() {
        _allItems      = items;
        _filteredItems = items;
        _isLoading     = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
        ));
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filteredItems = _allItems
          .where((item) =>
              item.itemName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showViewModal(ItemModel item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _ItemViewModal(
        item:        item,
        itemService: _itemService,
        onUpdated:   _loadItems,
        onDeleted:   _loadItems,
      ),
    );
  }

  Future<void> _goToAddItem() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(token: widget.token)),
    );
    if (result == true) _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Column(
      children: [
        KondoAppBar(title: 'Items'),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(SU.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SU.hp(0.015)),

                // ── Action Cards Row ──────────────────
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon:  Icons.add_box_outlined,
                        label: 'Add Item',
                        onTap: _goToAddItem,
                      ),
                    ),
                    SizedBox(width: SU.sm),
                    Expanded(
                      child: _ActionCard(
                        icon:  Icons.output_outlined,
                        label: 'Issued Item',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                IssuedItemsScreen(token: widget.token),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: SU.sm),
                    Expanded(
                      child: _ActionCard(
                        icon:  Icons.swap_vert_outlined,
                        label: 'Stock In/Out',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StockInOutScreen(token: widget.token),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: SU.hp(0.02)),

                // ── Item List Header + Search ──────────
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.primaryColorValue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2,
                          color: Colors.white, size: 16),
                    ),
                    SizedBox(width: SU.xs),
                    Text(
                      'Item List',
                      style: TextStyle(
                        fontSize:   SU.textLg,
                        fontWeight: FontWeight.w700,
                        color:      Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: SU.wp(0.38),
                      height: 38,
                      child: TextField(
                        onChanged: _onSearch,
                        decoration: InputDecoration(
                          hintText:   '',
                          prefixIcon: Icon(Icons.search,
                              size: SU.iconSm, color: Colors.black45),
                          filled:    true,
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

                SizedBox(height: SU.hp(0.015)),

                // ── Table ─────────────────────────────
                _isLoading
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(SU.xl),
                          child: const CircularProgressIndicator(
                            color: Color(AppConstants.primaryColorValue),
                          ),
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(SU.xl),
                              child: Text('No items found.',
                                  style: TextStyle(
                                      color:    Colors.grey,
                                      fontSize: SU.textMd)),
                            ),
                          )
                        : _ItemTable(
                            items:  _filteredItems,
                            onView: _showViewModal,
                          ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Action Card ────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: SU.actionCardH,
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(SU.radiusLg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: SU.xl, color: Colors.black87),
            SizedBox(height: SU.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   SU.textSm,
                fontWeight: FontWeight.w700,
                color:      Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item Table ─────────────────────────────────────────
class _ItemTable extends StatelessWidget {
  final List<ItemModel>          items;
  final void Function(ItemModel) onView;

  const _ItemTable({required this.items, required this.onView});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: SU.sm, horizontal: SU.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('Item',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Quantity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Status',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Action',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   SU.textSm)),
                ),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            final item   = entry.value;
            return _ItemTableRow(
              item:   item,
              isLast: isLast,
              onView: () => onView(item),
            );
          }),
        ],
      ),
    );
  }
}

// ── Item Table Row ─────────────────────────────────────
class _ItemTableRow extends StatelessWidget {
  final ItemModel    item;
  final bool         isLast;
  final VoidCallback onView;

  const _ItemTableRow({
    required this.item,
    required this.isLast,
    required this.onView,
  });

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
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(item.imageUrl,
                          width: 30, height: 30, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderThumb())
                      : _PlaceholderThumb(),
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
          Expanded(
            flex: 3,
            child: Text(
              item.quantityDisplay,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: SU.textXs),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(child: _StatusBadge(status: item.stockStatus)),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: GestureDetector(
                onTap: onView,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: SU.sm, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.successColorValue),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('View',
                      style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize:   SU.textXs)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          size: 14, color: Colors.black45),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    Color color;
    switch (status) {
      case 'High':
        color = const Color(AppConstants.successColorValue);
        break;
      case 'Medium':
        color = const Color(AppConstants.primaryColorValue);
        break;
      case 'Low':
        color = Colors.orange.shade700;
        break;
      case 'OutOfStock':
        color = Colors.red.shade600;
        break;
      default:
        color = Colors.grey;
    }
    final label = status == 'OutOfStock' ? 'Out-of-stock' : status;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SU.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w600,
              fontSize:   SU.textXs)),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ITEM VIEW MODAL  (redesigned — matches KeyDashboard)
// ═══════════════════════════════════════════════════════
class _ItemViewModal extends StatefulWidget {
  final ItemModel    item;
  final ItemService  itemService;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const _ItemViewModal({
    required this.item,
    required this.itemService,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<_ItemViewModal> createState() => _ItemViewModalState();
}

class _ItemViewModalState extends State<_ItemViewModal> {
  bool _isEditing  = false;
  bool _isSaving   = false;
  bool _isDeleting = false;

  // Text controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _descriptionCtrl;

  // Editable numeric values (in preferredUnit)
  late double _quantity;
  late double _minStock;
  late double _maxStock;

  // Dropdown values
  String? _unitType;
  String? _preferredUnit;
  late DateTime _selectedDate;

  static String _fmtVal(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static const List<String> _unitTypeOptions    = ['Liquid', 'Solid', 'Count'];

  List<String> get _preferredUnitOptions =>
      UOM.unitsFor(_unitType ?? widget.item.unitType);

  @override
  void initState() {
    super.initState();
    final item        = widget.item;
    _nameCtrl         = TextEditingController(text: item.itemName);
    _barcodeCtrl      = TextEditingController(text: item.barcode);
    _descriptionCtrl  = TextEditingController(text: item.description);
    _quantity         = item.quantityInPreferred;
    _minStock         = item.minStockInPreferred;
    _maxStock         = item.maxStockInPreferred;
    _unitType         = item.unitType.isNotEmpty ? item.unitType : null;
    _preferredUnit    = item.preferredUnit;
    _selectedDate     = item.date;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────
  Future<void> _onSaveTap() async {
    final confirmed = await ConfirmDialog.showSave(context);
    if (!confirmed) return;
    _save();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final pUnit  = _preferredUnit ?? widget.item.preferredUnit;
      final cf     = widget.item.conversionFactor;

      await widget.itemService.updateItem(widget.item.id, {
        'barcode':          _barcodeCtrl.text.trim(),
        'itemName':         _nameCtrl.text.trim(),
        'itemType':         widget.item.itemType,
        'unitType':         _unitType         ?? widget.item.unitType,
        'baseUnit':         widget.item.baseUnit,
        'preferredUnit':    pUnit,
        'conversionFactor': cf,
        'quantity': UOM.toBase(_quantity,  pUnit, conversionFactor: cf),
        'minStock': UOM.toBase(_minStock,  pUnit, conversionFactor: cf),
        'maxStock': UOM.toBase(_maxStock,  pUnit, conversionFactor: cf),
        'description': _descriptionCtrl.text.trim(),
        'imageUrl':    widget.item.imageUrl,
        'date':        _selectedDate.toIso8601String(),
      });
      widget.onUpdated();
      if (mounted) {
        setState(() { _isEditing = false; _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Item updated successfully!'),
          backgroundColor: Color(AppConstants.successColorValue),
        ));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600));
      }
    }
  }

  // ── Delete ─────────────────────────────────────────────
  Future<void> _onDeleteTap() async {
    final confirmed = await ConfirmDialog.showDelete(
      context,
      message: 'Are you sure you want to delete "${widget.item.itemName}"?'
               ' This action cannot be undone.',
    );
    if (!confirmed) return;
    _delete();
  }

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    try {
      await widget.itemService.deleteItem(widget.item.id);
      widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600));
      }
    }
  }

  Future<void> _pickDate() async {
    if (!_isEditing) return;
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate,
      firstDate:   DateTime(2000),
      lastDate:    DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(AppConstants.primaryColorValue)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    final size          = MediaQuery.of(context).size;
    final isConsumable  = widget.item.itemType == 'Consumable';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: SU.md,
        vertical:   SU.hp(0.02),
      ),
      child: Container(
        width: size.width * 0.95,
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
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
            // ── Header ────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: _kModalCardBg,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(SU.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_isEditing) ...[
                          _ModalBtn(
                            label: _isSaving ? '...' : 'Save',
                            color: const Color(AppConstants.primaryColorValue),
                            onTap: _isSaving ? null : _onSaveTap,
                          ),
                          _ModalBtn(
                            label: _isDeleting ? '...' : 'Delete',
                            color: Colors.red.shade500,
                            onTap: _isDeleting ? null : _onDeleteTap,
                          ),
                          _ModalBtn(
                            label: 'Cancel',
                            color: Colors.grey.shade600,
                            onTap: () => setState(() => _isEditing = false),
                          ),
                        ] else ...[
                          _ModalBtn(
                            label: 'Edit',
                            color: const Color(AppConstants.primaryColorValue),
                            onTap: () => setState(() => _isEditing = true),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: Colors.black54, size: 24),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(SU.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Item summary card ──────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kModalCardBg,
                        borderRadius: BorderRadius.circular(SU.radius),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: widget.item.imageUrl.isNotEmpty
                                ? Image.network(
                                    widget.item.imageUrl,
                                    width: 56, height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _SummaryThumb(),
                                  )
                                : _SummaryThumb(),
                          ),
                          SizedBox(width: SU.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.itemName,
                                  style: const TextStyle(
                                    fontSize:   15,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.item.itemType,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(status: widget.item.stockStatus),
                        ],
                      ),
                    ),

                    SizedBox(height: SU.md),

                    // ── Item Name + Barcode ────────────
                    _ModalRow(
                      leftLabel:  'Item Name',
                      rightLabel: isConsumable ? '' : 'Barcode',
                      leftChild: _isEditing
                          ? _ModalTextField(controller: _nameCtrl)
                          : _ModalReadOnly(text: widget.item.itemName),
                      rightChild: isConsumable
                          ? const SizedBox.shrink()
                          : _ModalReadOnly(
                              text: _barcodeCtrl.text.isEmpty
                                  ? '—' : _barcodeCtrl.text),
                    ),

                    if (isConsumable) ...[
                      SizedBox(height: SU.sm),

                      // ── Unit Type + Preferred Unit ───
                      _ModalRow(
                        leftLabel:  'Unit Type',
                        rightLabel: 'Preferred Unit',
                        leftChild: _isEditing
                            ? _ModalDropdownField(
                                value:     _unitType,
                                items:     _unitTypeOptions,
                                onChanged: (v) => setState(() {
                                  _unitType      = v;
                                  // reset preferred if no longer valid
                                  final newUnits = UOM.unitsFor(v ?? 'Count');
                                  if (!newUnits.contains(_preferredUnit)) {
                                    _preferredUnit = newUnits.first;
                                  }
                                }),
                              )
                            : _ModalReadOnly(
                                text: widget.item.unitType.isNotEmpty
                                    ? widget.item.unitType : '—'),
                        rightChild: _isEditing
                            ? _ModalDropdownField(
                                value:     _preferredUnit,
                                items:     _preferredUnitOptions,
                                onChanged: (v) =>
                                    setState(() => _preferredUnit = v),
                              )
                            : _ModalReadOnly(text: widget.item.preferredUnit),
                      ),

                      SizedBox(height: SU.sm),

                      // ── Quantity ───────────────────────
                      _ModalLabel('Quantity (${_preferredUnit ?? widget.item.preferredUnit})'),
                      SizedBox(height: SU.xs),
                      _isEditing
                          ? _StepperField(
                              value:     _quantity,
                              step:      1,
                              min:       0,
                              onChanged: (v) => setState(() => _quantity = v),
                            )
                          : _ModalReadOnly(text: _fmtVal(_quantity)),

                      SizedBox(height: SU.sm),

                      // ── Min / Max Stock ────────────────
                      _ModalRow(
                        leftLabel:  'Min Stock (${_preferredUnit ?? widget.item.preferredUnit})',
                        rightLabel: 'Max Stock (${_preferredUnit ?? widget.item.preferredUnit})',
                        leftChild: _isEditing
                            ? _StepperField(
                                value:     _minStock,
                                step:      1,
                                min:       0,
                                onChanged: (v) => setState(() => _minStock = v),
                              )
                            : _ModalReadOnly(text: _fmtVal(_minStock)),
                        rightChild: _isEditing
                            ? _StepperField(
                                value:     _maxStock,
                                step:      1,
                                min:       0,
                                onChanged: (v) => setState(() => _maxStock = v),
                              )
                            : _ModalReadOnly(text: _fmtVal(_maxStock)),
                      ),
                    ],

                    // ── NonConsumable: Description ───────
                    if (!isConsumable) ...[
                      SizedBox(height: SU.sm),
                      _ModalLabel('Description'),
                      SizedBox(height: SU.xs),
                      _isEditing
                          ? _ModalTextField(
                              controller: _descriptionCtrl,
                              maxLines:   4,
                            )
                          : _ModalReadOnly(
                              text:     _descriptionCtrl.text.isNotEmpty
                                  ? _descriptionCtrl.text : '—',
                              maxLines: 4,
                            ),
                    ],

                    SizedBox(height: SU.sm),

                    // ── Date ──────────────────────────────
                    _ModalLabel('Date'),
                    SizedBox(height: SU.xs),
                    GestureDetector(
                      onTap: _pickDate,
                      child: _ModalReadOnly(
                        text:      DateFormat('yyyy-MM-dd').format(_selectedDate),
                        isEditing: _isEditing,
                      ),
                    ),

                    SizedBox(height: SU.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Thumbnail ──────────────────────────────────
class _SummaryThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: const Color(AppConstants.backgroundColorValue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          size: 26, color: Colors.black26),
    );
  }
}

// ── Stepper Field ──────────────────────────────────────
class _StepperField extends StatelessWidget {
  final double   value;
  final double   step;
  final double   min;
  final void Function(double) onChanged;

  const _StepperField({
    required this.value,
    required this.step,
    required this.min,
    required this.onChanged,
  });

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:        _kFieldBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorderColor),
      ),
      child: Row(
        children: [
          // Decrement
          GestureDetector(
            onTap: () {
              if (value - step >= min) onChanged(value - step);
            },
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFE8DDD0),
                borderRadius: BorderRadius.only(
                  topLeft:    Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: const Icon(Icons.remove, size: 18, color: Colors.black54),
            ),
          ),
          // Value
          Expanded(
            child: Center(
              child: Text(
                _fmt(value),
                style: TextStyle(
                  fontSize:   SU.textMd,
                  fontWeight: FontWeight.w700,
                  color:      Colors.black87,
                ),
              ),
            ),
          ),
          // Increment
          GestureDetector(
            onTap: () => onChanged(value + step),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(AppConstants.primaryColorValue),
                borderRadius: const BorderRadius.only(
                  topRight:    Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modal Helper Widgets ───────────────────────────────

class _ModalRow extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final Widget leftChild;
  final Widget rightChild;

  const _ModalRow({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftChild,
    required this.rightChild,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _ModalLabel(leftLabel)),
          const SizedBox(width: 12),
          Expanded(child: _ModalLabel(rightLabel)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: leftChild),
          const SizedBox(width: 12),
          Expanded(child: rightChild),
        ]),
      ],
    );
  }
}

class _ModalLabel extends StatelessWidget {
  final String text;
  const _ModalLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
  );
}

class _ModalBtn extends StatelessWidget {
  final String        label;
  final Color         color;
  final VoidCallback? onTap;

  const _ModalBtn({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: onTap != null ? color : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w600,
              fontSize:   12),
        ),
      ),
    );
  }
}

class _ModalTextField extends StatelessWidget {
  final TextEditingController controller;
  final int                   maxLines;

  const _ModalTextField({required this.controller, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      textAlign:    TextAlign.center,
      maxLines:     maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        filled:    true,
        fillColor: _kFieldBg,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(AppConstants.primaryColorValue), width: 1.5),
        ),
      ),
    );
  }
}

class _ModalDropdownField extends StatelessWidget {
  final String?                value;
  final List<String>           items;
  final void Function(String?) onChanged;

  const _ModalDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value:     value,
      onChanged: onChanged,
      isDense:   true,
      decoration: InputDecoration(
        filled:    true,
        fillColor: _kFieldBg,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(AppConstants.primaryColorValue), width: 1.5),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.black45, size: 18),
      dropdownColor: _kModalBg,
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(fontSize: 12))))
          .toList(),
    );
  }
}

class _ModalReadOnly extends StatelessWidget {
  final String text;
  final bool   isEditing;
  final int    maxLines;

  const _ModalReadOnly({
    required this.text,
    this.isEditing = false,
    this.maxLines  = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _kFieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing
              ? const Color(AppConstants.primaryColorValue)
              : _kBorderColor,
          width: isEditing ? 1.5 : 1,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines:  maxLines,
        overflow:  TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}