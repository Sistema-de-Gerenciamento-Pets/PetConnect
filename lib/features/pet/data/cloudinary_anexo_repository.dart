import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/cloudinary_config.dart';
import '../domain/anexo_repository.dart';

/// Upload de arquivos via Cloudinary (upload preset "unsigned") — ver
/// core/config/cloudinary_config.dart para como configurar a conta.
class CloudinaryAnexoRepository implements AnexoRepository {
  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/auto/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryUploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: path.split('/').last));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
          'Falha no upload para o Cloudinary (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  @override
  Future<void> delete(String url) async {
    // Excluir no Cloudinary exige uma requisição assinada com a API secret
    // da conta, que não pode ficar embutida no app (seria exposta por
    // engenharia reversa do APK). Sem um backend próprio para assinar essa
    // requisição, o arquivo antigo fica órfão no Cloudinary — mesma
    // limitação já aceita antes para o Firebase Storage (ver PRs de
    // histórico médico e carteira de vacina).
  }
}
