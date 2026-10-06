import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'http_client.dart';

class FaceEmbeddingService {
  final HttpClient _httpClient = HttpClient.instance;

  Future<bool> isRegistered() async {
    final response = await _httpClient.get(ApiConfig.myFaceEmbedding);
    if (response.statusCode != 200) {
      throw Exception('Status data wajah tidak dapat dimuat.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['registered'] == true;
  }

  Future<List<List<double>>> getMyEmbeddings() async {
    final response = await _httpClient.get(ApiConfig.myFaceEmbeddingVector);
    if (response.statusCode != 200) {
      throw Exception('Data wajah belum tersedia untuk diverifikasi.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final values = body['embeddings'];
    if (values is! List ||
        values.isEmpty ||
        values.any((value) => value is! List)) {
      throw Exception('Data embedding wajah tidak valid.');
    }
    return values
        .map(
          (vector) => (vector as List)
              .map((value) => (value as num).toDouble())
              .toList(),
        )
        .toList();
  }

  Future<void> saveEmbedding(List<double> embedding) async {
    final response = await _httpClient.post(
      ApiConfig.myFaceEmbedding,
      data: {'embedding': embedding},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Data wajah gagal disimpan.');
    }
  }

  Future<void> saveEnrollment({
    required List<String> photoPaths,
    required List<List<double>> embeddings,
  }) async {
    final averageEmbedding = List<double>.filled(embeddings.first.length, 0);
    for (final embedding in embeddings) {
      for (var index = 0; index < embedding.length; index++) {
        averageEmbedding[index] += embedding[index] / embeddings.length;
      }
    }
    final response = await _httpClient.postMultipart(
      ApiConfig.myFaceEmbedding,
      files: photoPaths.map(File.new).toList(),
      fieldName: 'photos',
      fields: {
        'embeddingsJson': jsonEncode(embeddings),
        'embeddingJson': jsonEncode(averageEmbedding),
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await http.Response.fromStream(response);
      String message = 'Foto dan data wajah gagal disimpan.';
      try {
        final data = jsonDecode(body.body) as Map<String, dynamic>;
        message =
            data['message']?.toString() ??
            data['Message']?.toString() ??
            message;
        final errors = data['errors'];
        if (errors is Map && errors.values.isNotEmpty) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first.toString();
          }
        }
      } on FormatException {
        // API does not return JSON on every infrastructure-level error.
      }
      throw Exception(message);
    }
  }

  Future<void> deleteEnrollment() async {
    final response = await _httpClient.delete(ApiConfig.myFaceEmbedding);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Data wajah gagal dihapus.';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        message =
            data['message']?.toString() ??
            data['Message']?.toString() ??
            message;
      } on FormatException {
        // API does not return JSON on every infrastructure-level error.
      }
      throw Exception(message);
    }
  }
}
