class KeyTransactionModel {
  final String    id;
  final String    keyId;
  final String    barcode;
  final String    unit;
  final String    userId;
  final String    userName;
  final DateTime  checkOutDate;
  final DateTime? checkInDate;
  final String    status;

  KeyTransactionModel({
    required this.id,
    required this.keyId,
    required this.barcode,
    required this.unit,
    required this.userId,
    required this.userName,
    required this.checkOutDate,
    this.checkInDate,
    required this.status,
  });

  bool get isCheckedOut => status == 'CheckedOut';

  factory KeyTransactionModel.fromJson(Map<String, dynamic> json) {
    return KeyTransactionModel(
      id:           json['id']           as String,
      keyId:        json['keyId']        as String,
      barcode:      json['barcode']      as String,
      unit:         json['unit']         as String,
      userId:       json['userId']       as String,
      userName:     json['userName']     as String,
      checkOutDate: DateTime.parse(json['checkOutDate'] as String),
      checkInDate:  json['checkInDate'] != null
          ? DateTime.parse(json['checkInDate'] as String)
          : null,
      status:       json['status']       as String,
    );
  }
}

class KeyScanResultModel {
  final String  keyId;
  final String  barcode;
  final String  unit;
  final String  keyType;
  final String  status; // Available | CheckedOut
  final String? checkedOutBy;

  KeyScanResultModel({
    required this.keyId,
    required this.barcode,
    required this.unit,
    required this.keyType,
    required this.status,
    this.checkedOutBy,
  });

  bool get isAvailable => status == 'Available';

  factory KeyScanResultModel.fromJson(Map<String, dynamic> json) {
    return KeyScanResultModel(
      keyId:        json['keyId']        as String,
      barcode:      json['barcode']      as String,
      unit:         json['unit']         as String,
      keyType:      json['keyType']      as String,
      status:       json['status']       as String,
      checkedOutBy: json['checkedOutBy'] as String?,
    );
  }
}