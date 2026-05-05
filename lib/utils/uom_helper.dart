/// UOM — Unit of Measurement helper.
/// Handles all unit conversion logic for consumable items.
/// Flutter converts to base unit BEFORE sending to backend.
class UOM {
  UOM._();

  // ── Unit lists per type ──────────────────────────────
  static const List<String> liquidUnits = ['mL', 'L', 'gallon'];
  static const List<String> solidUnits  = ['g', 'kg', 'lb'];
  static const List<String> countUnits  = ['pcs'];

  /// Get available units for a given unitType
  static List<String> unitsFor(String unitType) {
    switch (unitType) {
      case 'Liquid': return liquidUnits;
      case 'Solid':  return solidUnits;
      case 'Count':  return countUnits;
      default:       return countUnits;
    }
  }

  /// Base unit for each type (stored in DB)
  static String baseUnitFor(String unitType) {
    switch (unitType) {
      case 'Liquid': return 'mL';
      case 'Solid':  return 'g';
      case 'Count':  return 'pcs';
      default:       return 'pcs';
    }
  }

  /// Convert [value] from [fromUnit] to base unit.
  /// For Count: pass conversionFactor (pcs per box/pack), default 1.
  ///
  /// Examples:
  ///   convert(2, 'L')        → 2000  (mL)
  ///   convert(1, 'kg')       → 1000  (g)
  ///   convert(1, 'gallon')   → 3785  (mL)
  ///   convert(3, 'pcs', 1)   → 3     (pcs)
  static double toBase(double value, String fromUnit,
      {double conversionFactor = 1}) {
    switch (fromUnit) {
      // Liquid
      case 'mL':     return value;
      case 'L':      return value * 1000;
      case 'gallon': return value * 3785.41;
      // Solid
      case 'g':      return value;
      case 'kg':     return value * 1000;
      case 'lb':     return value * 453.592;
      // Count
      case 'pcs':    return value * conversionFactor;
      default:       return value;
    }
  }

  /// Convert [value] from base unit to [toUnit] for display.
  /// Inverse of toBase.
  static double fromBase(double value, String toUnit,
      {double conversionFactor = 1}) {
    switch (toUnit) {
      case 'mL':     return value;
      case 'L':      return value / 1000;
      case 'gallon': return value / 3785.41;
      case 'g':      return value;
      case 'kg':     return value / 1000;
      case 'lb':     return value / 453.592;
      case 'pcs':    return conversionFactor > 0
          ? value / conversionFactor : value;
      default:       return value;
    }
  }

  /// Format a base-unit value nicely for display.
  /// e.g. formatDisplay(1500, 'mL') → "1500 mL"
  ///      formatDisplay(1000, 'mL') → "1 L"  (auto-promote)
  static String formatDisplay(double value, String baseUnit) {
    // Auto-promote to larger unit if clean
    if (baseUnit == 'mL' && value >= 1000 && value % 1000 == 0) {
      return '${(value / 1000).toStringAsFixed(0)} L';
    }
    if (baseUnit == 'g' && value >= 1000 && value % 1000 == 0) {
      return '${(value / 1000).toStringAsFixed(0)} kg';
    }
    final qty = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$qty $baseUnit';
  }
}