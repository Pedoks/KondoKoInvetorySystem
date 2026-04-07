import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/key_model.dart';
import '../services/key_service.dart';
import 'addkey_screen.dart';
import 'keys_inandout_screen.dart';

class KeyDashboardScreen extends StatefulWidget {
  final String token;

  const KeyDashboardScreen({super.key, required this.token});

  @override
  State<KeyDashboardScreen> createState() => _KeyDashboardScreenState();
}

class _KeyDashboardScreenState extends State<KeyDashboardScreen> {
  late final KeyService _keyService;
  List<KeyModel> _allKeys      = [];
  List<KeyModel> _filteredKeys = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _keyService = KeyService(token: widget.token);
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() => _isLoading = true);
    try {
      final keys = await _keyService.getAllKeys();
      setState(() {
        _allKeys      = keys;
        _filteredKeys = keys;
        _isLoading    = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red.shade600),
        );
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery  = query;
      _filteredKeys = _allKeys.where((k) =>
        k.ownersName.toLowerCase().contains(query.toLowerCase()) ||
        k.unit.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _showViewModal(KeyModel key) {
    showDialog(
      context: context,
      builder: (_) => _KeyViewModal(
        keyModel:   key,
        keyService: _keyService,
        onUpdated:  _loadKeys,
        onDeleted:  _loadKeys,
      ),
    );
  }

  Future<void> _goToAddKey() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddKeyScreen(token: widget.token),
      ),
    );
    if (result == true) _loadKeys();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        // ── Orange App Bar ───────────────────────────
        _KeysAppBar(),

        // ── Body ─────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(size.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.015),

                // ── Action Cards ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon:    Icons.key,
                        label:   'Add Key',
                        onTap:   _goToAddKey,
                      ),
                    ),
                    SizedBox(width: size.width * 0.04),
                    Expanded(
                      child: _ActionCard(
                        icon:    Icons.key_outlined,
                        label:   'Keys In&Out',
                        onTap:   () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => KeysInAndOutScreen(
                              token: widget.token,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: size.height * 0.02),

                // ── Key List + Search Row ────────────
                Row(
                  children: [
                    const Icon(Icons.key,
                        color: Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Key List',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    // Search bar
                    SizedBox(
                      width: size.width * 0.38,
                      height: 38,
                      child: TextField(
                        onChanged: _onSearch,
                        decoration: InputDecoration(
                          hintText:  '',
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

                // ── Table ────────────────────────────
                _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: Color(AppConstants.primaryColorValue),
                          ),
                        ),
                      )
                    : _filteredKeys.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No keys found.',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : _KeyTable(
                            keys:    _filteredKeys,
                            onView:  _showViewModal,
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
class _KeysAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: const Color(AppConstants.primaryColorValue),
      padding: EdgeInsets.only(
        top: topPadding + 12, bottom: 16,
        left: 16, right: 16,
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
              const Text('Keys',
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
  final IconData icon;
  final String   label;
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
        height: size.height * 0.13,
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: size.width * 0.09, color: Colors.black87),
            SizedBox(height: size.height * 0.008),
            Text(
              label,
              style: TextStyle(
                fontSize: size.width * 0.04,
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

// ── Key Table ──────────────────────────────────────────
class _KeyTable extends StatelessWidget {
  final List<KeyModel> keys;
  final void Function(KeyModel) onView;

  const _KeyTable({required this.keys, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 16),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text('Owner',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Unit Name',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Action',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Data rows
          ...keys.asMap().entries.map((entry) {
            final isLast = entry.key == keys.length - 1;
            final key    = entry.value;
            return _TableRow(
              keyModel: key,
              isLast:   isLast,
              onView:   () => onView(key),
            );
          }),
        ],
      ),
    );
  }
}

// ── Table Row ──────────────────────────────────────────
class _TableRow extends StatelessWidget {
  final KeyModel     keyModel;
  final bool         isLast;
  final VoidCallback onView;

  const _TableRow({
    required this.keyModel,
    required this.isLast,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    // Extract surname only for Owner column
    final ownerDisplay = keyModel.ownersName.split(' ').first;

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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              ownerDisplay,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              keyModel.unit,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: GestureDetector(
                onTap: onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.successColorValue),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

// ── View / Edit Modal ──────────────────────────────────
class _KeyViewModal extends StatefulWidget {
  final KeyModel    keyModel;
  final KeyService  keyService;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const _KeyViewModal({
    required this.keyModel,
    required this.keyService,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<_KeyViewModal> createState() => _KeyViewModalState();
}

class _KeyViewModalState extends State<_KeyViewModal> {
  bool _isEditing  = false;
  bool _isSaving   = false;
  bool _isDeleting = false;

  late final TextEditingController _ownerCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _keyHolderCtrl;
  late DateTime _selectedDate;

  String? _keyType;
  String? _unitStatus;
  String? _keyCode;

  static const List<String> keyTypeOptions = [
    'Key Bundle', 'Main Door', 'Mail Box',
    'Bedroom 1',  'Bedroom 2', 'Comfort Room',
  ];
  static const List<String> unitStatusOptions = ['Rented', 'Terminated'];
  static const List<String> keyCodeOptions = [
    'Code 0', 'Code 1', 'Code 2', 'Code 3', 'Code 4',
  ];

  @override
  void initState() {
    super.initState();
    final k = widget.keyModel;
    _ownerCtrl     = TextEditingController(text: k.ownersName);
    _unitCtrl      = TextEditingController(text: k.unit);
    _keyHolderCtrl = TextEditingController(text: k.keyHolder);
    _selectedDate  = k.date;
    _keyType       = keyTypeOptions.contains(k.keyType)    ? k.keyType    : null;
    _unitStatus    = unitStatusOptions.contains(k.unitStatus) ? k.unitStatus : null;
    _keyCode       = keyCodeOptions.contains(k.keyCode)    ? k.keyCode    : null;
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _unitCtrl.dispose();
    _keyHolderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.keyService.updateKey(widget.keyModel.id, {
        'ownersName': _ownerCtrl.text.trim(),
        'unit':       _unitCtrl.text.trim(),
        'keyType':    _keyType    ?? '',
        'unitStatus': _unitStatus ?? '',
        'keyHolder':  _keyHolderCtrl.text.trim(),
        'keyCode':    _keyCode    ?? '',
        'date':       _selectedDate.toIso8601String(),
      });
      widget.onUpdated();
      if (mounted) {
        setState(() { _isEditing = false; _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Key updated successfully!'),
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
        title: const Text('Delete Key'),
        content: const Text('Are you sure you want to delete this key?'),
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
      await widget.keyService.deleteKey(widget.keyModel.id);
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical:   size.height * 0.08,
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
              // ── Modal Header ──────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Edit / Save button
                  _isEditing
                      ? Row(
                          children: [
                            _ModalButton(
                              label: _isSaving ? '...' : 'Save',
                              color: const Color(AppConstants.primaryColorValue),
                              onTap: _isSaving ? null : _save,
                            ),
                            const SizedBox(width: 8),
                            _ModalButton(
                              label: _isDeleting ? '...' : 'Delete',
                              color: Colors.red.shade500,
                              onTap: _isDeleting ? null : _delete,
                            ),
                          ],
                        )
                      : _ModalButton(
                          label: 'Edit',
                          color: const Color(AppConstants.successColorValue),
                          onTap: () => setState(() => _isEditing = true),
                        ),
                  // Close
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: Colors.black54, size: 24),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Fields Grid ───────────────────────
              Row(
                children: [
                  Expanded(child: _modalLabel('Owner')),
                  const SizedBox(width: 12),
                  Expanded(child: _modalLabel('Unit')),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ModalTextField(
                      controller: _ownerCtrl,
                      readOnly:   !_isEditing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModalTextField(
                      controller: _unitCtrl,
                      readOnly:   !_isEditing,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: _modalLabel('Key Code')),
                  const SizedBox(width: 12),
                  Expanded(child: _modalLabel('Type')),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _isEditing
                        ? _ModalDropdown(
                            value:   _keyCode,
                            items:   keyCodeOptions,
                            onChanged: (v) =>
                                setState(() => _keyCode = v),
                          )
                        : _ModalReadOnly(text: _keyCode ?? '-'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isEditing
                        ? _ModalDropdown(
                            value:   _keyType,
                            items:   keyTypeOptions,
                            onChanged: (v) =>
                                setState(() => _keyType = v),
                          )
                        : _ModalReadOnly(text: _keyType ?? '-'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: _modalLabel('Key Holder')),
                  const SizedBox(width: 12),
                  Expanded(child: _modalLabel('Unit Status')),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ModalTextField(
                      controller: _keyHolderCtrl,
                      readOnly:   !_isEditing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isEditing
                        ? _ModalDropdown(
                            value:   _unitStatus,
                            items:   unitStatusOptions,
                            onChanged: (v) =>
                                setState(() => _unitStatus = v),
                          )
                        : _ModalReadOnly(text: _unitStatus ?? '-'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: _modalLabel('Date')),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: _ModalReadOnly(
                        text: DateFormat('yyyy-MM-dd')
                            .format(_selectedDate),
                        isEditing: _isEditing,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
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

// ── Modal Helper Widgets ───────────────────────────────
class _ModalButton extends StatelessWidget {
  final String     label;
  final Color      color;
  final VoidCallback? onTap;

  const _ModalButton({
    required this.label,
    required this.color,
    this.onTap,
  });

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
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ModalTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;

  const _ModalTextField({
    required this.controller,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly:   readOnly,
      textAlign:  TextAlign.center,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        filled:     true,
        fillColor:  Colors.white,
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

class _ModalDropdown extends StatelessWidget {
  final String?      value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _ModalDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value:    value,
      onChanged: onChanged,
      isDense:  true,
      decoration: InputDecoration(
        filled:    true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.black45, size: 18),
      dropdownColor:
          const Color(AppConstants.backgroundColorValue),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e,
                    style: const TextStyle(fontSize: 12)),
              ))
          .toList(),
    );
  }
}