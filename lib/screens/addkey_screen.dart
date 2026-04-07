import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/key_service.dart';
import 'barcode_scanner_screen.dart';

class AddKeyScreen extends StatefulWidget {
  final String token;

  const AddKeyScreen({super.key, required this.token});

  @override
  State<AddKeyScreen> createState() => _AddKeyScreenState();
}

class _AddKeyScreenState extends State<AddKeyScreen> {
  // Main form
  final _mainFormKey    = GlobalKey<FormState>();
  final _barcodeCtrl    = TextEditingController();
  final _ownerCtrl      = TextEditingController();
  final _unitCtrl       = TextEditingController();
  final _keyHolderCtrl  = TextEditingController();
  final _tagCtrl        = TextEditingController();
  String?  _keyType;
  String?  _unitStatus;
  DateTime _selectedDate = DateTime.now();

  // Extra key cards (same owner — only barcode + keyType)
  final List<_ExtraKeyData> _extraKeys = [];

  bool _isSubmitting = false;

  static const List<String> _keyTypeOptions = [
    'Key Bundle', 'Main Door', 'Mail Box',
    'Bedroom 1',  'Bedroom 2', 'Comfort Room',
  ];
  static const List<String> _unitStatusOptions = [
    'Rented', 'Terminated',
  ];

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _ownerCtrl.dispose();
    _unitCtrl.dispose();
    _keyHolderCtrl.dispose();
    _tagCtrl.dispose();
    for (final e in _extraKeys) e.dispose();
    super.dispose();
  }

  void _addExtraKey() =>
      setState(() => _extraKeys.add(_ExtraKeyData()));

  void _removeExtraKey(int index) =>
      setState(() => _extraKeys.removeAt(index));

  Future<void> _scanBarcode(TextEditingController ctrl) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() => ctrl.text = result);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate,
      firstDate:   DateTime(2000),
      lastDate:    DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(AppConstants.primaryColorValue),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _onSubmit() async {
    if (!_mainFormKey.currentState!.validate()) return;
    for (final e in _extraKeys) {
      if (!e.formKey.currentState!.validate()) return;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = KeyService(token: widget.token);

      // Main key
      await service.createKey({
        'barcode':    _barcodeCtrl.text.trim(),
        'ownersName': _ownerCtrl.text.trim(),
        'unit':       _unitCtrl.text.trim(),
        'keyType':    _keyType    ?? '',
        'unitStatus': _unitStatus ?? '',
        'keyHolder':  _keyHolderCtrl.text.trim(),
        'keyCode':    _tagCtrl.text.trim(),
        'date':       _selectedDate.toIso8601String(),
      });

      // Extra keys — inherit all owner data, only barcode+keyType differ
      for (final e in _extraKeys) {
        await service.createKey({
          'barcode':    e.barcodeCtrl.text.trim(),
          'ownersName': _ownerCtrl.text.trim(),
          'unit':       _unitCtrl.text.trim(),
          'keyType':    e.keyType ?? '',
          'unitStatus': _unitStatus ?? '',
          'keyHolder':  _keyHolderCtrl.text.trim(),
          'keyCode':    _tagCtrl.text.trim(),
          'date':       _selectedDate.toIso8601String(),
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
                  'Add Key',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(
                              AppConstants.primaryColorValue),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.key,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Key Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Main form card
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
                          // Barcode
                          _BarcodeRow(
                            controller: _barcodeCtrl,
                            onScanTap: () =>
                                _scanBarcode(_barcodeCtrl),
                          ),
                          const SizedBox(height: 10),
                          // Owner
                          _KField(
                            controller: _ownerCtrl,
                            hint: "Owner's Name",
                            icon: Icons.person_outline,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          // Unit
                          _KField(
                            controller: _unitCtrl,
                            hint: 'Unit',
                            icon: Icons.grid_view_outlined,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          // Key Type
                          _KDropdown(
                            value: _keyType,
                            hint: 'Key Type',
                            icon: Icons.vpn_key_outlined,
                            items: _keyTypeOptions,
                            onChanged: (v) =>
                                setState(() => _keyType = v),
                            validator: (v) =>
                                v == null ? 'Required' : null,
                          ),
                          const SizedBox(height: 10),
                          // Unit Status
                          _KDropdown(
                            value: _unitStatus,
                            hint: 'Unit Status',
                            icon: Icons.info_outline,
                            items: _unitStatusOptions,
                            onChanged: (v) =>
                                setState(() => _unitStatus = v),
                            validator: (v) =>
                                v == null ? 'Required' : null,
                          ),
                          const SizedBox(height: 10),
                          // Key Holder
                          _KField(
                            controller: _keyHolderCtrl,
                            hint: 'Key Holder',
                            icon: Icons.people_outline,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          // Tag
                          _KField(
                            controller: _tagCtrl,
                            hint: 'Tag',
                            icon: Icons.label_outline,
                          ),
                          const SizedBox(height: 10),
                          // Date
                          GestureDetector(
                            onTap: _pickDate,
                            child: AbsorbPointer(
                              child: _KField(
                                controller: TextEditingController(
                                  text: DateFormat('yyyy-MM-dd')
                                      .format(_selectedDate),
                                ),
                                hint: 'Date',
                                icon: Icons.calendar_month_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Extra Key Cards ───────────────
                  ..._extraKeys.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ExtraKeyCard(
                        key: ValueKey(e.id),
                        data: e,
                        keyTypeOptions: _keyTypeOptions,
                        onRemove: () => _removeExtraKey(i),
                        onScanTap: () => _scanBarcode(e.barcodeCtrl),
                        onKeyTypeChanged: (v) =>
                            setState(() => e.keyType = v),
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
                  onPressed: _isSubmitting ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(AppConstants.successColorValue),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Submit',
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
                  onPressed: _addExtraKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(AppConstants.lightOrangeValue),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text(
                    '+ Add Key',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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

// ── Extra Key Card ─────────────────────────────────────
class _ExtraKeyCard extends StatelessWidget {
  final _ExtraKeyData          data;
  final List<String>           keyTypeOptions;
  final VoidCallback           onRemove;
  final VoidCallback           onScanTap;
  final void Function(String?) onKeyTypeChanged;

  const _ExtraKeyCard({
    super.key,
    required this.data,
    required this.keyTypeOptions,
    required this.onRemove,
    required this.onScanTap,
    required this.onKeyTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: data.formKey,
        child: Column(
          children: [
            // Header + X
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(
                            AppConstants.primaryColorValue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.key,
                          color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Key Information',
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

            // Barcode
            _BarcodeRow(
              controller: data.barcodeCtrl,
              onScanTap:  onScanTap,
            ),

            const SizedBox(height: 10),

            // Key Type only
            _KDropdown(
              value:     data.keyType,
              hint:      'Key Type',
              icon:      Icons.vpn_key_outlined,
              items:     keyTypeOptions,
              onChanged: onKeyTypeChanged,
              validator: (v) => v == null ? 'Required' : null,
            ),
          ],
        ),
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
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            readOnly:   true,
            style: const TextStyle(fontSize: 14),
            decoration: _kInputDeco('Scan Barcode', null),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onScanTap,
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
        ),
      ],
    );
  }
}

// ── Text Field ─────────────────────────────────────────
class _KField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     hint;
  final IconData                   icon;
  final bool                       readOnly;
  final String? Function(String?)? validator;

  const _KField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.readOnly = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly:   readOnly,
      validator:  validator,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: _kInputDeco(hint, icon),
    );
  }
}

// ── Dropdown ───────────────────────────────────────────
class _KDropdown extends StatelessWidget {
  final String?                    value;
  final String                     hint;
  final IconData                   icon;
  final List<String>               items;
  final void Function(String?)     onChanged;
  final String? Function(String?)? validator;

  const _KDropdown({
    required this.value,
    required this.hint,
    required this.icon,
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
      style: const TextStyle(
          fontSize: 14, color: Colors.black87),
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
    filled:     true,
    fillColor:  const Color(AppConstants.backgroundColorValue),
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade400),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: Colors.red.shade400, width: 1.5),
    ),
  );
}

// ── Extra Key Data ─────────────────────────────────────
class _ExtraKeyData {
  final String id       = UniqueKey().toString();
  final formKey         = GlobalKey<FormState>();
  final barcodeCtrl     = TextEditingController();
  String? keyType;

  void dispose() => barcodeCtrl.dispose();
}