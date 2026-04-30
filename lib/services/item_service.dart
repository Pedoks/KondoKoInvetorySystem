import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_model.dart';
import '../utils/constants.dart';

class ItemService {
  final String token;

  ItemService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── Get All Items ─────────────────────────────────────
  Future<List<ItemModel>> getAllItems() async {
    final response = await http.get(
      Uri.parse(AppConstants.itemsEndpoint),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => ItemModel.fromJson(j)).toList();
    }

    throw Exception('Failed to load items: ${response.statusCode}');
  }

  // ── Get Item By Id ────────────────────────────────────
  Future<ItemModel?> getItemById(String id) async {
    final response = await http.get(
      Uri.parse('${AppConstants.itemsEndpoint}/$id'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ItemModel.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 404) return null;

    throw Exception('Failed to get item: ${response.statusCode}');
  }

  // ── Create Item ───────────────────────────────────────
  // Does NOT upload image — expects Cloudinary URL already in data['imageUrl']
  Future<ItemModel> createItem(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(AppConstants.itemsEndpoint),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return ItemModel.fromJson(jsonDecode(response.body));
    }

    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Failed to create item');
  }

  // ── Update Item ───────────────────────────────────────
  Future<ItemModel?> updateItem(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${AppConstants.itemsEndpoint}/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return ItemModel.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 404) return null;

    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Failed to update item');
  }

  // ── Delete Item ───────────────────────────────────────
  Future<void> deleteItem(String id) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.itemsEndpoint}/$id'),
      headers: _headers,
    );

    if (response.statusCode == 200) return;

    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Failed to delete item');
  }
}