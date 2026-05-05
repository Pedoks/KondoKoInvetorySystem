// lib/models/key_group_model.dart

import 'key_model.dart';

class KeyGroupModel {
  final String groupId;
  final String ownersName;
  final String unit;
  final String unitStatus;
  final String keyHolder;
  final String keyCode;
  final DateTime date;
  final int totalKeys;
  final int availableKeys;
  final List<String> checkedOutKeyIds; 
  final List<KeyModel> keys;

  KeyGroupModel({
    required this.groupId,
    required this.ownersName,
    required this.unit,
    required this.unitStatus,
    required this.keyHolder,
    required this.keyCode,
    required this.date,
    required this.totalKeys,
    required this.availableKeys,
    this.checkedOutKeyIds = const [], // ← defaults to empty so existing callers don't break
    required this.keys,
  });

  String get availabilityText => '$availableKeys/$totalKeys keys available';
  bool get hasAvailableKeys => availableKeys > 0;

  /// Returns true if the given key ID is currently checked out
  bool isKeyCheckedOut(String keyId) => checkedOutKeyIds.contains(keyId);

  factory KeyGroupModel.fromJson(Map<String, dynamic> json) {
    return KeyGroupModel(
      groupId:          json['groupId'] as String,
      ownersName:       json['ownersName'] as String,
      unit:             json['unit'] as String,
      unitStatus:       json['unitStatus'] as String,
      keyHolder:        json['keyHolder'] as String,
      keyCode:          json['keyCode'] as String,
      date:             DateTime.parse(json['date'] as String),
      totalKeys:        json['totalKeys'] as int,
      availableKeys:    json['availableKeys'] as int,
      checkedOutKeyIds: (json['checkedOutKeyIds'] as List<dynamic>?)  
                            ?.map((e) => e as String)
                            .toList() ?? [],
      keys:             (json['keys'] as List)
                            .map((k) => KeyModel.fromJson(k))
                            .toList(),
    );
  }
}