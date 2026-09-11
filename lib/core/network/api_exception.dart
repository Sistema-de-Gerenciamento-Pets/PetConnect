/// Erro devolvido pela API no formato `{timestamp, status, code, message}`,
/// ou uma falha de rede/transporte antes de chegar resposta.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
  });

  /// HTTP status (0 quando a requisição nem completou).
  final int status;

  /// Código estável da API (ex.: `RESOURCE_NOT_FOUND`), ou `NETWORK` /
  /// `UNKNOWN` para falhas locais.
  final String code;

  final String message;

  bool get isNetwork => code == 'NETWORK';
  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;

  @override
  String toString() => 'ApiException($status $code): $message';
}
