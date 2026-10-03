/// (P253 A1) Sakinin makbuz arsivi — `GET /me/makbuzlar` `Makbuz` semasi.
///
/// `pdfUrl` KISA OMURLUDUR (presign) ve SAKLANMAZ: kalici bir baglanti,
/// kimlik dogrulamasi olmadan erisilebilen bir mali belge demekti.
library;

/// Makbuz PDF turu (paylasim icin).
const makbuzMimeTuru = 'application/pdf';

class Makbuz {
  const Makbuz({
    required this.id,
    required this.belgeNo,
    required this.tutarKurus,
    required this.createdAt,
    this.pdfUrl,
  });

  final String id;
  final String belgeNo;
  final int tutarKurus;
  final DateTime createdAt;
  final String? pdfUrl;

  factory Makbuz.fromJson(Map<String, dynamic> j) => Makbuz(
        id: j['id'] as String? ?? '',
        belgeNo: j['belge_no'] as String? ?? '',
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt() ?? 0,
        pdfUrl: j['pdf_url'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
