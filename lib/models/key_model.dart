// lib/models/key_model.dart

class KeyModel {
  final String id;
  final String barcode;
  final String ownersName;
  final String unit;
  final String keyType;
  final String unitStatus;
  final String keyHolder;
  final String keyCode;
  final DateTime date;
  final String? groupId;


  bool get isCheckedOut => false; 
 

  KeyModel({
    required this.id,
    required this.barcode,
    required this.ownersName,
    required this.unit,
    required this.keyType,
    required this.unitStatus,
    required this.keyHolder,
    required this.keyCode,
    required this.date,
    this.groupId,
  });

  factory KeyModel.fromJson(Map<String, dynamic> json) {
    return KeyModel(
      id: json['id'] as String,
      barcode: json['barcode'] as String? ?? '',
      ownersName: json['ownersName'] as String,
      unit: json['unit'] as String,
      keyType: json['keyType'] as String,
      unitStatus: json['unitStatus'] as String,
      keyHolder: json['keyHolder'] as String,
      keyCode: json['keyCode'] as String,
      date: DateTime.parse(json['date'] as String),
      groupId: json['groupId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'ownersName': ownersName,
    'unit': unit,
    'keyType': keyType,
    'unitStatus': unitStatus,
    'keyHolder': keyHolder,
    'keyCode': keyCode,
    'date': date.toIso8601String(),
    'groupId': groupId,
  };
}