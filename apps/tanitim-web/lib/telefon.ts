/**
 * (P123 · P227 §3 · P233 §3) TELEFON — bicimleme, dogrulama, saklama.
 *
 * =========================================================================
 * (P233 §3) TR SABITI KALKTI — ULKE KODU ARTIK DEGERIN PARCASI
 * =========================================================================
 * Eskiden bu dosya TR'ye sabitti: her numaranin basina kosulsuz `+90`
 * konuyordu (bkz. `lib/ulke-telefon.ts` bas yorumu — yabanci numara
 * SESSIZCE baska bir numaraya donusuyordu).
 *
 * KULLANICININ GORDUGU DEGER artik ulke kodunu TASIR:
 * `(+90) 541 922 23 88`. Bu, cagiran 8 ekrani degistirmemek icin secilen
 * tasarimdir: `telefonGiris`/`telefonHatasi`/`telefonNormalle` yine TEK
 * bir dizge alir, ulkeyi o dizgeden cozer. Ulke AYRI bir alan olsaydi
 * her form ikinci bir durum parcasi tasimak zorunda kalirdi ve onuncu
 * form onu unuturdu (P166 §9'daki hatanin aynisi).
 *
 * =========================================================================
 * GOSTERIM ILE SAKLAMA AYRI
 * =========================================================================
 * Sunucuya giden deger yine E.164 (`+905419222388`) — `normalize_phone`
 * bosluk/parantez siler, bicim degisiminden ETKILENMEZ. Telefon GLOBAL
 * BENZERSIZ anahtar oldugu icin ikisini karistirmak eski kayitlari
 * erisilemez kilardi.
 *
 * BASTAKI `0` KALKTI: `0(543) 199 29 04` -> `(+90) 543 199 29 04`. Ulke
 * kodu gorunurken ayrica ulusal `0` ongoster bulundurmak, numarayi iki
 * kez "ulkelendirmek" olurdu (`+90 0543...` diye okunur).
 */
import {
  ULKELER,
  VARSAYILAN_ULKE,
  type Ulke,
  ulkeBul,
  ulkeyiCoz,
  ulusalBicimle,
} from "@/lib/ulke-telefon";

export { ULKELER, VARSAYILAN_ULKE, ulkeBul, ulkeEtiketi } from "@/lib/ulke-telefon";
export type { Ulke } from "@/lib/ulke-telefon";

/** TR hane sayisi — geriye donuk; yeni kod ulkenin `enAz/enCok`unu okur. */
export const TELEFON_HANE_SAYISI = 10;

const TR = ulkeBul(VARSAYILAN_ULKE)!;

/**
 * Ham dizgeyi (ulke, ulusal haneler) ciftine ayirir.
 *
 * ULKE NEREDEN OKUNUR — sirayla:
 *  1. `(+90) ...` / `+90...` / `0090...` — ACIK ulke kodu.
 *  2. Bastaki tek `0` (`0543...`) — ESKI TR bicimi; hala gelebilir
 *     (tarayici otomatik doldurma, yapistirma, eski localStorage).
 *  3. Hicbiri yoksa ULKE YOK doner (`null`) — sessizce TR sayilmaz;
 *     sessiz varsayim bu turun duzelttigi kusurun ta kendisi.
 */
export function telefonParcala(ham: string): {
  ulke: Ulke | null;
  haneler: string;
} {
  const metin = (ham ?? "").trim();
  let s = metin.replace(/\D/g, "");
  if (!s) return { ulke: null, haneler: "" };

  const acikKod = metin.includes("+") || s.startsWith("00");
  if (s.startsWith("00")) s = s.slice(2);

  if (acikKod) {
    const c = ulkeyiCoz(s);
    if (c) return { ulke: c.ulke, haneler: c.ulusal };
    // Kod taniniyor ama hane sayisi henuz tutmuyor (kullanici YAZIYOR):
    // en uzun eslesen kodu soy, kalani ulusal say.
    const kodlar = [...new Set(ULKELER.map((u) => u.arama))].sort(
      (a, b) => b.length - a.length,
    );
    for (const arama of kodlar) {
      if (s.startsWith(arama)) {
        const u = ULKELER.find((x) => x.arama === arama)!;
        return { ulke: u, haneler: s.slice(arama.length) };
      }
    }
    return { ulke: null, haneler: s };
  }

  if (s.startsWith("0")) return { ulke: TR, haneler: s.slice(1) };

  // (P233 §3) `+` YOKSA DA ULKE KODU ARANIR — ama YALNIZ hane sayisi TAM
  // tuttugunda. `905431992904` numarayi yazmanin cok yaygin bir bicimidir
  // (backend `kimlik.py` bunun icin ayrica telafi tasiyor) ve ilk yazimda
  // TASMA sayiliyordu: 12 hane, TR siniri 10. Olcum yakaladi.
  //
  // Hane sayisi TUTMAK ZORUNDA: aksi halde `5431992904` -> AR (`+54`) diye
  // cozulur ve kullanicinin yazdigi TR numarasi Arjantin numarasina
  // donerdi. Tam eslesme sarti bunu imkansiz kilar.
  const c = ulkeyiCoz(s);
  if (c) return { ulke: c.ulke, haneler: c.ulusal };
  return { ulke: null, haneler: s };
}

/** Ulusal haneler (ulke kodu HARIC), ulkenin en cok hanesine KIRPILMIS. */
export function telefonHaneleri(ham: string): string {
  const { ulke, haneler } = telefonParcala(ham);
  const sinir = (ulke ?? TR).enCok;
  return haneler.length > sinir ? haneler.slice(0, sinir) : haneler;
}

