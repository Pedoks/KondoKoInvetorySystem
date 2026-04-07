import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/key_model.dart';
import '../utils/constants.dart';

class KeyService {
  static const String _endpoint = '${AppConstants.baseUrl}/keys';

  final String token;
  KeyService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── GET ALL ───────────────────────────────────────────
  Future<List<KeyModel>> getAllKeys() async {
    try {
      final response = await http.get(
        Uri.parse(_endpoint),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => KeyModel.fromJson(e)).toList();
      }
      throw Exception('Failed to load keys: ${response.statusCode}');
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // ── GET BY ID ─────────────────────────────────────────
  Future<KeyModel> getKeyById(String id) async {
    final response = await http.get(
      Uri.parse('$_endpoint/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return KeyModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Key not found');
  }

  // ── CREATE ────────────────────────────────────────────
  Future<KeyModel> createKey(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return KeyModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create key: ${response.body}');
  }

  // ── UPDATE ────────────────────────────────────────────
  Future<KeyModel> updateKey(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_endpoint/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return KeyModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update key: ${response.body}');
  }

  // ── DELETE ────────────────────────────────────────────
  Future<void> deleteKey(String id) async {
    final response = await http.delete(
      Uri.parse('$_endpoint/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete key: ${response.body}');
    }
  }
}