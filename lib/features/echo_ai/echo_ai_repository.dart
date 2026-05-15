import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:echo_me/features/echo_ai/echo_ai_config.dart';
import 'package:echo_me/features/echo_ai/echo_ai_message.dart';

class EchoAiRepository {
  final AuthRepository _authRepository;
  final HttpClient _client;

  EchoAiRepository(this._authRepository, {HttpClient? client})
    : _client = client ?? HttpClient();

  Future<String> sendMessage({
    required String advisorId,
    required List<EchoAiMessage> messages,
  }) async {
    final user = _authRepository.firebaseUser;
    if (user == null) {
      throw const AuthFailure('Please login again to continue.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('Please login again to continue.');
    }

    final uri = Uri.parse('${EchoAiConfig.baseUrl}/api/echo-ai/chat');
    final request = await _client
        .postUrl(uri)
        .timeout(const Duration(seconds: 12));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(
      jsonEncode({
        'advisorId': advisorId,
        'messages': messages.map((message) => message.toApiJson()).toList(),
      }),
    );

    final response = await request.close().timeout(const Duration(seconds: 45));
    final body = await response.transform(utf8.decoder).join();
    final data = _decodeResponse(body);

    if (response.statusCode == HttpStatus.unauthorized) {
      throw const AuthFailure('Please login again to continue.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        data['error'] as String? ??
            'AI is not available right now. Please try again.',
      );
    }

    final reply = data['reply'] as String?;
    if (reply == null || reply.trim().isEmpty) {
      throw const ServerFailure();
    }

    return sanitizeEchoAiText(reply).trim();
  }

  void close() {
    _client.close(force: true);
  }

  Map<String, dynamic> _decodeResponse(String body) {
    if (body.isEmpty) return const <String, dynamic>{};

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      throw const ServerFailure();
    }

    throw const ServerFailure();
  }
}
