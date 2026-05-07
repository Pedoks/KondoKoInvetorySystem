import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_model.dart';
import '../utils/constants.dart';

class ItemTransactionService {
  final String token;

  ItemTransactionService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── Safe JSON decode ──────────────────────────────────
  dynamic _safeJson(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(http.Response response, String fallback) {
    final json = _safeJson(response);
    if (json is Map && json['message'] != null) {
      return json['message'] as String;
    }
    return fallback;
  }

  // ── Stock In (Consumable) ─────────────────────────────
  // quantity     = base unit value (Flutter converts before calling)
  // displayQty   = what the user typed/saw  (e.g. 1)
  // displayUnit  = unit the user selected   (e.g. "kg", "L", "pack")
  Future<ItemTransactionModel> stockIn({
    required String barcode,
    required double quantity,
    required double displayQuantity,
    required String displayUnit,
    required String photoProofUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/stockin'),
      headers: _headers,
      body: jsonEncode({
        'barcode':         barcode,
        'quantity':        quantity,
        'displayQuantity': displayQuantity,
        'displayUnit':     displayUnit,
        'photoProofUrl':   photoProofUrl,
      }),
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) throw Exception('Empty response from server.');
      return ItemTransactionModel.fromJson(json);
    }
    throw Exception(_errorMessage(response, 'Stock in failed'));
  }

  // ── Stock Out (Consumable) ────────────────────────────
  Future<ItemTransactionModel> stockOut({
    required String barcode,
    required double quantity,
    required double displayQuantity,
    required String displayUnit,
    required String photoProofUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/stockout'),
      headers: _headers,
      body: jsonEncode({
        'barcode':         barcode,
        'quantity':        quantity,
        'displayQuantity': displayQuantity,
        'displayUnit':     displayUnit,
        'photoProofUrl':   photoProofUrl,
      }),
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) throw Exception('Empty response from server.');
      return ItemTransactionModel.fromJson(json);
    }
    throw Exception(_errorMessage(response, 'Stock out failed'));
  }

  // ── Scan Barcode (NonConsumable) ──────────────────────
  Future<ItemScanResultModel> scanBarcode(String barcode) async {
    final response = await http.get(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/scan/$barcode'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) throw Exception('Empty response from server.');
      return ItemScanResultModel.fromJson(json);
    }
    throw Exception(_errorMessage(response, 'Scan failed'));
  }

  // ── Issue Item (NonConsumable) ────────────────────────
  Future<ItemTransactionModel> issueItem(String barcode) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/issue'),
      headers: _headers,
      body: jsonEncode({'barcode': barcode}),
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) throw Exception('Empty response from server.');
      return ItemTransactionModel.fromJson(json);
    }
    throw Exception(_errorMessage(response, 'Issue failed'));
  }

  // ── Return Item (NonConsumable) ───────────────────────
  Future<ItemTransactionModel> returnItem(String barcode) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/return'),
      headers: _headers,
      body: jsonEncode({'barcode': barcode}),
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) throw Exception('Empty response from server.');
      return ItemTransactionModel.fromJson(json);
    }
    throw Exception(_errorMessage(response, 'Return failed'));
  }

  // ── My Issued ─────────────────────────────────────────
  Future<List<ItemTransactionModel>> getMyIssued() async {
    final response = await http.get(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/my-issued'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) return [];
      final List<dynamic> data = json;
      return data.map((j) => ItemTransactionModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load issued items');
  }

  // ── My History ────────────────────────────────────────
  Future<List<ItemTransactionModel>> getMyHistory() async {
    final response = await http.get(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/my-history'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) return [];
      final List<dynamic> data = json;
      return data.map((j) => ItemTransactionModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load history');
  }

  // ── Global History ────────────────────────────────────
  Future<List<ItemTransactionModel>> getGlobalHistory() async {
    final response = await http.get(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/global-history'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = _safeJson(response);
      if (json == null) return [];
      final List<dynamic> data = json;
      return data.map((j) => ItemTransactionModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load global history');
  }
}