/** Ulkenin en cok hanesi asildi mi — KESMEDEN ONCE sorulur (P227 §3). */
export function telefonTasti(ham: string): boolean {
  const { ulke, haneler } = telefonParcala(ham);
  return haneler.length > (ulke ?? TR).enCok;
}

/** `(+90) 541 922 23 88` — eksikse kismi. */
export function telefonBicimle(haneler: string, ulke: Ulke | null): string {
  const govde = ulusalBicimle(ulke ?? TR, haneler);
  if (!ulke) return govde;
  return govde ? `(+${ulke.arama}) ${govde}` : `(+${ulke.arama}) `;
}

/** Kutuda gorunecek metin (fikirsiz/idempotent). */
export function telefonGiris(ham: string): string {
  const { ulke } = telefonParcala(ham);
  return telefonBicimle(telefonHaneleri(ham), ulke);
}

/** Sunucuya gidecek deger — E.164. Ulke yoksa BOS (yanlis kod uydurulmaz). */
export function telefonNormalle(ham: string): string {
  const { ulke } = telefonParcala(ham);
  const h = telefonHaneleri(ham);
  if (!h) return "";
  if (!ulke) return "";
  return `+${ulke.arama}${h}`;
}

/** Ulke kodunu DEGISTIRIR, girilmis haneleri korur. */
export function telefonUlkeyiDegistir(ham: string, kod: string): string {
  const u = ulkeBul(kod);
  if (!u) return ham;
  const { haneler } = telefonParcala(ham);
  const kirpik = haneler.length > u.enCok ? haneler.slice(0, u.enCok) : haneler;
  return telefonBicimle(kirpik, u);
}

export type TelefonHatasi =
  | "bos"
  | "eksik"
  | "gecersizOnEk"
  | "tasma"
  | "ulkeYok";

/**
 * [ham] icin hata kimligi; `null` = gecerli.
 *
 * SIRA ONEMLI: tasma once sorulur (numara kirpildigi icin digerleri
 * GECERLI gorunur ve kullanici hatayi hic gormezdi).
 */
export function telefonHatasi(
  ham: string,
  zorunlu = true,
  /** (P248 §2) Sabit hat kabul (firma/tedarikci): TR cep on eki (`5`)
   *  ARANMAZ. Kisiye ait alanlarda verilmez — orada cep beklenir. */
  sabitHat = false,
): TelefonHatasi | null {
  const { ulke, haneler } = telefonParcala(ham);
  if (haneler.length > (ulke ?? TR).enCok) return "tasma";
  if (!haneler) return zorunlu ? "bos" : null;
  if (!ulke) return "ulkeYok";
  // ON EK KURALI YALNIZ TR'DE: diger ulkelerin cep bloklarini
  // dogrulamak icin elimizde guvenilir veri yok; uydurulmus bir kural
  // gercek bir numarayi reddederdi.
  if (!sabitHat && ulke.mobilOnEk && !haneler.startsWith(ulke.mobilOnEk)) {
    return "gecersizOnEk";
  }
  if (haneler.length < ulke.enAz) return "eksik";
  return null;
}

/** Kutuda gorunecek ULUSAL kisim (ulke kodu AYRI kutuda cizildigi icin). */
export function telefonUlusal(ham: string): string {
  const { ulke } = telefonParcala(ham);
  return ulusalBicimle(ulke ?? TR, telefonHaneleri(ham));
}

/**
 * Ulusal kutuya yazilan/yapistirilan metnin HANELERI.
 *
 * BASTAKI SIFIRLAR ATILIR (`0543…` -> `543…`). Ulke kodu ayri kutuda
 * dururken alanin icine ulusal govde ekini (`0`) de yazmak, numarayi iki
 * kez "ulkelendirmek" olur: olcumde `+90` + `05431992904` = 11 hane ->
 * TASMA cikti. Hicbir ulkede ulusal anlamli numara `0` ile baslamaz.
 */
export function ulusalTemizle(metin: string): string {
  return (metin ?? "").replace(/\D/g, "").replace(/^0+/, "");
}

/**
 * (P248 §2) GIRIS KIMLIGI TELEFON MU — tek alanli giris (P205) icin.
 *
 * KARAR: alan RAKAM, `+` ya da `(` ile baslayip YALNIZ telefon
 * karakterleri tasiyorsa (rakam, bosluk, `+ ( ) - .`) telefon moduna
 * gecilir; harf ya da `@` gorulunce e-posta modunda kalinir. Kullaniciya
 * "hangisiyle giriyorsun" diye SORULMAZ (P205'in ilkesi) — ama telefon
 * yazana ulke kodu secicisi ve bicimleme, diger ekranlardaki gibi
 * gorunur.
 *
 * Bir e-posta rakamla baslayabilir (`123ali@...`): ilk harfte alan
 * e-posta moduna DONER ve yazilan metin korunur — kayip yok.
 */
export function kimlikTelefonMu(metin: string): boolean {
  const s = (metin ?? "").trim();
  if (!s) return false;
  return /^[\d+(]/.test(s) && /^[\d\s+().-]+$/.test(s);
}

/**
 * (P248 §2) Giris ucuna gidecek kimlik: telefonsa E.164, degilse kirpilmis
 * metin. Ulke cozulemezse HAM metin gider — sunucu `normalize_phone` ile
 * son karari verir ve gecersizse jenerik 401 doner (P205'in bilincli
 * belirsizligi korunur).
 */
export function kimlikGonderimDegeri(ham: string): string {
  const s = (ham ?? "").trim();
  if (!kimlikTelefonMu(s)) return s;
  return telefonNormalle(s) || s;
}
