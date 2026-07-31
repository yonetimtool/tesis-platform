/// Kuyruk kaydinin DISKE yazilan hata KODLARI.
///
/// KIMLIK / METIN AYRIMI (README §15): `OutboxEntry` diske yazilir, bu yuzden
/// cumle degil kod tasir. Sozlesme kodlari sunucudan gelir; burada yalniz
/// ISTEMCININ urettigi kodlar tanimlidir. Metne cevirme
/// `presentation/okutma_hata_metni.dart` isidir — bu dosya l10n BILMEZ,
/// boylece `data` katmani cizim katmanina bagimli olmaz.
library;

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';

/// (P34) Sunucu kodu: tura baslarken fotograf zorunlu (tenant ayari).
/// Bu kayit KALICI HATA degil TAMAMLANABILIR bir bekleyistir — kullanici
/// kamerayla fotograf ceker ve AYNI anahtarla yeniden gonderilir (ilk deneme
/// reddedildigi icin sunucuda kayit yoktur, cakisma olmaz).
const okutmaFotoGerekliKod = 'foto_gerekli';

/// Beklenmeyen istemci hatasi (sozlesmede yok).
const okutmaBeklenmeyenKod = 'client_unexpected';

/// AG kodlari (tur 13): sunucu zarfi hic gelmediginde `ApiException.message`
/// BOS'tur; diske bu kodlar yazilir ve metin cizimde uretilir.
const okutmaAgZamanAsimiKod = 'client_ag_timeout';
const okutmaAgUlasilamadiKod = 'client_ag_unreachable';

/// `ApiException`in ag kimligini diske yazilabilir koda cevirir. Zarf geldiyse
/// (sunucu metni var) null doner — o zaman sozlesme kodu yazilir.
String? okutmaAgKodu(ApiException e) => switch (e.agHatasi) {
      AkisHatasi.zamanAsimi => okutmaAgZamanAsimiKod,
      AkisHatasi.sunucuyaUlasilamadi => okutmaAgUlasilamadiKod,
      AkisHatasi.beklenmeyen => okutmaBeklenmeyenKod,
      null => null,
    };
