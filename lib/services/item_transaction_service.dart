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

  // ── Stock In (Consumable) ─────────────────────────────
  Future<ItemTransactionModel> stockIn({
    required String barcode,
    required double quantity,
    required String photoProofUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/stockin'),
      headers: _headers,
      body: jsonEncode({
        'barcode':       barcode,
        'quantity':      quantity,
        'photoProofUrl': photoProofUrl,
      }),
    );

    if (response.statusCode == 200) {
      return ItemTransactionModel.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Stock in failed');
  }

  // ── Stock Out (Consumable) ────────────────────────────
  Future<ItemTransactionModel> stockOut({
    required String barcode,
    required double quantity,
    required String photoProofUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/stockout'),
      headers: _headers,
      body: jsonEncode({
        'barcode':       barcode,
        'quantity':      quantity,
        'photoProofUrl': photoProofUrl,
      }),
    );

    if (response.statusCode == 200) {
      return ItemTransactionModel.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Stock out failed');
  }

  // ── Scan Barcode (NonConsumable) ──────────────────────
  Future<ItemScanResultModel> scanBarcode(String barcode) async {
    final response = await http.get(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/scan/$barcode'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ItemScanResultModel.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Scan failed');
  }

  // ── Issue Item (NonConsumable) ────────────────────────
  Future<ItemTransactionModel> issueItem(String barcode) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/issue'),
      headers: _headers,
      body: jsonEncode({'barcode': barcode}),
    );

    if (response.statusCode == 200) {
      return ItemTransactionModel.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Issue failed');
  }

  // ── Return Item (NonConsumable) ───────────────────────
  Future<ItemTransactionModel> returnItem(String barcode) async {
    final response = await http.post(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/return'),
      headers: _headers,
      body: jsonEncode({'barcode': barcode}),
    );

    if (response.statusCode == 200) {
      return ItemTransactionModel.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Return failed');
  }

  // ── My Issued ─────────────────────────────────────────
  Future<List<ItemTransactionModel>> getMyIssued() async {
    final response = await http.get(
      Uri.parse('${AppConstants.itemTransactionsEndpoint}/my-issued'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
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
      final List<dynamic> data = jsonDecode(response.body);
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
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => ItemTransactionModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load global history');
  }
}