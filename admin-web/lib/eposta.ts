import { SINIR } from "@/lib/girdi-siniri";

/**
 * (P233 §4) E-POSTA — bicim ve uzunluk, TEK kaynak.
 *
 * =========================================================================
 * OLCULEN DURUM: sunucu ZATEN reddediyordu, kullanici NEDENINI gormuyordu
 * =========================================================================
 * Backend `EmailStr` (pydantic/email-validator) kullaniyor ve OLCULDU:
 * yerel kisim 64'ten uzunsa, toplam 254'ten uzunsa ya da bicim bozuksa
 * 422 donuyor. Yani KURAL VARDI. Eksik olan, kuralin KULLANICIYA
 * SOYLENMESIYDI: alanlarin hicbirinde `maxLength` ve alan-ici hata yoktu
 * (6 web alani, 4 mobil alan tarandi); kullanici formu doldurup
 * gonderdikten SONRA jenerik bir hata goruyordu.
 *
 * =========================================================================
 * NEDEN "SUNUCUYLA AYNI REGEX" DEGIL
 * =========================================================================
 * Istemci dogrulamasi sunucudan DAHA SIKI olursa gercek bir adresi
 * reddeder ve kullanici kaydolamaz — geri donusu olmayan taraf budur.
 * Bu yuzden buradaki bicim denetimi KASITLI OLARAK GEVSEK: yalnizca
 * hicbir sunucunun kabul etmeyecegi seyleri (bosluk, `@` yoklugu/ikizi,
 * noktasiz alan adi, bas/son nokta, cift nokta) reddeder. Kesin karar
 * sunucunun.
 *
 * UZUNLUK SINIRLARI ise KESIN: RFC 5321 yerel kisim 64, toplam 254.
 */

/** RFC 5321: yerel kisim en cok 64 sekizli. */
export const EPOSTA_YEREL_SINIR = 64;

/** RFC 5321: adresin tamami en cok 254 karakter. (P248 §3a) Deger
 * sunucuyla ortak tek kaynaktan (`SINIR.EPOSTA`, kilit: girdi-siniri.test). */
export const EPOSTA_SINIR = SINIR.EPOSTA;

export type EpostaHatasi = "bos" | "bicim" | "yerelUzun" | "cokUzun";

/** [ham] icin hata kimligi; `null` = gecerli. Cumle CIZIM katmaninda. */
export function epostaHatasi(
  ham: string,
  zorunlu = true,
): EpostaHatasi | null {
  const s = (ham ?? "").trim();
  if (!s) return zorunlu ? "bos" : null;
  // UZUNLUK ONCE: bicim denetimi uzun bir adreste de gecebilir ve
  // kullanici asil engeli (uzunluk) hic gormezdi.
  if (s.length > EPOSTA_SINIR) return "cokUzun";
  const parcalar = s.split("@");
  if (parcalar.length !== 2) return "bicim";
  const [yerel, alan] = parcalar;
  if (yerel.length > EPOSTA_YEREL_SINIR) return "yerelUzun";
  if (!yerel || !alan) return "bicim";
  if (/\s/.test(s)) return "bicim";
  if (!alan.includes(".")) return "bicim";
  if (alan.startsWith(".") || alan.endsWith(".")) return "bicim";
  if (yerel.startsWith(".") || yerel.endsWith(".")) return "bicim";
  if (s.includes("..")) return "bicim";
  return null;
}

/** Saklanacak deger: kirpilmis + kucuk harf. */
export function epostaNormalle(ham: string): string {
  return (ham ?? "").trim().toLowerCase();
}
