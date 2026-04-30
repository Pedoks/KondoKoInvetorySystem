class ItemModel {
  final String   id;
  final String   barcode;
  final String   itemName;
  final String   itemType; // "Consumable" or "NonConsumable"
  final int      quantity;
  final int      minStock;
  final int      maxStock;
  final String   description;
  final String   imageUrl;
  final DateTime date;
  final String   stockStatus; // High / Medium / Low / OutOfStock

  ItemModel({
    required this.id,
    required this.barcode,
    required this.itemName,
    required this.itemType,
    required this.quantity,
    required this.minStock,
    required this.maxStock,
    required this.description,
    required this.imageUrl,
    required this.date,
    required this.stockStatus,
  });

  bool get isConsumable => itemType == 'Consumable';

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id:          json['id']          as String,
      barcode:     json['barcode']     as String? ?? '',
      itemName:    json['itemName']    as String,
      itemType:    json['itemType']    as String,
      quantity:    json['quantity']    as int,
      minStock:    json['minStock']    as int? ?? 0,
      maxStock:    json['maxStock']    as int? ?? 0,
      description: json['description'] as String? ?? '',
      imageUrl:    json['imageUrl']    as String? ?? '',
      date:        DateTime.parse(json['date'] as String),
      stockStatus: json['stockStatus'] as String? ?? 'High',
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode':     barcode,
    'itemName':    itemName,
    'itemType':    itemType,
    'quantity':    quantity,
    'minStock':    minStock,
    'maxStock':    maxStock,
    'description': description,
    'imageUrl':    imageUrl,
    'date':        date.toIso8601String(),
  };
}

class ItemTransactionModel {
  final String    id;
  final String    itemId;
  final String    itemName;
  final String    userId;
  final String    userName;
  final String    transactionType; // StockIn / StockOut / Issued / Returned
  final int       quantity;
  final String?   photoProofUrl;
  final DateTime  checkOutDate;
  final DateTime? checkInDate;
  final String?   status; // Issued / Returned / null

  ItemTransactionModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.userId,
    required this.userName,
    required this.transactionType,
    required this.quantity,
    this.photoProofUrl,
    required this.checkOutDate,
    this.checkInDate,
    this.status,
  });

  bool get isIssued => status == 'Issued';

  factory ItemTransactionModel.fromJson(Map<String, dynamic> json) {
    return ItemTransactionModel(
      id:              json['id']              as String,
      itemId:          json['itemId']          as String,
      itemName:        json['itemName']        as String,
      userId:          json['userId']          as String,
      userName:        json['userName']        as String,
      transactionType: json['transactionType'] as String,
      quantity:        json['quantity']        as int,
      photoProofUrl:   json['photoProofUrl']   as String?,
      checkOutDate:    DateTime.parse(json['checkOutDate'] as String),
      checkInDate:     json['checkInDate'] != null
          ? DateTime.parse(json['checkInDate'] as String)
          : null,
      status:          json['status'] as String?,
    );
  }
}

class ItemScanResultModel {
  final String  itemId;
  final String  barcode;
  final String  itemName;
  final String  itemType;
  final String  imageUrl;
  final String  status; // Available | Issued
  final String? issuedTo;

  ItemScanResultModel({
    required this.itemId,
    required this.barcode,
    required this.itemName,
    required this.itemType,
    required this.imageUrl,
    required this.status,
    this.issuedTo,
  });

  bool get isAvailable => status == 'Available';

  factory ItemScanResultModel.fromJson(Map<String, dynamic> json) {
    return ItemScanResultModel(
      itemId:   json['itemId']   as String,
      barcode:  json['barcode']  as String,
      itemName: json['itemName'] as String,
      itemType: json['itemType'] as String,
      imageUrl: json['imageUrl'] as String? ?? '',
      status:   json['status']   as String,
      issuedTo: json['issuedTo'] as String?,
    );
  }
}