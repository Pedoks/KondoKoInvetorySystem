import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import '../utils/screen_util.dart';
import '../utils/uom_helper.dart';
import '../widgets/kondo_app_bar.dart';
import '../services/item_service.dart';
import '../services/cloudinary_service.dart';
import 'barcode_scanner_screen.dart';

// ── Palette ──────────────────────────────────────────────
const _kCardBg    = Color(0xFFF2EADF);
const _kInnerCard = Color(0xFFE8DDD0);
const _kFieldBg   = Color(AppConstants.backgroundColorValue);
const _kPrimary   = Color(AppConstants.primaryColorValue);
const _kSuccess   = Color(AppConstants.successColorValue);

class AddItemScreen extends StatefulWidget {
  final String token;
  const AddItemScreen({super.key, required this.token});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _mainFormKey     = GlobalKey<FormState>();
  final _barcodeCtrl     = TextEditingController();
  final _itemNameCtrl    = TextEditingController();
  final _minStockCtrl    = TextEditingController();
  final _maxStockCtrl    = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _convFactorCtrl  = TextEditingController(text: '1');

  String? _itemType;
  String? _unitType;
  String? _inputUnit;
  double  _quantity   = 1;
  File?   _imageFile;
  bool    _isSubmitting = false;

  final List<_ExtraItemData> _extraItems = [];
  final _picker     = ImagePicker();
  final _cloudinary = CloudinaryService();

