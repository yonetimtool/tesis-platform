/// Onay butonunun KAYDIRMA KILIDI (P36) — saf hesap, widget YOK.
///
/// Kural: kullanici metnin SONUNA gelmeden "Onaylıyorum" ETKINLESMEZ.
/// Amac, okumadan onaylamayi zorlastirmaktir; bu bir UX susu degil,
/// aydinlatmanin GERCEKTEN gosterildiginin tek istemci-tarafi kanitidir.
library;

/// Sona ulasildi sayilmasi icin gereken ESIK (piksel).
///
/// Neden TAM esitlik degil: cihaz olcumlerinde son piksel cogu zaman
/// yakalanamaz (kesirli yukseklik, ust-asma efekti) ve buton HIC
/// etkinlesmezdi. 24 px, "gercekten sonundasin" demek icin yeterince kucuk.
const kaydirmaEsigiPx = 24.0;

/// Metin kaydirma alanina SIGIYORSA kapi ZATEN ACIKTIR.
///
/// Kaydirilamayan bir icerikte "sona kaydir" beklemek, butonu SONSUZA DEK
/// kapali birakirdi (kisa metinli tesisler).
bool kaydirmaKapisiAcik({
  required double kaydirmaKonumu,
  required double enBuyukKonum,
}) {
  if (enBuyukKonum <= 0) return true; // icerik ekrana sigiyor
  return kaydirmaKonumu >= enBuyukKonum - kaydirmaEsigiPx;
}
