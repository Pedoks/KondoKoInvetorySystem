import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/key_model.dart';
import '../models/key_group_model.dart';
import '../services/key_service.dart';
import 'addkey_screen.dart';
import 'keys_inandout_screen.dart';
import 'barcode_scanner_screen.dart';

class KeyDashboardScreen extends StatefulWidget {
  final String token;

  const KeyDashboardScreen({super.key, required this.token});

  @override
  State<KeyDashboardScreen> createState() => _KeyDashboardScreenState();
}

class _KeyDashboardScreenState extends State<KeyDashboardScreen> {
  late final KeyService _keyService;
  List<KeyGroupModel> _allGroups = [];
  List<KeyGroupModel> _filteredGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _keyService = KeyService(token: widget.token);
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await _keyService.getAllGroups();
      setState(() {
        _allGroups = groups;
        _filteredGroups = groups;
        _isLoading = false;
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
      _searchQuery = query;
      _filteredGroups = _allGroups.where((g) =>
        g.ownersName.toLowerCase().contains(query.toLowerCase()) ||
        g.unit.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _showGroupModal(KeyGroupModel group) {
    showDialog(
      context: context,
      builder: (_) => _KeyGroupModal(
        group: group,
        keyService: _keyService,
        onUpdated: _loadGroups,
        onDeleted: _loadGroups,
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
    if (result == true) _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        _KeysAppBar(),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(size.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.015),

                // Action Cards
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.key,
                        label: 'Add Key',
                        onTap: _goToAddKey,
                      ),
                    ),
                    SizedBox(width: size.width * 0.04),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.key_outlined,
                        label: 'Keys In&Out',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                KeysInAndOutScreen(token: widget.token),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: size.height * 0.02),

                // Key List + Search
                Row(
                  children: [
                    const Icon(Icons.key, color: Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Key Groups',
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
                          hintText: 'Search owner or unit...',
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Colors.black45),
                          filled: true,
                          fillColor: const Color(AppConstants.lightOrangeValue),
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

                // Table
                _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: Color(AppConstants.primaryColorValue),
                          ),
                        ),
                      )
                    : _filteredGroups.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No key groups found.',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : _KeyTable(
                            groups: _filteredGroups,
                            onView: _showGroupModal,
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
    );
  }
}

// ── Action Card ────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
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

// ── Key Table (Groups) ──────────────────────────────────────────
class _KeyTable extends StatelessWidget {
  final List<KeyGroupModel> groups;
  final void Function(KeyGroupModel) onView;

  const _KeyTable({required this.groups, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.lightOrangeValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text('Owner',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Unit Name',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
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
          ...groups.asMap().entries.map((entry) {
            final isLast = entry.key == groups.length - 1;
            final group = entry.value;
            return _GroupRow(
              group: group,
              isLast: isLast,
              onView: () => onView(group),
            );
          }),
        ],
      ),
    );
  }
}

// ── Group Row ──────────────────────────────────────────
class _GroupRow extends StatelessWidget {
  final KeyGroupModel group;
  final bool isLast;
  final VoidCallback onView;

