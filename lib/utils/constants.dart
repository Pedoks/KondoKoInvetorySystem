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
static const int primaryColorValue = 0xFFE07B2A;
static const int lightOrangeValue     = 0xFFFDE3B8;
static const int backgroundColorValue = 0xFFFFF7EF;
static const int successColorValue    = 0xFF558A67;
static const int errorColorValue   = 0xFFC46060;
static const int modalBgValue     = 0xFFF5EDE4;
static const int modalCardBgValue = 0xFFEDE3D8;

static const int stockInColorValue   = 0xFF3AADA0;
static const int stockOutColorValue  = 0xFFEA7D5F;
static const int stepMinusColorValue = 0xFFB8C0C8;
static const int warningColorValue = 0xFFEA7D5F;
static const int neutralColorValue = 0xFFA5A5A5;

  // ── Storage Keys ─────────────────────────────────────
  static const String tokenKey = 'jwt_token';
  static const String userKey  = 'saved_user';
}