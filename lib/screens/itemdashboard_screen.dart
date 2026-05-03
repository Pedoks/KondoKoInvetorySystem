import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';
import 'add_item_screen.dart';
import 'issued_items_screen.dart';
import 'stock_inout_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filteredItems = _allItems.where((item) =>
        item.itemName.toLowerCase().contains(query.toLowerCase()),
      ).toList();
    });
  }

  void _showViewModal(ItemModel item) {
    showDialog(
      context: context,
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
      MaterialPageRoute(
        builder: (_) => AddItemScreen(token: widget.token),
      ),
    );
    if (result == true) _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        // ── Orange App Bar ──────────────────────────────
        _ItemsAppBar(),

        // ── Body ────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(size.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.015),

                // ── Action Cards Row ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon:  Icons.add_box_outlined,
                        label: 'Add Item',
                        onTap: _goToAddItem,
                      ),
                    ),
                    SizedBox(width: size.width * 0.03),
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
                    SizedBox(width: size.width * 0.03),
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

                SizedBox(height: size.height * 0.02),

                // ── Item List Header + Search ─────────────
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.primaryColorValue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Item List',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: size.width * 0.38,
                      height: 38,
                      child: TextField(
                        onChanged: _onSearch,
                        decoration: InputDecoration(
                          hintText:   '',
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

                SizedBox(height: size.height * 0.015),

                // ── Table ────────────────────────────────
                _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: Color(AppConstants.primaryColorValue),
                          ),
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No items found.',
                                  style: TextStyle(color: Colors.grey)),
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

