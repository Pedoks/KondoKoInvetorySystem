import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class CloudinaryService {
  Future<String> uploadImage(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConstants.cloudinaryUploadUrl),
    );

    // Add the upload preset (unsigned)
    request.fields['upload_preset'] = AppConstants.cloudinaryUploadPreset;

    // Attach the image file
    final stream = http.ByteStream(imageFile.openRead());
    final length = await imageFile.length();
    final multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: imageFile.path.split('/').last,
    );
    request.files.add(multipartFile);

    // Send the request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary did not return a secure_url.');
      }
      return secureUrl;
    }

    throw Exception(
      'Cloudinary upload failed: ${response.statusCode} — ${response.body}',
    );
  }
}