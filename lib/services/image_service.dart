import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImageService {
  /// Uploads an image to Imgur and returns the direct link securely without using Firebase Storage.
  static Future<String?> uploadImage(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgur.com/3/upload'),
      );
      request.headers['Authorization'] =
          'Client-ID c93439e6a0a0346'; // Public anonymous Client-ID
      request.files.add(await http.MultipartFile.fromPath('image', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        if (json['success'] == true) {
          return json['data']['link'];
        }
      }
    } catch (e) {
      print('Image Upload Error: $e');
    }
    return null;
  }
}
