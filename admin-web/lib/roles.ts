// Rol modeli (contracts/auth.md §4): panel YALNIZ admin icindir; diger roller
// burada yalnizca kullanici yonetimi/atama ekranlarinda gosterim icin listelenir.
import type { SozlukAnahtari } from "./i18n/sozluk";
import type { UserRole } from "./types";

// METIN DEGIL KIMLIK (tur 17): `value` sozlesme degeri, `anahtar` ise
// gorunen adin sozluk anahtaridir. Kontrol akisi HER ZAMAN `value`ya bakar
// — metne bakan kod dil degisince sessizce bozulurdu.
export const ROLE_OPTIONS: { value: UserRole; anahtar: SozlukAnahtari }[] = [
  { value: "admin", anahtar: "rolPlatformAdmin" },
  { value: "yonetici", anahtar: "rolYonetici" },
  { value: "security", anahtar: "rolGuvenlik" },
  { value: "tesis_gorevlisi", anahtar: "rolTesisGorevlisi" },
  { value: "resident", anahtar: "rolSiteSakini" },
  { value: "guvenlik_amiri", anahtar: "rolGuvenlikAmiri" },
  { value: "denetci", anahtar: "rolDenetci" },
];

export const ROLE_STYLE: Record<string, string> = {
  admin: "bg-violet-100 text-violet-800",
  yonetici: "bg-amber-100 text-amber-800",
  security: "bg-blue-100 text-blue-800",
  tesis_gorevlisi: "bg-teal-100 text-teal-800",
  resident: "bg-slate-100 text-slate-700",
  guvenlik_amiri: "bg-indigo-100 text-indigo-800",
  // (P128) Denetci: mali gozetim — para ekranlarinin (finans) tonundan
  // ayri bir renk secildi ki listede "yonetim" gibi okunmasin.
  denetci: "bg-rose-100 text-rose-800",
};

/// Rol degerinin sozluk anahtari; taninmayan deger icin null (cagiran ham
/// degeri gosterir — uydurma etiket yok).
export function roleAnahtari(v: string): SozlukAnahtari | null {
  return ROLE_OPTIONS.find((r) => r.value === v)?.anahtar ?? null;
}

/// Gorunen rol adi — `t` cizim katmanindan gelir. Kimlik cozulemezse HAM
/// deger gosterilir (sunucu yeni bir rol eklerse satir bos kalmasin).
export function rolAdi(
  t: (a: SozlukAnahtari) => string,
  deger: string,
): string {
  const anahtar = roleAnahtari(deger);
  return anahtar ? t(anahtar) : deger;
}

// Gorev atanabilir saha rolleri (yonetici gorev ALMAZ, atar; resident alamaz).
export const SAHA_ROLLERI: UserRole[] = ["security", "tesis_gorevlisi"];
