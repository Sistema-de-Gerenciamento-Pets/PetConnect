import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/features/pet/data/api_anexo_repository.dart';

void main() {
  test('upload pega a assinatura na API e sobe direto pro Cloudinary assinado',
      () async {
    final requests = <http.BaseRequest>[];

    final api = ApiClient(
      baseUrl: 'http://api.test',
      getToken: () async => 'fake-token',
      httpClient: MockClient((req) async {
        requests.add(req);
        return http.Response(
          jsonEncode({
            'signature': 'sig123',
            'timestamp': 1700000000,
            'apiKey': 'key1',
            'cloudName': 'cloudx'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final cloudinaryRequests = <http.BaseRequest>[];
    final uploadHttp = MockClient((req) async {
      cloudinaryRequests.add(req);
      return http.Response(
          jsonEncode({
            'secure_url':
                'https://res.cloudinary.com/cloudx/image/upload/v1/abc.jpg'
          }),
          200);
    });

    final repo = ApiAnexoRepository(api: api, httpClient: uploadHttp);

    final url = await repo.upload(
      path: 'pets/123/foto.jpg',
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
    );

    expect(url, 'https://res.cloudinary.com/cloudx/image/upload/v1/abc.jpg');
    expect(requests.single.url.path, '/api/v1/uploads/signature');

    // MockClient entrega um http.Request reconstruído (não o MultipartRequest
    // original) — inspeciona o corpo multipart já codificado.
    final cloudinaryReq = cloudinaryRequests.single as http.Request;
    expect(cloudinaryReq.url.toString(),
        'https://api.cloudinary.com/v1_1/cloudx/auto/upload');
    expect(
        cloudinaryReq.headers['content-type'], contains('multipart/form-data'));
    final body = cloudinaryReq.body;
    expect(body, contains('name="api_key"'));
    expect(body, contains('key1'));
    expect(body, contains('name="timestamp"'));
    expect(body, contains('1700000000'));
    expect(body, contains('name="signature"'));
    expect(body, contains('sig123'));
    expect(body, contains('name="file"'));
  });

  test('delete manda a URL para DELETE /uploads', () async {
    http.Request? captured;
    final api = ApiClient(
      baseUrl: 'http://api.test',
      getToken: () async => 'fake-token',
      httpClient: MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      }),
    );

    final repo = ApiAnexoRepository(api: api);
    await repo
        .delete('https://res.cloudinary.com/cloudx/image/upload/v1/abc.jpg');

    expect(captured!.method, 'DELETE');
    expect(captured!.url.path, '/api/v1/uploads');
    expect(jsonDecode(captured!.body),
        {'url': 'https://res.cloudinary.com/cloudx/image/upload/v1/abc.jpg'});
  });
}
