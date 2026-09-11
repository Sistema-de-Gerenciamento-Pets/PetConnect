import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/core/network/api_exception.dart';

void main() {
  ApiClient clientReturning(http.Response Function(http.Request req) handler,
      {Future<String?> Function()? getToken}) {
    return ApiClient(
      baseUrl: 'http://api.test',
      getToken: getToken ?? () async => 'fake-token',
      httpClient: MockClient((req) async => handler(req)),
    );
  }

  test('GET prefixa /api/v1 e envia o Bearer token', () async {
    late http.Request captured;
    final api = clientReturning((req) {
      captured = req;
      return http.Response(jsonEncode({'ok': true}), 200,
          headers: {'content-type': 'application/json'});
    });

    final body = await api.get('/me');

    expect(captured.url.toString(), 'http://api.test/api/v1/me');
    expect(captured.headers['Authorization'], 'Bearer fake-token');
    expect(body['ok'], true);
  });

  test('sem token não manda header Authorization', () async {
    late http.Request captured;
    final api = clientReturning(
      (req) {
        captured = req;
        return http.Response('{}', 200);
      },
      getToken: () async => null,
    );

    await api.get('/me');

    expect(captured.headers.containsKey('Authorization'), false);
  });

  test('resposta de erro com envelope vira ApiException com code/message', () async {
    final api = clientReturning((req) => http.Response(
          jsonEncode({
            'timestamp': '2026-09-10T00:00:00Z',
            'status': 404,
            'code': 'RESOURCE_NOT_FOUND',
            'message': 'Usuário não encontrado.',
          }),
          404,
          headers: {'content-type': 'application/json'},
        ));

    final e = await api.get('/me').then<ApiException?>((_) => null).catchError((err) => err as ApiException);

    expect(e, isA<ApiException>());
    expect(e!.status, 404);
    expect(e.code, 'RESOURCE_NOT_FOUND');
    expect(e.isNotFound, true);
    expect(e.message, 'Usuário não encontrado.');
  });

  test('401 é detectado por isUnauthorized', () async {
    final api = clientReturning((req) => http.Response(
        jsonEncode({'code': 'UNAUTHENTICATED', 'message': 'x'}), 401,
        headers: {'content-type': 'application/json'}));

    try {
      await api.patch('/me', {'firstName': 'x'});
      fail('deveria ter lançado');
    } on ApiException catch (e) {
      expect(e.isUnauthorized, true);
    }
  });

  test('falha de transporte vira ApiException NETWORK', () async {
    final api = ApiClient(
      baseUrl: 'http://api.test',
      getToken: () async => null,
      httpClient: MockClient((req) => Future.error(const SocketExceptionLike())),
    );

    try {
      await api.get('/me');
      fail('deveria ter lançado');
    } on ApiException catch (e) {
      expect(e.code, 'NETWORK');
      expect(e.isNetwork, true);
      expect(e.status, 0);
    }
  });

  test('204/corpo vazio retorna mapa vazio', () async {
    final api = clientReturning((req) => http.Response('', 204));
    final body = await api.get('/me');
    expect(body, isEmpty);
  });
}

/// Exceção qualquer para simular falha de rede no MockClient.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
