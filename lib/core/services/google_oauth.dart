import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of a Google OAuth sign-in.
class GoogleOAuthResult {
  const GoogleOAuthResult({
    required this.idToken,
    required this.email,
    required this.googleId,
    this.name,
  });

  final String idToken;
  final String email;
  final String googleId;
  final String? name;
}

class GoogleOAuthException implements Exception {
  GoogleOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Google OAuth 2.0 Authorization Code + PKCE with a loopback redirect.
///
/// Works on Windows/macOS/Linux and Android: the system browser is opened and
/// Google redirects back to a short-lived HTTP listener on 127.0.0.1, which
/// captures the authorization code. The code is then exchanged for an ID token.
class GoogleOAuthFlow {
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const Duration _httpTimeout = Duration(seconds: 25);

  static Future<GoogleOAuthResult> signIn({
    required String clientId,
    String? clientSecret,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final verifier = _codeVerifier();
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');

    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (e) {
      throw GoogleOAuthException(
          'Could not start the local sign-in listener: $e');
    }

    final redirectUri = 'http://127.0.0.1:${server.port}/oauth2callback';
    final callback = Completer<String>();

    final subscription = server.listen((HttpRequest request) async {
      if (request.uri.path != '/oauth2callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final params = request.uri.queryParameters;
      final code = params['code'];
      final error = params['error'];

      request.response.headers.contentType = ContentType.html;
      request.response.write(
          code != null && code.isNotEmpty ? _successPage : _failurePage(error));
      await request.response.close();

      if (!callback.isCompleted) {
        if (code != null && code.isNotEmpty) {
          callback.complete(code);
        } else if (error == 'access_denied') {
          callback.completeError(
              GoogleOAuthException('Google sign-in was cancelled.'));
        } else {
          callback.completeError(GoogleOAuthException(
              'Google sign-in failed: ${params['error_description'] ?? error ?? 'unknown error'}'));
        }
      }
    });

    try {
      final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'prompt': 'select_account',
      });

      bool opened;
      try {
        opened = await launchUrl(authUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        throw GoogleOAuthException(
            'Could not open the browser for Google sign-in: $e');
      }
      if (!opened) {
        throw GoogleOAuthException(
            'Could not open the browser for Google sign-in.');
      }

      final code = await callback.future.timeout(
        timeout,
        onTimeout: () =>
            throw GoogleOAuthException('Google sign-in timed out. Please try again.'),
      );

      return await _exchangeCode(
        code: code,
        verifier: verifier,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUri: redirectUri,
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  static Future<GoogleOAuthResult> _exchangeCode({
    required String code,
    required String verifier,
    required String clientId,
    required String redirectUri,
    String? clientSecret,
  }) async {
    final http = HttpClient()..connectionTimeout = _httpTimeout;
    try {
      final request = await http
          .postUrl(Uri.parse(_tokenEndpoint))
          .timeout(_httpTimeout);
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.write(Uri(queryParameters: {
        'client_id': clientId,
        if (clientSecret != null && clientSecret.isNotEmpty)
          'client_secret': clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      }).query);

      final response = await request.close().timeout(_httpTimeout);
      final body = await utf8.decodeStream(response);

      if (response.statusCode != HttpStatus.ok) {
        throw GoogleOAuthException(
            _tokenErrorMessage(response.statusCode, body));
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw GoogleOAuthException('Google returned an unexpected response.');
      }
      final idToken = decoded['id_token'] as String?;
      if (idToken == null || idToken.isEmpty) {
        throw GoogleOAuthException(
            'Google did not return an ID token. Enable the "openid" scope on the OAuth client.');
      }

      final claims = _decodeJwtPayload(idToken);
      final email = (claims['email'] as String?)?.trim().toLowerCase();
      final googleId = claims['sub'] as String?;
      if (email == null || email.isEmpty || googleId == null) {
        throw GoogleOAuthException(
            'Google did not share an email address for this account.');
      }

      return GoogleOAuthResult(
        idToken: idToken,
        email: email,
        googleId: googleId,
        name: claims['name'] as String?,
      );
    } finally {
      http.close(force: true);
    }
  }

  static String _tokenErrorMessage(int status, String body) {
    var detail = body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final description = decoded['error_description'];
        final error = decoded['error'];
        detail = (description ?? error ?? body).toString();
      }
    } catch (_) {}

    if (detail.contains('client_secret is missing')) {
      return 'Google requires the desktop client secret for this client ID. '
          'Add GOOGLE_CLIENT_SECRET to your .env file.';
    }
    if (detail.contains('redirect_uri_mismatch')) {
      return 'Google rejected the redirect URI. Use a Desktop app OAuth client '
          '(loopback redirects are not allowed for Web/Android/iOS clients).';
    }
    if (detail.contains('invalid_client')) {
      return 'Google rejected the OAuth client. Check GOOGLE_CLIENT_ID and '
          'GOOGLE_CLIENT_SECRET in your .env file.';
    }
    return 'Google token exchange failed (HTTP $status): $detail';
  }

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      throw GoogleOAuthException('Google returned an invalid ID token.');
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (e) {
      throw GoogleOAuthException('Could not read the Google ID token: $e');
    }
  }

  static String _codeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String get _successPage => '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Signed in</title></head>
<body style="font-family:system-ui,sans-serif;background:#050A15;color:#F8FAFC;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
<div style="text-align:center;padding:24px">
<h2 style="font-weight:600">Signed in with Google</h2>
<p style="color:#9FB0C7">You can close this tab and return to GM Inventory Everywhere.</p>
${Platform.isAndroid ? _androidReturnButton : ''}
</div></body></html>
''';

  /// Chrome cannot launch the app automatically without verified App Links,
  /// so this button (plus a best-effort auto-attempt) returns to the app.
  static const String _androidReturnButton = '''
<script>
  // Best effort: Chrome usually blocks this without a user gesture, but some
  // browsers honour it and reopen GM Inventory Everywhere immediately.
  setTimeout(function () { window.location.href = 'gminventory://oauth'; }, 50);
</script>
<p style="margin-top:22px">
<a href="gminventory://oauth"
   style="display:inline-block;padding:12px 22px;border-radius:12px;background:#2563EB;color:#fff;text-decoration:none;font-weight:600">
Open GM Inventory Everywhere
</a></p>
''';

  static String _failurePage(String? error) => '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Sign-in failed</title></head>
<body style="font-family:system-ui,sans-serif;background:#050A15;color:#F8FAFC;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
<div style="text-align:center">
<h2 style="font-weight:600">Sign-in was not completed</h2>
<p style="color:#9FB0C7">${error ?? 'You can close this tab and try again from GM Inventory Everywhere.'}</p>
</div></body></html>
''';
}
