class AppConstants {
  // ── API ──────────────────────────────────────────────
  static const bool isProduction = true;

  static const String baseUrl = isProduction
      ? 'https://kondokoinvetorysystem-production.up.railway.app/api'
      : 'http://10.0.2.2:5053/api';

  // ── Auth Endpoints ────────────────────────────────────
  static const String loginEndpoint    = '$baseUrl/auth/login';
  static const String registerEndpoint = '$baseUrl/auth/register';

  // ── Key Endpoints ─────────────────────────────────────
  static const String keysEndpoint            = '$baseUrl/keys';
  static const String keyTransactionsEndpoint = '$baseUrl/keytransactions';

  // ── Item Endpoints ────────────────────────────────────
  static const String itemsEndpoint            = '$baseUrl/items';
  static const String itemTransactionsEndpoint = '$baseUrl/itemtransactions';

  // ── Cloudinary ────────────────────────────────────────
  static const String cloudinaryCloudName    = 'ddjmli7v8';
  static const String cloudinaryUploadPreset = 'kondoko_preset';
  static const String cloudinaryUploadUrl    =
      'https://api.cloudinary.com/v1_1/ddjmli7v8/image/upload';

  // ── Colors ───────────────────────────────────────────
  static const int primaryColorValue    = 0xFFFA821E;
  static const int lightOrangeValue     = 0xFFFDBA74;
  static const int backgroundColorValue = 0xFFFFF3E8;
  static const int successColorValue    = 0xFF22C55E;

  // ── Storage Keys ─────────────────────────────────────
  static const String tokenKey = 'jwt_token';
  static const String userKey  = 'saved_user';
}