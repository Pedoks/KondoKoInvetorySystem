
class AppConstants {
  // ── API ──────────────────────────────────────────────
// Toggle this when building for prod
static const bool isProduction = true;

static const String baseUrl = isProduction
    ? 'https://kondokoinvetorysystem-production.up.railway.app/api'
    : 'http://10.0.2.2:5053/api';
  // Use http://localhost:5000/api for Web / Desktop
  // Use http://10.0.2.2:5000/api  for Android Emulator

  // ── Endpoints ────────────────────────────────────────
  static const String loginEndpoint    = '$baseUrl/auth/login';
  static const String registerEndpoint = '$baseUrl/auth/register';

  // ── Colors ───────────────────────────────────────────
  static const int primaryColorValue    = 0xFFFA821E;
  static const int lightOrangeValue     = 0xFFFDBA74;
  static const int backgroundColorValue = 0xFFFFF3E8;
  static const int successColorValue    = 0xFF22C55E;

  // ── Storage Keys ─────────────────────────────────────
  static const String tokenKey = 'jwt_token';
  static const String userKey  = 'saved_user';   // ← NEW
}