  static const List<String> _itemTypeOptions = ['Consumable', 'Non-consumable'];
  static const List<String> _unitTypeOptions = ['Liquid', 'Solid', 'Count'];

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _itemNameCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
    _descriptionCtrl.dispose();
    _convFactorCtrl.dispose();
    for (final e in _extraItems) e.dispose();
    super.dispose();
  }

  bool get _isConsumable    => _itemType == 'Consumable';
  bool get _isNonConsumable => _itemType == 'Non-consumable';

  String get _itemTypeValue =>
      _itemType == 'Non-consumable' ? 'NonConsumable' : 'Consumable';

  String get _baseUnit      => UOM.baseUnitFor(_unitType ?? 'Count');
  List<String> get _availableUnits => UOM.unitsFor(_unitType ?? 'Count');
  String get _preferredUnit => _inputUnit ?? _baseUnit;
  String get _stockHint     => _preferredUnit;

  Future<void> _scanBarcode(TextEditingController ctrl) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) setState(() => ctrl.text = result);
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  // ── Validation ─────────────────────────────────────────
  bool _validate() {
    if (_itemNameCtrl.text.trim().isEmpty) {
      _showError('Item Name is required.');
      return false;
    }
    if (_itemType == null) {
      _showError('Please select an Item Type.');
      return false;
    }
    if (_isNonConsumable && _barcodeCtrl.text.trim().isEmpty) {
      _showError('Barcode is required for Non-consumable items.');
      return false;
    }
    if (_isConsumable) {
      if (_unitType == null) {
        _showError('Please select a Unit Type.');
        return false;
      }
      if (_inputUnit == null) {
        _showError('Please select an Input Unit (e.g. L, mL, kg).');
        return false;
      }
      if (_minStockCtrl.text.trim().isEmpty) {
        _showError('Min Stock is required.');
        return false;
      }
      if (_maxStockCtrl.text.trim().isEmpty) {
        _showError('Max Stock is required.');
        return false;
      }
    }
    if (_isNonConsumable && _descriptionCtrl.text.trim().isEmpty) {
      _showError('Description is required for Non-consumable items.');
      return false;
    }
    if (_imageFile == null) {
      _showError('Item image is required. Please upload a picture.');
      return false;
    }
    return true;
  }

  Future<void> _onSaveItem() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final service  = ItemService(token: widget.token);
      final imageUrl = await _cloudinary.uploadImage(_imageFile!);
      final convFactor = double.tryParse(_convFactorCtrl.text) ?? 1;

      final baseQty = _isConsumable
          ? UOM.toBase(_quantity, _preferredUnit,
              conversionFactor: convFactor)
          : 1.0;
      final baseMin = _isConsumable
          ? UOM.toBase(double.tryParse(_minStockCtrl.text) ?? 0,
              _preferredUnit, conversionFactor: convFactor)
          : 0.0;
      final baseMax = _isConsumable
          ? UOM.toBase(double.tryParse(_maxStockCtrl.text) ?? 0,
              _preferredUnit, conversionFactor: convFactor)
          : 0.0;

      await service.createItem({
        'barcode':          _barcodeCtrl.text.trim(),
        'itemName':         _itemNameCtrl.text.trim(),
        'itemType':         _itemTypeValue,
        'unitType':         _isConsumable ? (_unitType ?? 'Count') : '',
        'baseUnit':         _isConsumable ? _baseUnit : 'pcs',
        'preferredUnit':    _isConsumable ? _preferredUnit : 'pcs',
        'conversionFactor': _isConsumable ? convFactor : 1,
        'quantity':         baseQty,
        'minStock':         baseMin,
        'maxStock':         baseMax,
        'description':      _isNonConsumable
            ? _descriptionCtrl.text.trim() : '',
        'imageUrl':         imageUrl,
        'date':             DateTime.now().toIso8601String(),
      });

      // Extra items (NonConsumable only)
      for (final extra in _extraItems) {
        // Validate extra
        if (extra.itemNameCtrl.text.trim().isEmpty) continue;
        String extraImageUrl = '';
        if (extra.imageFile != null) {
          extraImageUrl = await _cloudinary.uploadImage(extra.imageFile!);
        }
        await service.createItem({
          'barcode':          extra.barcodeCtrl.text.trim(),
          'itemName':         extra.itemNameCtrl.text.trim(),
          'itemType':         'NonConsumable',
          'unitType':         '',
          'baseUnit':         'pcs',
          'preferredUnit':    'pcs',
          'conversionFactor': 1,
          'quantity':         1,
          'minStock':         0,
          'maxStock':         0,
          'description':      extra.descriptionCtrl.text.trim(),
          'imageUrl':         extraImageUrl,
          'date':             DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600));
  }

  void _addExtraItem() =>
      setState(() => _extraItems.add(_ExtraItemData()));

  void _removeExtraItem(int i) =>
      setState(() => _extraItems.removeAt(i));

  @override
  Widget build(BuildContext context) {
    SU.init(context);

    return Scaffold(
      backgroundColor: _kFieldBg,
      body: Column(
        children: [
          KondoAppBar(title: 'Add Item', showBack: true, showLogo: false),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: SU.md, vertical: SU.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: SU.sm),

                  _SectionHeader(
                      icon: Icons.inventory_2, label: 'Item Information'),

                  SizedBox(height: SU.sm),

                  // ── Main form card (beige) ──────────
                  Container(
                    padding: EdgeInsets.all(SU.sm),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(SU.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withOpacity(0.07),
                          blurRadius: 14,
                          offset:     const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _mainFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barcode — NonConsumable or before type picked
                          if (_isNonConsumable || _itemType == null)
                            Column(children: [
                              _BarcodeRow(
                                controller: _barcodeCtrl,
                                onScanTap: () => _scanBarcode(_barcodeCtrl),
                              ),
                              SizedBox(height: SU.sm),
                            ]),

                          // Item Name
                          _KField(
                            controller: _itemNameCtrl,
                            hint:       'Item Name',
                            icon:       Icons.inventory_outlined,
                          ),
                          SizedBox(height: SU.sm),

                          // Item Type
                          _KDropdown(
                            value:    _itemType,
                            hint:     'Item Type',
                            icon:     Icons.category_outlined,
                            items:    _itemTypeOptions,
                            onChanged: (v) => setState(() {
                              _itemType  = v;
                              _unitType  = null;
                              _inputUnit = null;
                              _quantity  = 1;
                              _minStockCtrl.clear();
                              _maxStockCtrl.clear();
                              _descriptionCtrl.clear();
                              _barcodeCtrl.clear();
                              _convFactorCtrl.text = '1';
                            }),
                          ),
                          SizedBox(height: SU.sm),

                          // ── Consumable fields ───────────
                          if (_isConsumable) ...[
                            _KDropdown(
                              value:    _unitType,
                              hint:     'Unit Type',
                              icon:     Icons.straighten_outlined,
                              items:    _unitTypeOptions,
                              onChanged: (v) => setState(() {
                                _unitType  = v;
                                _inputUnit = null;
                                _quantity  = 1;
                              }),
                            ),
                            SizedBox(height: SU.sm),

                            if (_unitType != null) ...[
                              _UnitPickerRow(
                                label:         'Input Unit',
                                units:         _availableUnits,
                                selectedUnit:  _inputUnit,
                                onUnitChanged: (u) =>
                                    setState(() => _inputUnit = u),
                              ),
                              SizedBox(height: SU.xs),
                              Padding(
                                padding: EdgeInsets.only(left: SU.xs),
                                child: Text(
                                  'All values entered in $_preferredUnit'
                                  ' · stored in $_baseUnit',
                                  style: TextStyle(
                                      fontSize: SU.textXs,
                                      color:    Colors.black45),
                                ),
                              ),
                              SizedBox(height: SU.sm),
                            ],

                            if (_unitType == 'Count') ...[
                              _KField(
                                controller:  _convFactorCtrl,
                                hint:        'Pcs per box/pack (e.g. 12)',
                                icon:        Icons.format_list_numbered_outlined,
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: SU.sm),
                            ],

                            _QuantityRow(
                              quantity:    _quantity,
                              unit:        _preferredUnit,
                              onDecrement: () {
                                if (_quantity > 1)
                                  setState(() => _quantity--);
                              },
                              onIncrement: () =>
                                  setState(() => _quantity++),
                            ),
                            SizedBox(height: SU.sm),

                            _KField(
                              controller:  _minStockCtrl,
                              hint:        'Min Stock ($_stockHint)',
                              icon:        Icons.align_vertical_bottom_outlined,
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: SU.sm),

                            _KField(
                              controller:  _maxStockCtrl,
                              hint:        'Max Stock ($_stockHint)',
                              icon:        Icons.align_vertical_top_outlined,
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: SU.sm),
                          ],

                          // ── NonConsumable fields ─────────
                          if (_isNonConsumable) ...[
                            TextFormField(
                              controller: _descriptionCtrl,
                              maxLines:   4,
                              style: TextStyle(
                                  fontSize: SU.textMd,
                                  color:    Colors.black87),
                              decoration: _kInputDeco(
                                  'Item Description',
                                  Icons.description_outlined),
                            ),
                            SizedBox(height: SU.sm),
                          ],

                          // Item Picture
                          _ItemPictureSection(
                            imageFile:   _imageFile,
                            onPickImage: _pickImage,
                            isRequired:  true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Extra items (NonConsumable only) ──
                  if (_isNonConsumable)
                    ..._extraItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(top: SU.sm),
                        child: _ExtraItemCard(
                          key:         ValueKey(e.id),
                          data:        e,
                          onRemove:    () => _removeExtraItem(i),
                          onPickImage: () async {
                            final picked = await _picker.pickImage(
                              source:       ImageSource.gallery,
                              maxWidth:     1024,
                              imageQuality: 80,
                            );
                            if (picked != null && mounted) {
                              setState(() => e.imageFile = File(picked.path));
                            }
                          },
                          onScanTap: () => _scanBarcode(e.barcodeCtrl),
                        ),
                      );
                    }),

                  SizedBox(height: SU.xl),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: _kFieldBg,
        padding: EdgeInsets.fromLTRB(
            SU.md, SU.xs, SU.md, SU.md + SU.bottomSafe),
        child: Row(
          children: [
            // Save Item
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _onSaveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kSuccess,
                    shape:           const StadiumBorder(),
                    elevation:       0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text('Save Item',
                          style: TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize:   SU.textLg)),
                ),
              ),
            ),

            // Add Another — NonConsumable only
            if (_isNonConsumable) ...[
              SizedBox(width: SU.sm),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _addExtraItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kCardBg,
                      shape:           const StadiumBorder(),
                      elevation:       0,
                    ),
                    child: Text('+ Add another',
                        style: TextStyle(
                            color:      Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize:   SU.textMd)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Unit Picker Row ────────────────────────────────────
class _UnitPickerRow extends StatelessWidget {
  final String       label;
  final List<String> units;
  final String?      selectedUnit;
  final void Function(String) onUnitChanged;

  const _UnitPickerRow({
    required this.label,
    required this.units,
    required this.selectedUnit,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize:   SU.textSm,
                fontWeight: FontWeight.w600,
                color:      Colors.black87)),
        SizedBox(height: SU.xs),
        Row(
          children: units.map((unit) {
            final isSelected = selectedUnit == unit;
            return Padding(
              padding: EdgeInsets.only(right: SU.xs),
              child: GestureDetector(
                onTap: () => onUnitChanged(unit),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: SU.md, vertical: SU.xs + 2),
                  decoration: BoxDecoration(
                    color: isSelected ? _kPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _kPrimary : Colors.black26,
                    ),
                  ),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color:      isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize:   SU.textSm,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Extra Item Card (NonConsumable only) ───────────────
class _ExtraItemCard extends StatelessWidget {
  final _ExtraItemData data;
  final VoidCallback   onRemove;
  final VoidCallback   onPickImage;
  final VoidCallback   onScanTap;

  const _ExtraItemCard({
    super.key,
    required this.data,
    required this.onRemove,
    required this.onPickImage,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      padding: EdgeInsets.all(SU.sm),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(SU.radiusLg),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + X
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(
                  icon: Icons.inventory_2, label: 'Item Information'),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _kInnerCard,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close,
                      size: SU.iconSm - 4, color: Colors.black54),
                ),
              ),
            ],
          ),
          SizedBox(height: SU.sm),

          // Barcode
          _BarcodeRow(
              controller: data.barcodeCtrl, onScanTap: onScanTap),
          SizedBox(height: SU.sm),

          // Item Name
          _KField(
            controller: data.itemNameCtrl,
            hint:       'Item Name',
            icon:       Icons.inventory_outlined,
          ),
          SizedBox(height: SU.sm),

          // Description
          TextFormField(
            controller: data.descriptionCtrl,
            maxLines:   3,
            style: TextStyle(fontSize: SU.textMd, color: Colors.black87),
            decoration: _kInputDeco(
                'Item Description', Icons.description_outlined),
          ),
          SizedBox(height: SU.sm),

          // Picture
          _ItemPictureSection(
            imageFile:   data.imageFile,
            onPickImage: onPickImage,
            isRequired:  false,
          ),
        ],
      ),
    );
  }
}

