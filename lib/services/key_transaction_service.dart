import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/key_transaction_model.dart';
import '../utils/constants.dart';

class KeyTransactionService {
  static const String _base = '${AppConstants.baseUrl}/keytransactions';

  final String token;
  KeyTransactionService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── Scan barcode → get key status ─────────────────────
  Future<KeyScanResultModel> scanBarcode(String barcode) async {
    final response = await http.get(
      Uri.parse('$_base/scan/$barcode'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return KeyScanResultModel.fromJson(jsonDecode(response.body));
    }
    final msg = _extractMessage(response.body);
    throw Exception(msg);
  }

  // ── Check Out ─────────────────────────────────────────
  Future<KeyTransactionModel> checkOut(String barcode) async {
    final response = await http.post(
      Uri.parse('$_base/checkout'),
      headers: _headers,
      body: jsonEncode({'barcode': barcode}),
    );
    if (response.statusCode == 200) {
      return KeyTransactionModel.fromJson(jsonDecode(response.body));
    }
    final msg = _extractMessage(response.body);
    throw Exception(msg);
  }

  // ── Check In ──────────────────────────────────────────
  Future<KeyTransactionModel> checkIn(String barcode) async {
    final response = await http.post(
      Uri.parse('$_base/checkin'),
      headers: _headers,
      body: jsonEncode({'barcode': barcode}),
    );
    if (response.statusCode == 200) {
      return KeyTransactionModel.fromJson(jsonDecode(response.body));
    }
    final msg = _extractMessage(response.body);
    throw Exception(msg);
  }

  // ── My Active (checked-out by me) ─────────────────────
  Future<List<KeyTransactionModel>> getMyActive() async {
    final response = await http.get(
      Uri.parse('$_base/my-active'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => KeyTransactionModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load active keys');
  }

  // ── My History ────────────────────────────────────────
  Future<List<KeyTransactionModel>> getMyHistory() async {
    final response = await http.get(
      Uri.parse('$_base/my-history'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => KeyTransactionModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load history');
  }

  // ── Global History ────────────────────────────────────
  Future<List<KeyTransactionModel>> getGlobalHistory() async {
    final response = await http.get(
      Uri.parse('$_base/global-history'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => KeyTransactionModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load global history');
  }

  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['message'] as String? ?? 'An error occurred.';
    } catch (_) {
      return 'An error occurred.';
    }
  }
}