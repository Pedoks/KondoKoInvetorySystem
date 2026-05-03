import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/key_model.dart';
import '../models/key_group_model.dart';
import '../utils/constants.dart';

class KeyService {
  static const String _endpoint = '${AppConstants.baseUrl}/keys';

  final String token;
  KeyService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── Get all Individual Keys ───────────────────────────
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

  // ── GET ALL GROUPS─────────────────────────────────
  Future<List<KeyGroupModel>> getAllGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_endpoint/groups'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => KeyGroupModel.fromJson(e)).toList();
      }
      throw Exception('Failed to load groups: ${response.statusCode}');
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // ── GET GROUP BY ID ────────────────────────────────
  Future<KeyGroupModel> getGroupById(String groupId) async {
    final response = await http.get(
      Uri.parse('$_endpoint/group/$groupId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return KeyGroupModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Group not found');
  }

  // ── GET BY ID ─────────────────────────
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

  // ── CREATE  ────────────────────────────
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

  // ── ADD KEY TO GROUP ───────────────────────────────
  Future<KeyModel> addKeyToGroup({
    required String groupId,
    required String barcode,
    required String keyType,
  }) async {
    final response = await http.post(
      Uri.parse('$_endpoint/add-to-group'),
      headers: _headers,
      body: jsonEncode({
        'groupId': groupId,
        'barcode': barcode,
        'keyType': keyType,
      }),
    );
    if (response.statusCode == 200) {
      return KeyModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to add key to group: ${response.body}');
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