// ── Item Picture Section ───────────────────────────────
class _ItemPictureSection extends StatelessWidget {
  final File?        imageFile;
  final VoidCallback onPickImage;
  final bool         isRequired;

  const _ItemPictureSection({
    required this.imageFile,
    required this.onPickImage,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(
                icon: Icons.image_outlined, label: 'Item Picture'),
            if (isRequired) ...[
              SizedBox(width: SU.xs),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: SU.xs + 2, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Required',
                    style: TextStyle(
                        color:    Colors.white,
                        fontSize: SU.textXs,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        SizedBox(height: SU.sm),
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              color:        imageFile != null ? null : _kInnerCard,
              borderRadius: BorderRadius.circular(SU.radiusLg),
              border: Border.all(
                color: imageFile != null
                    ? _kPrimary
                    : isRequired ? Colors.red.shade300 : Colors.black26,
                width: imageFile != null ? 2 : 1,
              ),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(SU.radiusLg),
                    child: Image.file(imageFile!, fit: BoxFit.cover))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size:  SU.xl,
                          color: isRequired
                              ? Colors.red.shade300 : Colors.black38),
                      SizedBox(height: SU.xs),
                      Text('Upload Picture',
                          style: TextStyle(
                              color:    isRequired
                                  ? Colors.red.shade400 : Colors.black45,
                              fontSize: SU.textSm)),
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
  final double       quantity;
  final String       unit;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityRow({
    required this.quantity,
    required this.unit,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(SU.radius),
        border:       Border.all(color: Colors.black26),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: SU.sm, vertical: SU.xs),
      child: Row(
        children: [
          Icon(Icons.shopping_cart_outlined,
              color: Colors.black38, size: SU.iconSm),
          SizedBox(width: SU.xs),
          Text('Quantity',
              style: TextStyle(
                  color: Colors.black38, fontSize: SU.textMd)),
          const Spacer(),
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                  color: Colors.black12, shape: BoxShape.circle),
              child: const Icon(Icons.remove, size: 16),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: SU.sm),
            child: Text(
              '${quantity.toInt()} $unit',
              style: TextStyle(
                  fontSize:   SU.textLg,
                  fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                  color: _kPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.add, size: 16, color: Colors.white),
            ),
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

  const _BarcodeRow(
      {required this.controller, required this.onScanTap});

  @override
  Widget build(BuildContext context) {
    SU.init(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final hasValue = value.text.isNotEmpty;
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(SU.radius),
                  border:       Border.all(color: Colors.black26),
                ),
                child: Text(
                  hasValue ? value.text : 'Scan Barcode',
                  style: TextStyle(
                    fontSize:   SU.textMd,
                    color:      hasValue ? Colors.black87 : Colors.black38,
                    fontWeight: hasValue
                        ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
            SizedBox(width: SU.sm),
            ElevatedButton.icon(
              onPressed: onScanTap,
              icon: Icon(Icons.qr_code_scanner,
                  size: SU.iconSm, color: Colors.white),
              label: Text(
                hasValue ? 'Rescan' : 'Scan',
                style: TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize:   SU.textMd),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasValue
                    ? Colors.orange.shade700 : _kSuccess,
                shape:     const StadiumBorder(),
                padding:   EdgeInsets.symmetric(
                    horizontal: SU.md, vertical: 15),
                elevation: 0,
              ),
            ),
          ],
        );
      },
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
    SU.init(context);
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        _kPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: SU.iconMd),
        ),
        SizedBox(width: SU.sm),
        Text(label,
            style: TextStyle(
                fontSize:   SU.textLg,
                fontWeight: FontWeight.w700,
                color:      Colors.black87)),
      ],
    );
  }
}

