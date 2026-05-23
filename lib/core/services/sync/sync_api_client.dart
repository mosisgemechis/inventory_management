import 'dart:convert';
import 'dart:io';

class SyncApiClient {
  SyncApiClient({
    required this.baseUrl,
    this.accessToken,
    HttpClient? httpClient,
  }) : _http = httpClient ?? HttpClient();

  final String baseUrl;
  final String? accessToken;
  final HttpClient _http;

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = Uri.parse(baseUrl).resolve(path);
    final req = await _http.postUrl(uri).timeout(timeout);
    req.headers.contentType = ContentType.json;
    if (accessToken != null && accessToken!.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
    req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close().timeout(timeout);
    final respBody = await utf8.decodeStream(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode}: $respBody', uri: uri);
    }
    final decoded = jsonDecode(respBody);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object response');
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final base = Uri.parse(baseUrl).resolve(path);
    final uri = query == null ? base : base.replace(queryParameters: query);
    final req = await _http.getUrl(uri).timeout(timeout);
    if (accessToken != null && accessToken!.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
    final resp = await req.close().timeout(timeout);
    final respBody = await utf8.decodeStream(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode}: $respBody', uri: uri);
    }
    final decoded = jsonDecode(respBody);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object response');
  }
}