  const _GroupRow({
    required this.group,
    required this.isLast,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final ownerDisplay = group.ownersName.split(' ').first;
    final statusColor = group.hasAvailableKeys 
        ? const Color(AppConstants.successColorValue)
        : Colors.red.shade600;

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
            child: Text(ownerDisplay,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(group.unit,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                group.availabilityText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: GestureDetector(
                onTap: onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

// ── Key Group Modal ──────────────────────────────────────────
class _KeyGroupModal extends StatefulWidget {
  final KeyGroupModel group;
  final KeyService keyService;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const _KeyGroupModal({
    required this.group,
    required this.keyService,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<_KeyGroupModal> createState() => _KeyGroupModalState();
}

// ── Key List Item Widget (With Scan Button in Edit Mode) ──────────────────────────
class _KeyListItem extends StatelessWidget {
  final KeyModel keyModel;
  final bool isSelected;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback onScan;  // NEW: callback for scan button

  const _KeyListItem({
    required this.keyModel,
    required this.isSelected,
    required this.isEditMode,
    required this.onTap,
    required this.onScan,  // NEW
  });

  @override
  Widget build(BuildContext context) {
    final bool isCheckedOut = false;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(AppConstants.primaryColorValue).withOpacity(0.1) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFE8D5C0), width: 0.5)),
        ),
        child: Row(
          children: [
            // Icon
            Icon(
              Icons.key,
              size: 16,
              color: isSelected ? const Color(AppConstants.primaryColorValue) : Colors.black54,
            ),
            const SizedBox(width: 8),
            
            // Key Type
            Expanded(
              flex: 2,
              child: Text(
                keyModel.keyType,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(AppConstants.primaryColorValue) : Colors.black87,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Barcode
            Expanded(
              flex: 2,
              child: Text(
                keyModel.barcode,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isCheckedOut 
                    ? Colors.red.withOpacity(0.15)
                    : const Color(AppConstants.successColorValue).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isCheckedOut ? 'Out' : 'Available',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isCheckedOut ? Colors.red.shade600 : const Color(AppConstants.successColorValue),
                ),
              ),
            ),
            
            // Scan Button (only in edit mode)
            if (isEditMode) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onScan,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.primaryColorValue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 16,
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

// ── Key Details Form Widget ──────────────────────────────────────────
// ── Key Details Form Widget (Without Barcode) ──────────────────────────────────────────
class _KeyDetailsForm extends StatefulWidget {
  final KeyModel keyModel;
  final bool isEditMode;
  final Function(KeyModel) onChanged;

  const _KeyDetailsForm({
    required this.keyModel,
    required this.isEditMode,
    required this.onChanged,
  });

  @override
  State<_KeyDetailsForm> createState() => _KeyDetailsFormState();
}

class _KeyDetailsFormState extends State<_KeyDetailsForm> {
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _keyHolderCtrl;
  late DateTime _selectedDate;

  String? _keyType;
  String? _unitStatus;
  String? _keyCode;

  static const List<String> keyTypeOptions = [
    'Key Bundle', 'Main Door', 'Mail Box',
    'Bedroom 1', 'Bedroom 2', 'Comfort Room',
  ];
  static const List<String> unitStatusOptions = ['Rented', 'Terminated'];
  static const List<String> keyCodeOptions = [
    'Code 0', 'Code 1', 'Code 2', 'Code 3', 'Code 4',
  ];

  @override
  void initState() {
    super.initState();
    final k = widget.keyModel;
    _ownerCtrl = TextEditingController(text: k.ownersName);
    _unitCtrl = TextEditingController(text: k.unit);
    _keyHolderCtrl = TextEditingController(text: k.keyHolder);
    _selectedDate = k.date;
    _keyType = keyTypeOptions.contains(k.keyType) ? k.keyType : null;
    _unitStatus = unitStatusOptions.contains(k.unitStatus) ? k.unitStatus : null;
    _keyCode = keyCodeOptions.contains(k.keyCode) ? k.keyCode : null;
    
    if (widget.isEditMode) {
      _ownerCtrl.addListener(_notifyChange);
      _unitCtrl.addListener(_notifyChange);
      _keyHolderCtrl.addListener(_notifyChange);
    }
  }

  void _notifyChange() {
    if (!widget.isEditMode) return;
    final updatedKey = KeyModel(
      id: widget.keyModel.id,
      barcode: widget.keyModel.barcode, // Keep existing barcode
      ownersName: _ownerCtrl.text,
      unit: _unitCtrl.text,
      keyType: _keyType ?? '',
      unitStatus: _unitStatus ?? '',
      keyHolder: _keyHolderCtrl.text,
      keyCode: _keyCode ?? '',
      date: _selectedDate,
      groupId: widget.keyModel.groupId,
    );
    widget.onChanged(updatedKey);
  }

  Future<void> _pickDate() async {
    if (!widget.isEditMode) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(AppConstants.primaryColorValue),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _notifyChange();
    }
  }

  @override
  void dispose() {
    if (widget.isEditMode) {
      _ownerCtrl.removeListener(_notifyChange);
      _unitCtrl.removeListener(_notifyChange);
      _keyHolderCtrl.removeListener(_notifyChange);
    }
    _ownerCtrl.dispose();
    _unitCtrl.dispose();
    _keyHolderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isEditMode ? 'Edit Key Details' : 'Key Details',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 12),

        // Owner / Unit
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
              child: widget.isEditMode
                  ? _ModalTextField(controller: _ownerCtrl, readOnly: false)
                  : _ModalReadOnly(text: _ownerCtrl.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.isEditMode
                  ? _ModalTextField(controller: _unitCtrl, readOnly: false)
                  : _ModalReadOnly(text: _unitCtrl.text),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Key Code / Type
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
              child: widget.isEditMode
                  ? _ModalDropdown(
                      value: _keyCode,
                      items: keyCodeOptions,
                      onChanged: (v) {
                        setState(() => _keyCode = v);
                        _notifyChange();
                      },
                    )
                  : _ModalReadOnly(text: _keyCode ?? '-'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.isEditMode
                  ? _ModalDropdown(
                      value: _keyType,
                      items: keyTypeOptions,
                      onChanged: (v) {
                        setState(() => _keyType = v);
                        _notifyChange();
                      },
                    )
                  : _ModalReadOnly(text: _keyType ?? '-'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Key Holder / Unit Status
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
              child: widget.isEditMode
                  ? _ModalTextField(controller: _keyHolderCtrl, readOnly: false)
                  : _ModalReadOnly(text: _keyHolderCtrl.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.isEditMode
                  ? _ModalDropdown(
                      value: _unitStatus,
                      items: unitStatusOptions,
                      onChanged: (v) {
                        setState(() => _unitStatus = v);
                        _notifyChange();
                      },
                    )
                  : _ModalReadOnly(text: _unitStatus ?? '-'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Date
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
              child: widget.isEditMode
                  ? GestureDetector(
                      onTap: _pickDate,
                      child: _ModalReadOnly(
                        text: DateFormat('yyyy-MM-dd').format(_selectedDate),
                        isEditing: true,
                      ),
                    )
                  : _ModalReadOnly(text: DateFormat('yyyy-MM-dd').format(_selectedDate)),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
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

// ── Key Group Modal State ──────────────────────────────────────────
class _KeyGroupModalState extends State<_KeyGroupModal> {
  KeyModel? _selectedKey;
  bool _isEditing = false;
  bool _isAddingKey = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  
  // For adding new key
  String? _newKeyType;
  String _newBarcode = '';
  
  static const List<String> keyTypeOptions = [
    'Key Bundle', 'Main Door', 'Mail Box',
    'Bedroom 1', 'Bedroom 2', 'Comfort Room',
  ];

  @override
  void initState() {
    super.initState();
    _selectedKey = widget.group.keys.isNotEmpty ? widget.group.keys.first : null;
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _loadOriginalGroup();
    });
  }

  Future<void> _loadOriginalGroup() async {
    try {
      final updatedGroup = await widget.keyService.getGroupById(widget.group.groupId);
      setState(() {
        widget.group.keys.clear();
        widget.group.keys.addAll(updatedGroup.keys);
        if (_selectedKey != null) {
          final sameKey = widget.group.keys.firstWhere(
            (k) => k.id == _selectedKey!.id,
            orElse: () => widget.group.keys.first,
          );
          _selectedKey = sameKey;
        }
      });
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _scanNewBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          hintLabel: 'Scan new key barcode',
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _newBarcode = result);
    }
  }

  Future<void> _addKeyToGroup() async {
    if (_newKeyType == null || _newBarcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan barcode and select key type')),
      );
      return;
    }

    setState(() => _isAddingKey = true);
    try {
      await widget.keyService.addKeyToGroup(
        groupId: widget.group.groupId,
        barcode: _newBarcode,
        keyType: _newKeyType!,
      );
      
      final updatedGroup = await widget.keyService.getGroupById(widget.group.groupId);
      
      setState(() {
        widget.group.keys.clear();
        widget.group.keys.addAll(updatedGroup.keys);
        _isAddingKey = false;
        _newKeyType = null;
        _newBarcode = '';
        if (_selectedKey == null && widget.group.keys.isNotEmpty) {
          _selectedKey = widget.group.keys.first;
        }
      });
      
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key added successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isAddingKey = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    }
  }

  Future<void> _updateSelectedKey() async {
    if (_selectedKey == null) return;
    
    setState(() => _isSaving = true);
    try {
      await widget.keyService.updateKey(_selectedKey!.id, {
        'barcode': _selectedKey!.barcode,
        'ownersName': _selectedKey!.ownersName,
        'unit': _selectedKey!.unit,
        'keyType': _selectedKey!.keyType,
        'unitStatus': _selectedKey!.unitStatus,
        'keyHolder': _selectedKey!.keyHolder,
        'keyCode': _selectedKey!.keyCode,
        'date': _selectedKey!.date.toIso8601String(),
      });
      
      widget.onUpdated();
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    }
  }
  
  Future<void> _scanAndUpdateBarcode(KeyModel key) async {
  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => BarcodeScannerScreen(
        hintLabel: 'Scan new barcode for ${key.keyType}',
      ),
    ),
  );
  
  if (result != null && mounted) {
    setState(() => _isSaving = true);
    try {
      await widget.keyService.updateKey(key.id, {
        'barcode': result,
        'ownersName': key.ownersName,
        'unit': key.unit,
        'keyType': key.keyType,
        'unitStatus': key.unitStatus,
        'keyHolder': key.keyHolder,
        'keyCode': key.keyCode,
        'date': key.date.toIso8601String(),
      });
      
      // Refresh the key in the list
      final updatedGroup = await widget.keyService.getGroupById(widget.group.groupId);
      setState(() {
        widget.group.keys.clear();
        widget.group.keys.addAll(updatedGroup.keys);
        _isSaving = false;
        // Keep the same key selected if it still exists
        if (_selectedKey != null) {
          final sameKey = widget.group.keys.firstWhere(
            (k) => k.id == key.id,
            orElse: () => widget.group.keys.first,
          );
          _selectedKey = sameKey;
        }
      });
      
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcode updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    }
  }
}

  Future<void> _deleteSelectedKey() async {
    if (_selectedKey == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Key'),
        content: Text('Are you sure you want to delete key "${_selectedKey!.keyType}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await widget.keyService.deleteKey(_selectedKey!.id);
      
      final updatedGroup = await widget.keyService.getGroupById(widget.group.groupId);
      
      if (updatedGroup.keys.isEmpty) {
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          widget.group.keys.clear();
          widget.group.keys.addAll(updatedGroup.keys);
          _selectedKey = widget.group.keys.first;
          _isDeleting = false;
          _isEditing = false;
        });
      }
      
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key deleted successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.04,
        vertical: size.height * 0.02,
      ),
      child: Container(
        width: isSmallScreen ? size.width * 0.95 : size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: const Color(AppConstants.lightOrangeValue),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_isEditing) ...[
                          _ModalButton(
                            label: _isSaving ? '...' : 'Save',
                            color: const Color(AppConstants.primaryColorValue),
                            onTap: _isSaving ? null : _updateSelectedKey,
                          ),
                          _ModalButton(
                            label: _isDeleting ? '...' : 'Delete',
                            color: Colors.red.shade500,
                            onTap: _isDeleting ? null : _deleteSelectedKey,
                          ),
                          _ModalButton(
                            label: 'Cancel',
                            color: Colors.grey.shade600,
                            onTap: _cancelEdit,
                          ),
                          _ModalButton(
                            label: _isAddingKey ? '...' : '+ Add Key',
                            color: const Color(AppConstants.successColorValue),
                            onTap: _isAddingKey ? null : () => setState(() => _isAddingKey = true),
                          ),
                        ] else ...[
                          _ModalButton(
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
                    child: const Icon(Icons.close, color: Colors.black54, size: 24),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group Info Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.group.unit,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  widget.group.ownersName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.group.hasAvailableKeys
                                  ? const Color(AppConstants.successColorValue).withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.group.availabilityText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.group.hasAvailableKeys
                                    ? const Color(AppConstants.successColorValue)
                                    : Colors.red.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Keys List Header
                    if (!_isAddingKey && widget.group.keys.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.primaryColorValue).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Key Type',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Barcode',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(width: 80),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: size.height * 0.3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: widget.group.keys.map((key) {
                              final isSelected = _selectedKey?.id == key.id;
                              return _KeyListItem(
                                keyModel: key, 
                                isSelected: isSelected,
                                isEditMode: _isEditing,
                                onTap: () => setState(() => _selectedKey = key),
                                onScan: () => _scanAndUpdateBarcode(key),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Add Key Form
// Add Key Form
if (_isAddingKey && _isEditing) ...[
  Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(AppConstants.lightOrangeValue),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        // Header
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
                  child: const Icon(Icons.key, color: Colors.white, size: 17),
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
              onTap: () => setState(() => _isAddingKey = false),
              child: const Icon(Icons.close, size: 22, color: Colors.black54),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Barcode
        _DashBarcodeRow(
          barcode: _newBarcode,
          onScanTap: _scanNewBarcode,
        ),

        const SizedBox(height: 10),

        // Key Type
        _DashDropdown(
          value: _newKeyType,
          hint: 'Key Type',
          icon: Icons.vpn_key_outlined,
          items: keyTypeOptions,
          onChanged: (v) => setState(() => _newKeyType = v),
        ),

        const SizedBox(height: 12),

        // Add button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isAddingKey ? _addKeyToGroup : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.successColorValue),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text(
              'Add Key',
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
  const SizedBox(height: 20),
],

                    // Selected Key Details Form
                    if (_selectedKey != null && !_isAddingKey) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      _KeyDetailsForm(
                        keyModel: _selectedKey!,
                        isEditMode: _isEditing,
                        onChanged: (updatedKey) => setState(() => _selectedKey = updatedKey),
                      ),
                      const SizedBox(height: 20),
                    ],
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

// ── Modal Helper Widgets ───────────────────────────────
class _ModalButton extends StatelessWidget {
  final String label;
  final Color color;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
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
      readOnly: readOnly,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
  final bool isEditing;

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
  final String? value;
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
      value: value,
      onChanged: onChanged,
      isDense: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45, size: 18),
      dropdownColor: const Color(AppConstants.backgroundColorValue),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 12)),
              ))
          .toList(),
    );
  }
}

// Helper function
InputDecoration _scanFieldDeco(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
  filled: true,
  fillColor: const Color(AppConstants.backgroundColorValue),
  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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

// ── Dash Barcode Row ───────────────────────────────────
class _DashBarcodeRow extends StatelessWidget {
  final String barcode;
  final VoidCallback onScanTap;

  const _DashBarcodeRow({
    required this.barcode,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = barcode.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(AppConstants.backgroundColorValue),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black26),
            ),
            child: Text(
              hasValue ? barcode : 'Scan Barcode',
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? Colors.black87 : Colors.black38,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onScanTap,
          icon: const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

// ── Dash Dropdown ──────────────────────────────────────
class _DashDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final void Function(String?) onChanged;

  const _DashDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.black38, size: 18),
        filled: true,
        fillColor: const Color(AppConstants.backgroundColorValue),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black38),
      dropdownColor: const Color(AppConstants.backgroundColorValue),
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
    );
  }
}