/// Dis sistem entegrasyonu domain modelleri (C1b) — `contracts/openapi.yaml`
/// Integration semasi. Sir (auth_secret) SUNUCUDAN GELMEZ (write-only);
/// istemci yalniz `authSecretSet` (varlik) bilir.
library;

class Integration {
  const Integration({
    required this.id,
    required this.ad,
    required this.channelType,
    required this.endpointUrl,
    required this.httpMethod,
    required this.authType,
    required this.authSecretSet,
    required this.payloadTemplate,
    required this.aktif,
    this.headersJson = const {},
  });

  final String id;
  final String ad;
  final String channelType; // webhook | megaphone | smarthome
  final String endpointUrl;
  final String httpMethod;
  final Map<String, String> headersJson;
  final String authType; // none | bearer | api_key
  final bool authSecretSet; // sir kayitli mi (sirrin KENDISI gelmez)
  final String payloadTemplate;
  final bool aktif;

  factory Integration.fromJson(Map<String, dynamic> json) => Integration(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        channelType: json['channel_type'] as String? ?? 'webhook',
        endpointUrl: json['endpoint_url'] as String? ?? '',
        httpMethod: json['http_method'] as String? ?? 'POST',
        headersJson: (json['headers_json'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
        authType: json['auth_type'] as String? ?? 'none',
        authSecretSet: json['auth_secret_set'] as bool? ?? false,
        payloadTemplate: json['payload_template'] as String? ?? '',
        aktif: json['aktif'] as bool? ?? true,
      );
}

/// Create/PATCH govdesi. `authSecret` YALNIZ doluysa gonderilir (write-only;
/// bos = degistirme).
class IntegrationDraft {
  const IntegrationDraft({
    required this.ad,
    required this.channelType,
    required this.endpointUrl,
    required this.httpMethod,
    required this.authType,
    required this.payloadTemplate,
    required this.aktif,
    this.headersJson = const {},
    this.authSecret,
  });

  final String ad;
  final String channelType;
  final String endpointUrl;
  final String httpMethod;
  final Map<String, String> headersJson;
  final String authType;
  final String? authSecret;
  final String payloadTemplate;
  final bool aktif;

  Map<String, dynamic> toJson() => {
        'ad': ad,
        'channel_type': channelType,
        'endpoint_url': endpointUrl,
        'http_method': httpMethod,
        'headers_json': headersJson,
        'auth_type': authType,
        if (authSecret != null && authSecret!.isNotEmpty)
          'auth_secret': authSecret,
        'payload_template': payloadTemplate,
        'aktif': aktif,
      };
}

class IntegrationPreset {
  const IntegrationPreset({
    required this.key,
    required this.channelType,
    required this.httpMethod,
    required this.headersJson,
    required this.payloadTemplate,
  });

  final String key;
  final String channelType;
  final String httpMethod;
  final Map<String, String> headersJson;
  final String payloadTemplate;

  factory IntegrationPreset.fromJson(Map<String, dynamic> json) =>
      IntegrationPreset(
        key: json['key'] as String? ?? '',
        channelType: json['channel_type'] as String? ?? 'webhook',
        httpMethod: json['http_method'] as String? ?? 'POST',
        headersJson: (json['headers_json'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
        payloadTemplate: json['payload_template'] as String? ?? '',
      );
}

/// Tetik sonucu — {ok, status?, error?}.
class TriggerResult {
  const TriggerResult({required this.ok, this.status, this.error});

  final bool ok;
  final int? status;
  final String? error;

  factory TriggerResult.fromJson(Map<String, dynamic> json) => TriggerResult(
        ok: json['ok'] as bool? ?? false,
        status: (json['status'] as num?)?.toInt(),
        error: json['error'] as String?,
      );
}
