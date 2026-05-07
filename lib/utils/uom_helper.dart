/// UOM — Unit of Measurement helper.
/// Handles all unit conversion logic for consumable items.
/// Flutter converts to base unit BEFORE sending to backend.
class UOM {
  UOM._();

  // ── Unit lists per type ──────────────────────────────
  static const List<String> liquidUnits = ['mL', 'L', 'gallon'];
  static const List<String> solidUnits  = ['g', 'kg', 'lb'];
  static const List<String> countUnits  = ['pcs'];

  // ── Units per type ───────────────────────────────────

  /// Get available units for a given unitType.
  /// For Count items WITHOUT a pack (convFactor == 1): returns ['pcs']
  /// For Count items WITH a pack (convFactor > 1):     returns ['pcs', 'pack']
  static List<String> unitsFor(String unitType,
      {double conversionFactor = 1}) {
    switch (unitType) {
      case 'Liquid': return liquidUnits;
      case 'Solid':  return solidUnits;
      case 'Count':
        return conversionFactor > 1 ? ['pcs', 'pack'] : ['pcs'];
      default:
        return countUnits;
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

  // ── Conversion ───────────────────────────────────────

  /// Convert [value] FROM [fromUnit] TO base unit.
  ///
  /// For Count:
  ///   'pcs'  → value * 1           (each pcs is 1 base pcs)
  ///   'pack' → value * convFactor   (each pack = convFactor pcs)
  ///
  /// Examples:
  ///   toBase(2,   'L')             → 2000   (mL)
  ///   toBase(1,   'kg')            → 1000   (g)
  ///   toBase(2,   'pack', cf: 24)  → 48     (pcs)
  ///   toBase(48,  'pcs',  cf: 24)  → 48     (pcs)
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
      case 'pack':   return value * conversionFactor;
      case 'pcs':    return value;   // pcs is already base
      default:       return value;
    }
  }

  /// Convert [value] FROM base unit TO [toUnit] for display.
  /// Inverse of toBase.
  ///
  /// Examples:
  ///   fromBase(2000, 'L')              → 2     (L)
  ///   fromBase(1000, 'kg')             → 1     (kg)
  ///   fromBase(48,   'pack', cf: 24)   → 2     (pack)
  ///   fromBase(48,   'pcs',  cf: 24)   → 48    (pcs)
  static double fromBase(double value, String toUnit,
      {double conversionFactor = 1}) {
    switch (toUnit) {
      case 'mL':     return value;
      case 'L':      return value / 1000;
      case 'gallon': return value / 3785.41;
      case 'g':      return value;
      case 'kg':     return value / 1000;
      case 'lb':     return value / 453.592;
      case 'pack':
        return conversionFactor > 0 ? value / conversionFactor : value;
      case 'pcs':    return value;
      default:       return value;
    }
  }

  // ── Display formatting ───────────────────────────────

  /// Format a value nicely as a display string.
  /// [value]    — the value already converted to [displayUnit]
  /// [displayUnit] — the unit to show
  ///
  /// Examples:
  ///   formatDisplay(2,    'L')    → "2 L"
  ///   formatDisplay(1.5,  'kg')   → "1.5 kg"
  ///   formatDisplay(2,    'pack') → "2 pack"
  ///   formatDisplay(48,   'pcs')  → "48 pcs"
  static String formatDisplay(double value, String displayUnit) {
    final str = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$str $displayUnit';
  }

  /// Format a BASE-unit value for display, auto-promoting to preferred unit.
  /// Used in places where we only have the base value and preferred unit.
  ///
  /// [baseValue]   — value in base unit (mL / g / pcs)
  /// [baseUnit]    — 'mL' | 'g' | 'pcs'
  /// [preferredUnit] — what to show it as
  /// [convFactor]  — conversion factor for Count items
  static String formatInPreferred(
    double baseValue,
    String baseUnit, {
    String? preferredUnit,
    double convFactor = 1,
  }) {
    final unit = preferredUnit ?? baseUnit;
    final converted = fromBase(baseValue, unit, conversionFactor: convFactor);
    return formatDisplay(converted, unit);
  }

  // ── Pack helpers ─────────────────────────────────────

  /// True if this Count item uses packs (conversionFactor > 1)
  static bool hasPack(String unitType, double conversionFactor) =>
      unitType == 'Count' && conversionFactor > 1;

  /// Returns the secondary hint for Count items with packs.
  /// e.g. qty=2, unit='pack', cf=24  → "= 48 pcs"
  ///      qty=48, unit='pcs',  cf=24  → "= 2 pack"
  static String? packHint(double qty, String unit, double convFactor) {
    if (convFactor <= 1) return null;
    if (unit == 'pack') {
      final pcs = (qty * convFactor).toInt();
      return '= $pcs pcs';
    }
    if (unit == 'pcs') {
      final packs = qty / convFactor;
      final str = packs == packs.truncateToDouble()
          ? packs.toInt().toString()
          : packs.toStringAsFixed(1);
      return '= $str pack';
    }
    return null;
  }
}