import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class HttpClient {
  static HttpClient? _instance;
  static IOClient? _ioClient;
  final String _baseUrl;

  HttpClient._({String? baseUrl}) : _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  // Singleton instance
  static HttpClient get instance {
    _instance ??= HttpClient._();
    return _instance!;
  }

  // Buat IOClient yang accept semua certificate (untuk self-signed)
  IOClient get client {
    if (_ioClient == null) {
      final ioHttpClient = io.HttpClient()
        ..badCertificateCallback =
            ((io.X509Certificate cert, String host, int port) {
              // Accept semua certificate untuk development
              // TODO: di production, validasi certificate dengan benar
              return true;
            });
      _ioClient = IOClient(ioHttpClient);
    }
    return _ioClient!;
  }

  // Helper: build full URL
  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  // Helper: get headers with auth token
  Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConfig.tokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // GET request
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final finalHeaders = headers ?? await _getHeaders(withAuth: withAuth);
    final uri = _buildUri(path, queryParams: queryParams);

    final response = await client.get(uri, headers: finalHeaders);

    return response;
  }

  // POST request
  Future<http.Response> post(
    String path, {
    dynamic data,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final finalHeaders = headers ?? await _getHeaders(withAuth: withAuth);
    final uri = _buildUri(path, queryParams: queryParams);
    final body = data is String ? data : jsonEncode(data);

    final response = await client.post(uri, headers: finalHeaders, body: body);

    return response;
  }

  Future<http.StreamedResponse> postMultipart(
    String path, {
    required List<io.File> files,
    required String fieldName,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path));
    final multipartHeaders = await _getHeaders();
    multipartHeaders.remove('Content-Type');
    request.headers.addAll(multipartHeaders);
    request.files.addAll(
      files.map(
        (file) => http.MultipartFile.fromBytes(
          fieldName,
          file.readAsBytesSync(),
          filename: file.uri.pathSegments.last,
        ),
      ),
    );
    if (fields != null) request.fields.addAll(fields);
    return client.send(request);
  }

  // PUT request
  Future<http.Response> put(
    String path, {
    dynamic data,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final finalHeaders = headers ?? await _getHeaders(withAuth: withAuth);
    final uri = _buildUri(path, queryParams: queryParams);
    final body = data is String ? data : jsonEncode(data);

    final response = await client.put(uri, headers: finalHeaders, body: body);

    return response;
  }

  // DELETE request
  Future<http.Response> delete(
    String path, {
    dynamic data,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    final finalHeaders = headers ?? await _getHeaders(withAuth: withAuth);
    final uri = _buildUri(path, queryParams: queryParams);

    final response = await client.delete(uri, headers: finalHeaders);

    return response;
  }
}
