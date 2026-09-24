/**
 * (P247 §2) PROFILDEN ROL GECISI — YONETICI <-> SAKIN (web tarafinin kararlari).
 *
 * =========================================================================
 * NE, NEREDE
 * =========================================================================
 * Sunucu tek kaynaktir: `GET /me` AKTIF rolu (`role`) ve gecilebilecek
 * rolleri (`roller`, sunucu adlariyla: `yonetici`, `resident`) doner;
 * `POST /me/rol-gecis` yeni jeton cifti uretir (bkz.
 * backend/app/rol_gecisi.py). Web bu modulde yalniz SUNLARI karar verir:
 *
 *   1. sunucu rolunu WEB rolune cevirmek (`resident` + cift rol ->
 *      `SAKIN_MODU`; gerekce `lib/yuzey.ts`),
 *   2. bildirim hedefini AKTIF rolde bulamazsa DIGER rolde aramak
 *      (otomatik mod gecisi — ana ajan karari, mobilin ikizi).
 *
 * Saf fonksiyonlar: React'e ve cerezlere bagli degil, testte dogrudan
 * cagrilir.
 */
import { bildirimRotasi } from "./bildirim-rotasi";
import { SAKIN_MODU, rotaRoldeGorunur } from "./yuzey";

/** Sunucunun rol adlari (`POST /me/rol-gecis` govdesi). */
export type SunucuRolu = "yonetici" | "resident";

/** `GET /me` yanitinin bu modulun okudugu kismi. */
export interface RolDurumu {
  role?: string | null;
  roller?: string[] | null;
}

/**
 * Sunucu rolu -> web rolu. `resident` YALNIZ cift rollu kiside
 * `SAKIN_MODU`dur; saf sakin `resident` kalir (P129: mobil-yalniz).
 */
export function webRolu(d: RolDurumu | null | undefined): string | null {
  const rol = d?.role ?? null;
  if (rol === "resident" && (d?.roller ?? []).includes("yonetici")) {
    return SAKIN_MODU;
  }
  return rol;
}

/** Menu cizilir mi? Yalniz IKI rolu olan kisi (tek eleman = menu YOK). */
export function gecisMenusuVar(d: RolDurumu | null | undefined): boolean {
  return (d?.roller ?? []).length === 2;
}

/** Web rolunun sunucudaki karsiligi (gecis istegi icin). */
export function sunucuRolu(webRol: string | null): SunucuRolu | null {
  if (webRol === SAKIN_MODU) return "resident";
  if (webRol === "yonetici") return "yonetici";
  return null;
}

/** Sunucu rolu -> gecisten SONRAKI web rolu. */
export function gecisSonrasiWebRolu(rol: SunucuRolu): string {
  return rol === "resident" ? SAKIN_MODU : "yonetici";
}

/** Cift rollu kisinin OTEKI rolu (sunucu adiyla); yoksa `null`. */
export function digerRol(d: RolDurumu | null | undefined): SunucuRolu | null {
  if (!gecisMenusuVar(d)) return null;
  const aktif = d?.role ?? null;
  const oteki = (d?.roller ?? []).find((r) => r !== aktif);
  return oteki === "yonetici" || oteki === "resident" ? oteki : null;
}

/**
 * SAKIN MODUNDA bildirim -> ekran.
 *
 * `lib/bildirim-rotasi.ts` YONETIM ekranlarina isaret eder (web bildirim
 * listesi P241'de yalniz yonetimdeydi). Sakin modunda ayni tipin dogru
 * ekrani SAKININ kendi sayfasidir — mobildeki `sikayetlerim`/`myDues`
 * ayriminin web karsiligi. Tip burada yoksa sakin modunda hedef yoktur.
 */
export const SAKIN_BILDIRIM_ROTALARI: Record<string, string> = {
  talep_yanit: "/taleplerim",
  talep_is_emri: "/taleplerim",
  talep_cozuldu: "/taleplerim",
  talep_reddedildi: "/taleplerim",
  sikayet_cozuldu: "/taleplerim",
  gurultu_uyari_sakin: "/taleplerim",
  rezervasyon: "/rezervasyonlarim",
  rezervasyon_karar: "/rezervasyonlarim",
  duyuru: "/duyurular",
  etkinlik: "/etkinlikler",
  aidat_borc: "/aidatim",
  aidat_odendi: "/aidatim",
  aidat_hatirlatma: "/aidatim",
  tahsilat: "/aidatim",
  tahsilat_toplu: "/aidatim",
  iade: "/aidatim",
  iptal: "/aidatim",
};

