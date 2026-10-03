/// (P253 A2) Rapor dosyasinin MIME turu ve sabit dosya adlari.
///
/// Teknik dizgeler (MIME, uzanti) CIZIM KATMANINDA durmaz — sabit metin
/// kilidi `presentation/` altini tarar; bunlar cevrilecek metin degil.
library;

String raporMimeTuru(String dosyaAdi) {
  final ad = dosyaAdi.toLowerCase();
  if (ad.endsWith('.pdf')) return 'application/pdf';
  if (ad.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (ad.endsWith('.csv')) return 'text/csv';
  return 'application/octet-stream';
}

/// Gorev gecmisi CSV dosya adi (web `/reports/tasks` ile ayni).
const gorevGecmisiDosyaAdi = 'gorev-gecmisi.csv';
