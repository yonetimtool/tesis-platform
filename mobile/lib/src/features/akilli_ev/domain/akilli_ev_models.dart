/// (P240 §3) Akilli ev modelleri.
library;

class AkilliEvCihaz {
  const AkilliEvCihaz({
    required this.id,
    required this.ad,
    required this.tip,
    required this.disKimlik,
    required this.eylemler,
    this.daireNo,
    this.alan,
    this.aktif = true,
    this.bolum,
  });

  final String id;
  final String ad;

  /// `isik` | `priz` | `kilit` | ... | `sensor_su` | `sayac` | `diger`
  final String tip;
  final String disKimlik;

  /// Cihaz TIPININ destekledigi eylemler — SUNUCUDAN gelir.
  ///
  /// Istemcide hesaplanmiyor: bir sensore "ac" dugmesi cizmek,
  /// kullaniciya calismayacak bir sey vaat etmekti.
  final List<String> eylemler;
  final String? daireNo;
  final String? alan;
  final bool aktif;

  /// (E2E 2026-09) TESIS-13: cihazin sayildigi bolum — SUNUCUDAN gelir
  /// (`TIP_BOLUM`). Eski sunucu gondermezse istemci tablosuna duser.
  final String? bolum;

  factory AkilliEvCihaz.fromJson(Map<String, dynamic> j) => AkilliEvCihaz(
        id: j['id'] as String,
        ad: j['ad'] as String? ?? '',
        tip: j['tip'] as String? ?? 'diger',
        disKimlik: j['dis_kimlik'] as String? ?? '',
        eylemler: ((j['eylemler'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        daireNo: j['daire_no'] as String?,
        alan: j['alan'] as String?,
        aktif: j['aktif'] as bool? ?? true,
        bolum: j['bolum'] as String?,
      );
}

class AkilliEvBolum {
  const AkilliEvBolum({required this.bolum, required this.acik});

  final String bolum;
  final bool acik;

  factory AkilliEvBolum.fromJson(Map<String, dynamic> j) => AkilliEvBolum(
        bolum: j['bolum'] as String? ?? '',
        acik: j['acik'] as bool? ?? false,
      );
}
