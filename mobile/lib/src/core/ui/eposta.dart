/// (P233 §4) E-POSTA — biçim ve uzunluk, TEK kaynak.
///
/// Panel ikizi: `admin-web/lib/eposta.ts` (aynı kurallar, aynı kimlikler).
///
/// =========================================================================
/// ÖLÇÜLEN DURUM: sunucu ZATEN reddediyordu, kullanıcı NEDENİNİ görmüyordu
/// =========================================================================
/// Backend `EmailStr` kullanıyor ve ölçüldü: yerel kısım 64'ten uzunsa,
/// toplam 254'ten uzunsa ya da biçim bozuksa 422 dönüyor. Yani KURAL
/// VARDI. Eksik olan, kuralın KULLANICIYA SÖYLENMESİYDİ — alanların
/// hiçbirinde uzunluk sınırı ve alan-içi hata yoktu.
///
/// =========================================================================
/// NEDEN "SUNUCUYLA AYNI REGEX" DEĞİL
/// =========================================================================
/// İstemci doğrulaması sunucudan DAHA SIKI olursa gerçek bir adresi
/// reddeder ve kullanıcı kaydolamaz — geri dönüşü olmayan taraf budur. Bu
/// yüzden biçim denetimi KASITLI OLARAK GEVŞEK: yalnızca hiçbir sunucunun
/// kabul etmeyeceği şeyleri reddeder. Kesin karar sunucunun.
library;

/// RFC 5321: yerel kısım en çok 64 sekizli.
const kEpostaYerelSinir = 64;

/// RFC 5321: adresin tamamı en çok 254 karakter.
const kEpostaSinir = 254;

/// Doğrulama sonucu — METİN DEĞİL KİMLİK (README §15).
enum EpostaHatasi { bos, bicim, yerelUzun, cokUzun }

/// [ham] için hata kimliği; `null` = geçerli.
EpostaHatasi? epostaHatasi(String ham, {bool zorunlu = true}) {
  final s = ham.trim();
  if (s.isEmpty) return zorunlu ? EpostaHatasi.bos : null;
  // UZUNLUK ÖNCE: biçim denetimi uzun bir adreste de geçebilir ve kullanıcı
  // asıl engeli (uzunluk) hiç görmezdi.
  if (s.length > kEpostaSinir) return EpostaHatasi.cokUzun;
  final parcalar = s.split('@');
  if (parcalar.length != 2) return EpostaHatasi.bicim;
  final yerel = parcalar[0];
  final alan = parcalar[1];
  if (yerel.length > kEpostaYerelSinir) return EpostaHatasi.yerelUzun;
  if (yerel.isEmpty || alan.isEmpty) return EpostaHatasi.bicim;
  if (RegExp(r'\s').hasMatch(s)) return EpostaHatasi.bicim;
  if (!alan.contains('.')) return EpostaHatasi.bicim;
  if (alan.startsWith('.') || alan.endsWith('.')) return EpostaHatasi.bicim;
  if (yerel.startsWith('.') || yerel.endsWith('.')) return EpostaHatasi.bicim;
  if (s.contains('..')) return EpostaHatasi.bicim;
  return null;
}

/// Saklanacak değer: kırpılmış + küçük harf.
String epostaNormalle(String ham) => ham.trim().toLowerCase();
