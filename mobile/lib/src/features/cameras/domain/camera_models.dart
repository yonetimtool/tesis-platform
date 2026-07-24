/// GET /cameras elemani (WP-F) — yayin URL'sini ISTEMCI oynatir.
class Camera {
  const Camera({required this.id, required this.ad, required this.streamUrl});

  final String id;
  final String ad;
  final String streamUrl;

  factory Camera.fromJson(Map<String, dynamic> json) => Camera(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        streamUrl: json['stream_url'] as String? ?? '',
      );
}
