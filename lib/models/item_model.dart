class ItemModel {
  final String   id;
  final String   barcode;
  final String   itemName;
  final String   itemType;         // "Consumable" or "NonConsumable"

  // ── Unit of Measurement ─────────────────────────────
  final String   unitType;         // "Liquid" | "Solid" | "Count"
  final String   baseUnit;         // "mL" | "g" | "pcs" — always smallest, stored in DB
  final String   preferredUnit;    // "L" | "kg" | "pcs" — what staff prefers to see/use
  final double   conversionFactor; // for Count only

  // ── Stock (always in base unit in DB) ───────────────
  final double   quantity;
  final double   minStock;
  final double   maxStock;

  final String   description;
  final String   imageUrl;
  final DateTime date;
  final String   stockStatus;

  ItemModel({
    required this.id,
    required this.barcode,
    required this.itemName,
    required this.itemType,
    required this.unitType,
    required this.baseUnit,
    required this.preferredUnit,
    required this.conversionFactor,
    required this.quantity,
    required this.minStock,
    required this.maxStock,
    required this.description,
    required this.imageUrl,
    required this.date,
    required this.stockStatus,
  });

  bool get isConsumable => itemType == 'Consumable';
  bool get isLiquid     => unitType == 'Liquid';
  bool get isSolid      => unitType == 'Solid';
  bool get isCount      => unitType == 'Count';

  /// Quantity converted from base unit to preferredUnit for display
  /// e.g. 5000 mL → "5 L" if preferredUnit = L
  double get quantityInPreferred {
    if (!isConsumable) return quantity;
    return _convertFromBase(quantity, preferredUnit);
  }

  /// MinStock converted to preferredUnit for display
  double get minStockInPreferred => _convertFromBase(minStock, preferredUnit);

  /// MaxStock converted to preferredUnit for display
  double get maxStockInPreferred => _convertFromBase(maxStock, preferredUnit);

  double _convertFromBase(double value, String toUnit) {
    switch (toUnit) {
      case 'mL': return value;
      case 'L':  return value / 1000;
      case 'gallon': return value / 3785.41;
      case 'g':  return value;
      case 'kg': return value / 1000;
      case 'lb': return value / 453.592;
      case 'pcs': return conversionFactor > 0
          ? value / conversionFactor : value;
      default:   return value;
    }
  }

  /// Nicely formatted quantity in preferredUnit
  /// e.g. "5 L", "500 mL", "10 kg"
  String get quantityDisplay {
    if (!isConsumable) return '${quantity.toInt()} pc';
    final val = quantityInPreferred;
    final str = val == val.truncateToDouble()
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
    return '$str $preferredUnit';
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id:               json['id']               as String,
      barcode:          json['barcode']           as String?  ?? '',
      itemName:         json['itemName']          as String,
      itemType:         json['itemType']          as String,
      unitType:         json['unitType']          as String?  ?? 'Count',
      baseUnit:         json['baseUnit']          as String?  ?? 'pcs',
      preferredUnit:    json['preferredUnit']     as String?  ?? 'pcs',
      conversionFactor: (json['conversionFactor'] as num?)?.toDouble() ?? 1,
      quantity:         (json['quantity']         as num).toDouble(),
      minStock:         (json['minStock']         as num?)?.toDouble() ?? 0,
      maxStock:         (json['maxStock']         as num?)?.toDouble() ?? 0,
      description:      json['description']       as String?  ?? '',
      imageUrl:         json['imageUrl']          as String?  ?? '',
      date:             DateTime.parse(json['date'] as String),
      stockStatus:      json['stockStatus']       as String?  ?? 'High',
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode':          barcode,
    'itemName':         itemName,
    'itemType':         itemType,
    'unitType':         unitType,
    'baseUnit':         baseUnit,
    'preferredUnit':    preferredUnit,
    'conversionFactor': conversionFactor,
    'quantity':         quantity,
    'minStock':         minStock,
    'maxStock':         maxStock,
    'description':      description,
    'imageUrl':         imageUrl,
    'date':             date.toIso8601String(),
  };
}

class ItemTransactionModel {
  final String    id;
  final String    itemId;
  final String    itemName;
  final String    userId;
  final String    userName;
  final String    transactionType;
  final double    quantity;   // always in base unit
  final String    baseUnit;
  final String?   photoProofUrl;
  final DateTime  checkOutDate;
  final DateTime? checkInDate;
  final String?   status;

  ItemTransactionModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.userId,
    required this.userName,
    required this.transactionType,
    required this.quantity,
    required this.baseUnit,
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
      quantity:        (json['quantity']       as num).toDouble(),
      baseUnit:        json['baseUnit']        as String? ?? 'pcs',
      photoProofUrl:   json['photoProofUrl']   as String?,
      checkOutDate:    DateTime.parse(json['checkOutDate'] as String),
      checkInDate:     json['checkInDate'] != null
          ? DateTime.parse(json['checkInDate'] as String) : null,
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
  final String  status;
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