import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageKitService {
  // ImageKit credentials
  static const String _publicKey = 'public_YxZ2hS349M/KeoIfzWDSN5rzBh8=';
  static const String _privateKey = 'private_tZIKNaqZmhLmPestcD/Q7JAuS/A=';
  static const String _uploadEndpoint = 'https://upload.imagekit.io/api/v1/files/upload';

  /// Upload image to ImageKit
  /// Returns the uploaded image URL on success, null on failure
  static Future<String?> uploadImage({
    required File imageFile,
    required String fileName,
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      // Check file size (max 2MB)
      final fileSize = await imageFile.length();
      const maxSize = 2 * 1024 * 1024; // 2MB in bytes
      if (fileSize > maxSize) {
        throw Exception('File size exceeds 2MB limit');
      }

      final auth = base64Encode(utf8.encode('$_privateKey:'));
      final finalFileName = folder != null ? '$folder/$fileName' : fileName;

      final uri = Uri.parse(_uploadEndpoint);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Basic $auth'
        ..fields['fileName'] = finalFileName
        ..fields['publicKey'] = _publicKey
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['url'] as String;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Upload failed: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('ImageKit upload error: $e');
      return null;
    }
  }

  /// Delete image from ImageKit
  static Future<bool> deleteImage(String fileId) async {
    try {
      final auth = base64Encode(utf8.encode('$_privateKey:'));
      
      final response = await http.delete(
        Uri.parse('https://api.imagekit.io/v1/files/$fileId'),
        headers: {
          'Authorization': 'Basic $auth',
        },
      );

      return response.statusCode == 204;
    } catch (e) {
      print('ImageKit delete error: $e');
      return false;
    }
  }

  /// Get optimized image URL with transformations
  static String getOptimizedUrl({
    required String imageUrl,
    int? width,
    int? height,
    String? quality,
    String? format,
  }) {
    final uri = Uri.parse(imageUrl);
    final transformations = <String>[];

    if (width != null) transformations.add('w-$width');
    if (height != null) transformations.add('h-$height');
    if (quality != null) transformations.add('q-$quality');
    if (format != null) transformations.add('f-$format');

    if (transformations.isEmpty) return imageUrl;

    final transformation = 'tr:${transformations.join(',')}';
    final segments = uri.pathSegments.toList();
    segments.insert(segments.length - 1, transformation);

    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      pathSegments: segments,
    ).toString();
  }

  /// Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
