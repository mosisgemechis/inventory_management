import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
      final safePrefix = accessToken!.length > 15 ? accessToken!.substring(0, 10) : 'short';
      debugPrint('[SYNC CLIENT] Setting Authorization header: Bearer $safePrefix... (len=${accessToken!.length})');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    } else {
      debugPrint('[SYNC CLIENT] No accessToken provided, skipping Authorization header');
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
      final safePrefix = accessToken!.length > 15 ? accessToken!.substring(0, 10) : 'short';
      debugPrint('[SYNC CLIENT] Setting Authorization header: Bearer $safePrefix... (len=${accessToken!.length})');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    } else {
      debugPrint('[SYNC CLIENT] No accessToken provided, skipping Authorization header');
    }
    final resp = await req.close().timeout(timeout);
    final respBody = await utf8.decodeStream(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode}: $respBody', uri: uri);
    }
    return await compute(_decodeJsonObject, respBody);
  }

  static Map<String, dynamic> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object response');
  }
}
