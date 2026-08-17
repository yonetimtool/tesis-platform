// (P167 §1.7) PROFIL BOLUMLERI — TEK KAYNAK.
//
// Ayni liste UC yerde cizilir: sag ust kullanici menusu, profil sayfasinin
// KENDI sol menusu ve (dolayli olarak) sayfanin hangi bolumu acacagi
// karari. Uc yerde elle tekrar edilseydi biri eklenip otekI unutuldugunda
// menude gorunen ama sayfada ACILMAYAN bir satir kalirdi — depoda daha
// once yasanmis "olu baglanti" sinifinin ta kendisi.
//
// SORGU PARAMETRESI, AYRI ROTA DEGIL. `/profil/guvenlik` gibi alt rotalar
// acmak, `ROTA_ROLLERI` ve `rotaYuzeyi` TAM ESLESME yaptigi icin her biri
// icin ayri bir rol kaydi gerektirirdi (bkz. `lib/menu.ts`teki `sorgu`
// notu). Tek rota + sorgu, rol kapisini TEK yerde tutar.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

export type ProfilBolumId =
  | "hesap"
  | "guvenlik"
  | "bildirim"
  | "sifre"
  | "hesap-sil";

export interface ProfilBolumu {
  id: ProfilBolumId;
  anahtar: SozlukAnahtari;
  /** Geri alinamaz eylem — menude ayri renkte cizilir. */
  tehlikeli?: boolean;
}

/** Sira ekranda gorunen siradir; "Hesabimi sil" bilerek EN SONDA. */
export const PROFIL_BOLUMLERI: readonly ProfilBolumu[] = [
  { id: "hesap", anahtar: "profilHesapBilgileri" },
  { id: "guvenlik", anahtar: "profilGuvenlikGiris" },
  { id: "bildirim", anahtar: "profilBildirimAyarlari" },
  { id: "sifre", anahtar: "profilSifreDegistir" },
  { id: "hesap-sil", anahtar: "profilHesabimiSil", tehlikeli: true },
];

export const PROFIL_BOLUM_IDLERI = PROFIL_BOLUMLERI.map((b) => b.id);

/** Bir bolumun adresi. */
export function profilBaglantisi(id: ProfilBolumId): string {
  return `/profil?bolum=${id}`;
}