// ── Text Field ─────────────────────────────────────────
class _KField extends StatelessWidget {
  final TextEditingController controller;
  final String                hint;
  final IconData?             icon;
  final TextInputType         keyboardType;

  const _KField({
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: SU.textMd, color: Colors.black87),
      decoration: _kInputDeco(hint, icon),
    );
  }
}

// ── Dropdown ───────────────────────────────────────────
class _KDropdown extends StatelessWidget {
  final String?                value;
  final String                 hint;
  final IconData?              icon;
  final List<String>           items;
  final void Function(String?) onChanged;

  const _KDropdown({
    required this.value,
    required this.hint,
    this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value:     value,
      onChanged: onChanged,
      decoration: _kInputDeco(hint, icon),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.black38),
      dropdownColor: _kCardBg,
      style: TextStyle(fontSize: SU.textMd, color: Colors.black87),
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
        ? Icon(icon, color: Colors.black38, size: 18) : null,
    filled:    true,
    fillColor: Colors.white,
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
      borderSide: const BorderSide(color: _kPrimary, width: 1.5),
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
  final String id              = UniqueKey().toString();
  final barcodeCtrl            = TextEditingController();
  final itemNameCtrl           = TextEditingController();
  final descriptionCtrl        = TextEditingController();
  File?   imageFile;

  void dispose() {
    barcodeCtrl.dispose();
    itemNameCtrl.dispose();
    descriptionCtrl.dispose();
  }
}