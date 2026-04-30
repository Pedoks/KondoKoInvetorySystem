import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import '../services/item_service.dart';
import '../services/cloudinary_service.dart';
import 'barcode_scanner_screen.dart';

class AddItemScreen extends StatefulWidget {
  final String token;

  const AddItemScreen({super.key, required this.token});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _mainFormKey       = GlobalKey<FormState>();
  final _barcodeCtrl       = TextEditingController();
  final _itemNameCtrl      = TextEditingController();
  final _minStockCtrl      = TextEditingController();
  final _maxStockCtrl      = TextEditingController();
  final _descriptionCtrl   = TextEditingController();

  String? _itemType; // 'Consumable' or 'NonConsumable'
  int     _quantity = 1;
  File?   _imageFile;
  bool    _isSubmitting = false;

  final List<_ExtraItemData> _extraItems = [];
  final _picker = ImagePicker();
  final _cloudinaryService = CloudinaryService();

  static const List<String> _itemTypeOptions = ['Consumable', 'Non-consumable'];

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _itemNameCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
    _descriptionCtrl.dispose();
    for (final e in _extraItems) e.dispose();
    super.dispose();
  }

  String get _itemTypeValue {
    if (_itemType == 'Non-consumable') return 'NonConsumable';
    return 'Consumable';
  }

  bool get _isConsumable => _itemType == 'Consumable' || _itemType == null;

  Future<void> _scanBarcode(TextEditingController ctrl) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() => ctrl.text = result);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImageIfSelected() async {
    if (_imageFile == null) return null;
    return await _cloudinaryService.uploadImage(_imageFile!);
  }

  Future<void> _onSaveItem() async {
    if (!_mainFormKey.currentState!.validate()) return;
    if (_itemType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Item Type.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = ItemService(token: widget.token);

      // Upload image to Cloudinary first
      String imageUrl = '';
      if (_imageFile != null) {
        imageUrl = await _cloudinaryService.uploadImage(_imageFile!) ?? '';
      }

      // Create main item
      await service.createItem({
        'barcode':     _barcodeCtrl.text.trim(),
        'itemName':    _itemNameCtrl.text.trim(),
        'itemType':    _itemTypeValue,
        'quantity':    _isConsumable ? _quantity : 1,
        'minStock':    _isConsumable
            ? (int.tryParse(_minStockCtrl.text) ?? 0) : 0,
        'maxStock':    _isConsumable
            ? (int.tryParse(_maxStockCtrl.text) ?? 0) : 0,
        'description': !_isConsumable ? _descriptionCtrl.text.trim() : '',
        'imageUrl':    imageUrl,
        'date':        DateTime.now().toIso8601String(),
      });

      // Create extra items
      for (final extra in _extraItems) {
        String extraImageUrl = '';
        if (extra.imageFile != null) {
          extraImageUrl =
              await _cloudinaryService.uploadImage(extra.imageFile!) ?? '';
        }
        final extraIsConsumable = extra.itemType != 'Non-consumable';
        await service.createItem({
          'barcode':     extra.barcodeCtrl.text.trim(),
          'itemName':    extra.itemNameCtrl.text.trim(),
          'itemType':    extra.itemType == 'Non-consumable'
              ? 'NonConsumable' : 'Consumable',
          'quantity':    extraIsConsumable ? extra.quantity : 1,
          'minStock':    0,
          'maxStock':    0,
          'description': '',
          'imageUrl':    extraImageUrl,
          'date':        DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addExtraItem() =>
      setState(() => _extraItems.add(_ExtraItemData()));

  void _removeExtraItem(int index) =>
      setState(() => _extraItems.removeAt(index));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final top  = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColorValue),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App Bar ──────────────────────────────
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
                  'Add Item',
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

          // ── Body ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.04,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.primaryColorValue),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory_2,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Item Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Main Form Card ────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.lightOrangeValue),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _mainFormKey,
                      child: Column(
                        children: [
                          // Barcode row — shown for NonConsumable always,
                          // hidden for Consumable (barcode optional)
                          if (_itemType == null || _itemType == 'Non-consumable')
                            Column(
                              children: [
                                _BarcodeRow(
                                  controller: _barcodeCtrl,
                                  onScanTap:  () =>
                                      _scanBarcode(_barcodeCtrl),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),

                          // Item Name
                          _KField(
                            controller: _itemNameCtrl,
                            hint: 'Item Name',
                            icon: Icons.inventory_outlined,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Required' : null,
                          ),
                          const SizedBox(height: 10),

                          // Item Type dropdown
                          _KDropdown(
                            value:     _itemType,
                            hint:      'Item Type',
                            icon:      Icons.category_outlined,
                            items:     _itemTypeOptions,
                            onChanged: (v) {
                              setState(() {
                                _itemType = v;
                                // Reset fields when type changes
                                _quantity = 1;
                                _minStockCtrl.clear();
                                _maxStockCtrl.clear();
                                _descriptionCtrl.clear();
                                _barcodeCtrl.clear();
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Select item type' : null,
                          ),
                          const SizedBox(height: 10),

                          // ── Consumable fields ──────
                          if (_itemType == 'Consumable') ...[
                            // Quantity row with +/- buttons
                            _QuantityRow(
                              quantity:    _quantity,
                              onDecrement: () {
                                if (_quantity > 1)
                                  setState(() => _quantity--);
                              },
                              onIncrement: () =>
                                  setState(() => _quantity++),
                            ),
                            const SizedBox(height: 10),

                            // Min Stock
                            _KField(
                              controller: _minStockCtrl,
                              hint: 'Min Stock',
                              icon: Icons.align_vertical_bottom_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),

                            // Max Stock
                            _KField(
                              controller: _maxStockCtrl,
                              hint: 'Max Stock',
                              icon: Icons.align_vertical_top_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                          ],

                          // ── NonConsumable fields ───
                          if (_itemType == 'Non-consumable') ...[
                            // Description
                            TextFormField(
                              controller: _descriptionCtrl,
                              maxLines:   4,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87),
                              decoration: _kInputDeco(
                                  'Item Description:', Icons.description_outlined),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                          ],

                          // ── Item Picture ───────────
                          _ItemPictureSection(
                            imageFile:   _imageFile,
                            onPickImage: _pickImage,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Extra Item Cards ──────────────
                  ..._extraItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ExtraItemCard(
                        key:      ValueKey(e.id),
                        data:     e,
                        onRemove: () => _removeExtraItem(i),
                        onPickImage: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1024,
                            imageQuality: 80,
                          );
                          if (picked != null && mounted) {
                            setState(() =>
                                e.imageFile = File(picked.path));
                          }
                        },
                        onScanTap: () => _scanBarcode(e.barcodeCtrl),
                        onTypeChanged: (v) =>
                            setState(() => e.itemType = v),
                        onQuantityChanged: (q) =>
                            setState(() => e.quantity = q),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom Buttons ──────────────────────────────
      bottomNavigationBar: Container(
        color: const Color(AppConstants.backgroundColorValue),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _onSaveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(AppConstants.successColorValue),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          'Save Item',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _addExtraItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(AppConstants.lightOrangeValue),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text(
                    '+ Add another',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item Picture Section ───────────────────────────────
class _ItemPictureSection extends StatelessWidget {
  final File?        imageFile;
  final VoidCallback onPickImage;

  const _ItemPictureSection({
    required this.imageFile,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(AppConstants.primaryColorValue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_outlined,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
            const Text(
              'Item Picture',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: const Color(AppConstants.backgroundColorValue),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black26),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      imageFile!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: 32, color: Colors.black38),
                      SizedBox(height: 8),
                      Text(
                        'Upload Picture',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Quantity Row ───────────────────────────────────────
class _QuantityRow extends StatelessWidget {
  final int          quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityRow({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.backgroundColorValue),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined,
              color: Colors.black38, size: 18),
          const SizedBox(width: 8),
          const Text('Quantity',
              style: TextStyle(color: Colors.black38, fontSize: 14)),
          const Spacer(),
          // Minus
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.remove, size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Plus
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(AppConstants.primaryColorValue),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add,
                  size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 4),
          const Text('pcs',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ── Extra Item Card ────────────────────────────────────
class _ExtraItemCard extends StatelessWidget {
  final _ExtraItemData          data;
  final VoidCallback            onRemove;
  final VoidCallback            onPickImage;
  final VoidCallback            onScanTap;
  final void Function(String?)  onTypeChanged;
  final void Function(int)      onQuantityChanged;

  const _ExtraItemCard({
    super.key,
    required this.data,
    required this.onRemove,
    required this.onPickImage,
    required this.onScanTap,
    required this.onTypeChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isConsumable = data.itemType != 'Non-consumable';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header + X
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.primaryColorValue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2,
                        color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Item Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close,
                    size: 22, color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barcode (for NonConsumable)
          if (data.itemType == 'Non-consumable' || data.itemType == null)
            Column(
              children: [
                _BarcodeRow(
                  controller: data.barcodeCtrl,
                  onScanTap:  onScanTap,
                ),
                const SizedBox(height: 10),
              ],
            ),

          // Item Name
          _KField(
            controller: data.itemNameCtrl,
            hint: 'Item Name',
            icon: Icons.inventory_outlined,
          ),
          const SizedBox(height: 10),

          // Item Type
          _KDropdown(
            value:     data.itemType,
            hint:      'Item Type',
            icon:      Icons.category_outlined,
            items:     const ['Consumable', 'Non-consumable'],
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 10),

          // Quantity for Consumable
          if (isConsumable)
            Column(
              children: [
                _QuantityRow(
                  quantity:    data.quantity,
                  onDecrement: () {
                    if (data.quantity > 1) {
                      onQuantityChanged(data.quantity - 1);
                    }
                  },
                  onIncrement: () =>
                      onQuantityChanged(data.quantity + 1),
                ),
                const SizedBox(height: 10),
              ],
            ),

          // Item Picture
          _ItemPictureSection(
            imageFile:   data.imageFile,
            onPickImage: onPickImage,
          ),
        ],
      ),
    );
  }
}

// ── Barcode Row ────────────────────────────────────────
class _BarcodeRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback          onScanTap;

  const _BarcodeRow({
    required this.controller,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final hasValue = value.text.isNotEmpty;
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                readOnly:   true,
                style: const TextStyle(fontSize: 14),
                decoration: _kInputDeco(
                  hasValue ? value.text : 'Scan Barcode', null,
                ).copyWith(
                  hintStyle: TextStyle(
                    color: hasValue ? Colors.black87 : Colors.black38,
                    fontSize: 14,
                    fontWeight:
                        hasValue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onScanTap,
              icon: const Icon(Icons.qr_code_scanner,
                  size: 16, color: Colors.white),
              label: Text(
                hasValue ? 'Rescan' : 'Scan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasValue
                    ? Colors.orange.shade700
                    : const Color(AppConstants.successColorValue),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 15),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Text Field ─────────────────────────────────────────
class _KField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     hint;
  final IconData?                  icon;
  final bool                       readOnly;
  final TextInputType              keyboardType;
  final String? Function(String?)? validator;

  const _KField({
    required this.controller,
    required this.hint,
    this.icon,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      readOnly:     readOnly,
      keyboardType: keyboardType,
      validator:    validator,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: _kInputDeco(hint, icon),
    );
  }
}

// ── Dropdown ───────────────────────────────────────────
class _KDropdown extends StatelessWidget {
  final String?                    value;
  final String                     hint;
  final IconData?                  icon;
  final List<String>               items;
  final void Function(String?)     onChanged;
  final String? Function(String?)? validator;

  const _KDropdown({
    required this.value,
    required this.hint,
    this.icon,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value:     value,
      validator: validator,
      onChanged: onChanged,
      decoration: _kInputDeco(hint, icon),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.black38),
      dropdownColor:
          const Color(AppConstants.backgroundColorValue),
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
    );
  }
}

// ── Shared Decoration ──────────────────────────────────
InputDecoration _kInputDeco(String hint, IconData? icon) {
  return InputDecoration(
    hintText:  hint,
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
    prefixIcon: icon != null
        ? Icon(icon, color: Colors.black38, size: 18)
        : null,
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
        color: Color(AppConstants.primaryColorValue), width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade400),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
    ),
  );
}

// ── Extra Item Data ────────────────────────────────────
class _ExtraItemData {
  final String id          = UniqueKey().toString();
  final barcodeCtrl        = TextEditingController();
  final itemNameCtrl       = TextEditingController();
  String? itemType;
  int     quantity         = 1;
  File?   imageFile;

  void dispose() {
    barcodeCtrl.dispose();
    itemNameCtrl.dispose();
  }
}