// ── App Bar ────────────────────────────────────────────
class _ItemsAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: const Color(AppConstants.primaryColorValue),
      padding: EdgeInsets.only(
        top: topPadding + 12, bottom: 16, left: 16, right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text('k',
                    style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Items',
                style: TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined,
                color: Colors.white, size: 26),
          ),
        ],
      ),
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
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size.height * 0.12,
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: size.width * 0.08, color: Colors.black87),
            SizedBox(height: size.height * 0.006),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size.width * 0.030,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
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
  final List<ItemModel>            items;
  final void Function(ItemModel)   onView;

  const _ItemTable({required this.items, required this.onView});

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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text('Item',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Quantity',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Status',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Action',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Rows
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        border: const Border(
          top: BorderSide(color: Color(0xFFE8D5C0), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          // Item col: thumbnail + name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                // Small thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _PlaceholderThumb(),
                        )
                      : _PlaceholderThumb(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.itemName,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Quantity
          Expanded(
            flex: 2,
            child: Text(
              item.isConsumable
                  ? '${item.quantity} pcs'
                  : '${item.quantity} pc',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),

          // Status badge
          Expanded(
            flex: 3,
            child: Center(child: _StatusBadge(status: item.stockStatus)),
          ),

          // View button
          Expanded(
            flex: 2,
            child: Center(
              child: GestureDetector(
                onTap: onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.successColorValue),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
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

// ── Placeholder Thumbnail ──────────────────────────────
class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          size: 16, color: Colors.black45),
    );
  }
}

// ── Status Badge ───────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Item View Modal ────────────────────────────────────
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

  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _maxStockCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _barcodeCtrl;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl        = TextEditingController(text: item.itemName);
    _quantityCtrl    = TextEditingController(text: '${item.quantity}');
    _minStockCtrl    = TextEditingController(text: '${item.minStock}');
    _maxStockCtrl    = TextEditingController(text: '${item.maxStock}');
    _descriptionCtrl = TextEditingController(text: item.description);
    _barcodeCtrl     = TextEditingController(text: item.barcode);
    _selectedDate    = item.date;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
    _descriptionCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.itemService.updateItem(widget.item.id, {
        'barcode':     _barcodeCtrl.text.trim(),
        'itemName':    _nameCtrl.text.trim(),
        'itemType':    widget.item.itemType,
        'quantity':    int.tryParse(_quantityCtrl.text) ?? widget.item.quantity,
        'minStock':    int.tryParse(_minStockCtrl.text) ?? widget.item.minStock,
        'maxStock':    int.tryParse(_maxStockCtrl.text) ?? widget.item.maxStock,
        'description': _descriptionCtrl.text.trim(),
        'imageUrl':    widget.item.imageUrl,
        'date':        _selectedDate.toIso8601String(),
      });
      widget.onUpdated();
      if (mounted) {
        setState(() { _isEditing = false; _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item updated successfully!'),
            backgroundColor: Color(AppConstants.successColorValue),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red.shade600),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await widget.itemService.deleteItem(widget.item.id);
      widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red.shade600),
        );
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(AppConstants.primaryColorValue),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isConsumable = widget.item.itemType == 'Consumable';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical:   size.height * 0.06,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _isEditing
                      ? Row(
                          children: [
                            _ModalBtn(
                              label: _isSaving ? '...' : 'Save',
                              color: const Color(AppConstants.primaryColorValue),
                              onTap: _isSaving ? null : _save,
                            ),
                            const SizedBox(width: 8),
                            _ModalBtn(
                              label: _isDeleting ? '...' : 'Delete',
                              color: Colors.red.shade500,
                              onTap: _isDeleting ? null : _delete,
                            ),
                          ],
                        )
                      : _ModalBtn(
                          label: 'Edit',
                          color: const Color(AppConstants.successColorValue),
                          onTap: () => setState(() => _isEditing = true),
                        ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: Colors.black54, size: 24),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Item Image ────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: widget.item.imageUrl.isNotEmpty
                    ? Image.network(
                        widget.item.imageUrl,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ImagePlaceholder(),
                      )
                    : _ImagePlaceholder(),
              ),

              const SizedBox(height: 16),

              // ── Item Type (read-only) ─────────────
              _modalLabel('Item Type'),
              const SizedBox(height: 6),
              _ModalReadOnly(text: widget.item.itemType),

              const SizedBox(height: 12),

              // ── Item Name + Quantity ──────────────
              Row(
                children: [
                  Expanded(child: _modalLabel('Item Name')),
                  const SizedBox(width: 12),
                  Expanded(child: _modalLabel('Quantity')),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ModalTextField(
                      controller: _nameCtrl,
                      readOnly:   !_isEditing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModalTextField(
                      controller: _quantityCtrl,
                      readOnly:   !_isEditing,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Consumable-only: Min/Max Stock ────
              if (isConsumable) ...[
                Row(
                  children: [
                    Expanded(child: _modalLabel('Min Stock')),
                    const SizedBox(width: 12),
                    Expanded(child: _modalLabel('Max Stock')),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ModalTextField(
                        controller:   _minStockCtrl,
                        readOnly:     !_isEditing,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModalTextField(
                        controller:   _maxStockCtrl,
                        readOnly:     !_isEditing,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── NonConsumable-only: Description + Barcode ──
              if (!isConsumable) ...[
                _modalLabel('Description'),
                const SizedBox(height: 6),
                _ModalTextField(
                  controller: _descriptionCtrl,
                  readOnly:   !_isEditing,
                  maxLines:   3,
                ),
                const SizedBox(height: 12),

                _modalLabel('Barcode'),
                const SizedBox(height: 6),
                _ModalReadOnly(text: _barcodeCtrl.text.isEmpty
                    ? '—' : _barcodeCtrl.text),
                const SizedBox(height: 12),
              ],

              // ── Date ─────────────────────────────
              _modalLabel('Date'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: _ModalReadOnly(
                  text: DateFormat('yyyy-MM-dd').format(_selectedDate),
                  isEditing: _isEditing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: Colors.black87,
    ),
  );
}

// ── Image Placeholder ──────────────────────────────────
class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(AppConstants.backgroundColorValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.image_outlined,
          size: 48, color: Colors.black26),
    );
  }
}

// ── Modal Helpers ──────────────────────────────────────
class _ModalBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback? onTap;

  const _ModalBtn({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            )),
      ),
    );
  }
}

class _ModalTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final TextInputType keyboardType;
  final int maxLines;

  const _ModalTextField({
    required this.controller,
    required this.readOnly,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      readOnly:     readOnly,
      textAlign:    TextAlign.center,
      keyboardType: keyboardType,
      maxLines:     maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        filled:    true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 12),
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
            color: Color(AppConstants.primaryColorValue), width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ModalReadOnly extends StatelessWidget {
  final String text;
  final bool   isEditing;

  const _ModalReadOnly({required this.text, this.isEditing = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing
              ? const Color(AppConstants.primaryColorValue)
              : Colors.black26,
          width: isEditing ? 1.5 : 1,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}