/**
 * (P247 §5 ile ortak) KISIYE SAKIN OLARAK giden bildirim tipleri —
 * `backend/app/push_gorunum.py: SAKIN_KIMLIKLERI`in AYNISI.
 *
 * Sunucu push'a `hedef_rol` koyar ama KALICI bildirim satirinda o alan
 * yoktur; web listesi ayni karari tipten verir. Cift rollu kiside bu
 * tipler SAKIN MODUNDA acilir (yonetici modundayken bile): "kargonuz
 * geldi" yoneticiye degil daire sakinine yazilmistir.
 */
export const SAKIN_KIMLIKLERI: ReadonlySet<string> = new Set([
  "kargo", "kargo_teslim", "ziyaretci", "rezervasyon",
  "sikayet_cozuldu", "talep_is_emri", "talep_cozuldu", "talep_reddedildi",
  "erisim_onaylandi", "erisim_reddedildi",
  "aidat_borc", "aidat_odendi", "aidat_hatirlatma",
  "gurultu_uyari_sakin", "akilli_ev_kacak", "akilli_ev_yangin",
]);

function aday(tip: string, webRol: string | null): string | null {
  if (webRol === SAKIN_MODU) return SAKIN_BILDIRIM_ROTALARI[tip] ?? null;
  return bildirimRotasi(tip);
}

/** Bildirimin gidecegi yer; `gecis` doluysa once o role gecilir. */
export interface BildirimHedefi {
  rota: string;
  gecis: SunucuRolu | null;
}

/**
 * (P247 §2) BILDIRIM HEDEFI + OTOMATIK MOD GECISI.
 *
 * KARAR (ana ajan, mobille ayni): hedef AKTIF rolde gorunur degilse ve
 * kisinin DIGER rolunde gorunurse -> once o role gecilir, sonra hedefe
 * gidilir (kullaniciya "Sakin moduna gecildi" bildirilir). Iki rolde de
 * yoksa `null`: uydurma bir hedef vermek yerine satir yalnizca okunur.
 */
export function bildirimHedefi(
  tip: string,
  aktifWebRol: string | null,
  durum?: RolDurumu | null,
): BildirimHedefi | null {
  // 1) SAKINE yazilmis bildirim (hedef_rol = resident): cift rollu kiside
  //    once SAKIN ekrani denenir — yonetici modundaysa sakine gecilir.
  //    Web'de sakin karsiligi olmayan tip (kargo, ziyaretci: sakin
  //    sayfalari mobil-yalniz) asagidaki genel kurala duser.
  const cift = aktifWebRol === SAKIN_MODU || digerRol(durum) !== null;
  if (cift && SAKIN_KIMLIKLERI.has(tip)) {
    const sakinRota = SAKIN_BILDIRIM_ROTALARI[tip];
    if (sakinRota && rotaRoldeGorunur(sakinRota, SAKIN_MODU)) {
      return {
        rota: sakinRota,
        gecis: aktifWebRol === SAKIN_MODU ? null : "resident",
      };
    }
  }
  // 2) Genel kural: aktif modda, yoksa diger modda.
  const buradan = aday(tip, aktifWebRol);
  if (buradan && rotaRoldeGorunur(buradan, aktifWebRol)) {
    return { rota: buradan, gecis: null };
  }
  const oteki = digerRol(durum);
  if (!oteki) return null;
  const otekiWeb = gecisSonrasiWebRolu(oteki);
  if (otekiWeb === aktifWebRol) return null;
  const oradan = aday(tip, otekiWeb);
  if (oradan && rotaRoldeGorunur(oradan, otekiWeb)) {
    return { rota: oradan, gecis: oteki };
  }
  return null;
}

/**
 * Gecisten sonraki sayfa yuklemesinde gosterilecek bilgi (oturum deposu).
 * Gecis TAM SAYFA YUKLEMESIYLE biter (onbellek sifirlanir — bkz.
 * `useRolGecisi`); bildirim o yuklemeyi asmak icin burada bekler.
 */
export const ROL_GECIS_BILGI_ANAHTARI = "yz.rolGecildi";
