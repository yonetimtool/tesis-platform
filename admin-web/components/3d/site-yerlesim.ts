/**
 * (P161) SITE YERLESIMI — sahnenin GEOMETRI MATEMATIGI.
 *
 * =========================================================================
 * NEDEN AYRI DOSYA
 * =========================================================================
 * Burada `three` YOK. Bu dosya saf sayi hesabi yapar: blok kutlesinin
 * olculeri, dairelerin cephedeki yerleri, kat yukseklikleri. Ayri
 * durmasinin iki somut faydasi var:
 *
 *   1. TEST EDILEBILIR. Sahne dosyasi jsdom'da calismaz (WebGL yok);
 *      yerlesim kurallari ise dogrudan olculebilir. "Yuz daire yuz ayri
 *      mesh olmasin" ya da "veri yoksa bos ekran cikmasin" gibi kurallar
 *      sahneyi acmadan dogrulanir.
 *   2. ANA PAKETE GIRMEZ diye ugrasmaya gerek yok — `three` ice
 *      aktarilmadigi icin zaten kucuk.
 *
 * =========================================================================
 * OLCEK VERIDEN GELIR (brief'in kurali)
 * =========================================================================
 * Hicbir olcu elle yazilmaz: kutle yuksekligi KAT SAYISINDAN, taban alani
 * KAT BASINA DAIRE SAYISINDAN turer. Iki katli 4 daireli bir site ile
 * on katli 120 daireli bir site AYNI sahneyi vermez.
 */

/** Bir kat = bu kadar dunya birimi. Tek olcek sabiti; gerisi bundan turer. */
export const KAT_YUKSEKLIGI = 0.62;
/** Zemin ile ilk pencere sirasi arasindaki bosluk (giris kati). */
export const TABAN_PAYI = 0.18;
/** Bloklar arasi en kucuk aciklik — kutleler birbirine girmesin. */
export const BLOK_ARALIGI = 1.6;
/** Daire basina taban alani (dunya birimi kare). */
export const ALAN_PAYI = 0.36;
/** Kutle en-boy orani — gercek apartmanlar 1:1 ile 1:1.6 arasindadir. */
export const EN_BOY = 1.5;

export type DaireDurumu = "normal" | "borclu" | "alarm" | "pasif";

export interface SahneDairesi {
  id: string;
  no: string;
  /** Kat (0 = zemin). building-map bunu veriden getirir. */
  kat: number;
  /** Kattaki sira — cephedeki yerini belirler. */
  sira: number;
  durum: DaireDurumu;
}

export interface SahneBlogu {
  id: string;
  ad: string;
  daireler: SahneDairesi[];
}

/** Bir dairenin cephedeki yeri — blok merkezine GORE. */
export interface DaireYeri {
  daire: SahneDairesi;
  /** Blok merkezine gore konum. */
  x: number;
  y: number;
  z: number;
  /** Pencerenin baktigi yon (Y ekseni etrafinda radyan). */
  yon: number;
}

export interface BlokOlcusu {
  blok: SahneBlogu;
  /** Kutle merkezinin site duzlemindeki yeri. */
  merkezX: number;
  merkezZ: number;
  genislik: number;
  derinlik: number;
  yukseklik: number;
  katSayisi: number;
  /** Kattaki en kalabalik daire sayisi. */
  katBasinaDaire: number;
  daireYerleri: DaireYeri[];
}

/**
 * Dikdortgen cephe uzerine `n` esit aralikli nokta dagitir.
 *
 * NEDEN CEVRE, NEDEN TEK CEPHE DEGIL: tek cepheye dizmek 40 daireli bir
 * kati 40 pencere genisliginde bir duvara cevirirdi — bina degil, cit.
 * Cevreye dagitinca kutle gercek bir apartman oranina oturur ve HER
 * PENCERE HALA TEK BIR DAIREDIR (uydurma pencere yok).
 */
export function cepheNoktalari(
  n: number,
  genislik: number,
  derinlik: number,
): { x: number; z: number; yon: number }[] {
  if (n <= 0) return [];
  const yariG = genislik / 2;
  const yariD = derinlik / 2;
  const cevre = 2 * (genislik + derinlik);
  const noktalar: { x: number; z: number; yon: number }[] = [];
  for (let i = 0; i < n; i++) {
    // Yarim adim kaydirma: ilk daire tam koseye gelmesin.
    let s = ((i + 0.5) / n) * cevre;
    if (s < genislik) {
      noktalar.push({ x: -yariG + s, z: yariD, yon: 0 });
      continue;
    }
    s -= genislik;
    if (s < derinlik) {
      noktalar.push({ x: yariG, z: yariD - s, yon: Math.PI / 2 });
      continue;
    }
    s -= derinlik;
    if (s < genislik) {
      noktalar.push({ x: yariG - s, z: -yariD, yon: Math.PI });
      continue;
    }
    s -= genislik;
    noktalar.push({ x: -yariG, z: -yariD + s, yon: -Math.PI / 2 });
  }
  return noktalar;
}

/**
 * DAIRE PENCERESININ OLCEGI — RENK TEK KANAL OLMASIN.
 *
 * OLCULEN SORUN: `alarm` (kirmizi) ile `normal` (mavi) neredeyse AYNI
 * ISIKLIKTA. Ikisi de duvardan ayriliyor ama BIRBIRINDEN yalnizca RENK
 * TONUYLA ayriliyorlar (oran 1.01). Renk korlugu olan bir kullanici,
 * gri tonlamali bir cikti ya da parlak gunes altindaki bir ekran icin
 * bu tek kanal yeterli degil.
 *
 * Rengi bozmak yerine IKINCI BIR KANAL eklendi: alarmli daire biraz
 * BUYUK cizilir. Instancing'de olcek zaten ornek matrisinde tasiniyor,
 * yani bedeli sifir.
 */
export function daireOlcegi(durum: DaireDurumu): number {
  return durum === "alarm" ? 1.32 : 1;
}

/** Kat sayisi = en yuksek kat + 1; en az 1 (kat bilgisi yoksa tek kat). */
export function katSayisi(daireler: SahneDairesi[]): number {
  let enUst = 0;
  for (const d of daireler) enUst = Math.max(enUst, d.kat);
  return Math.max(1, enUst + 1);
}

/** Kattaki EN KALABALIK daire sayisi — taban alanini bu belirler. */
export function katBasinaDaire(daireler: SahneDairesi[]): number {
  const sayac = new Map<number, number>();
  for (const d of daireler) sayac.set(d.kat, (sayac.get(d.kat) ?? 0) + 1);
  let enCok = 1;
  for (const n of sayac.values()) enCok = Math.max(enCok, n);
  return enCok;
}

/**
 * Tek bir blogun olculeri + her dairenin cephedeki yeri.
 *
 * Taban alani kat basina daire sayisindan turer ama KAREYE YAKIN tutulur:
 * gercek apartmanlar 1:1 ile 1:1.6 arasindadir; oran serbest birakilinca
 * kalabalik katlar duvara donusuyordu.
 */
export function blokOlcusu(blok: SahneBlogu, merkezX: number, merkezZ: number): BlokOlcusu {
  const kat = katSayisi(blok.daireler);
  const kbd = katBasinaDaire(blok.daireler);
  // TABAN ALANDAN TURER, CEVREDEN DEGIL.
  //
  // Ilk surum cevreyi daire sayisiyla carpip kenari oradan cikariyordu ve
  // sonuc KULE oluyordu: 7 katli 6 daireli bir blok 1.1 x 1.0 tabanla 4.5
  // birim yukseliyordu (1:4 oran). Gercek apartman oyle durmaz. Her daire
  // bir TABAN ALANI tutar; kenarlar o alandan ve sabit bir en-boy
  // oranindan cikar.
  const alan = Math.max(4, kbd) * ALAN_PAYI;
  const genislik = Math.max(1.3, Math.sqrt(alan * EN_BOY));
  const derinlik = Math.max(0.95, alan / genislik);
  const yukseklik = TABAN_PAYI + kat * KAT_YUKSEKLIGI;

  // Kat icindeki siralamayi KARARLI yap: ayni veri her zaman ayni sahne.
  const katlar = new Map<number, SahneDairesi[]>();
  for (const d of blok.daireler) {
    const liste = katlar.get(d.kat);
    if (liste) liste.push(d);
    else katlar.set(d.kat, [d]);
  }

  const daireYerleri: DaireYeri[] = [];
  for (const [k, liste] of katlar) {
    liste.sort((a, b) => a.sira - b.sira || a.no.localeCompare(b.no));
    const noktalar = cepheNoktalari(liste.length, genislik, derinlik);
    for (let i = 0; i < liste.length; i++) {
      const p = noktalar[i];
      daireYerleri.push({
        daire: liste[i],
        x: p.x,
        // Pencere katin ORTASINA gelir, tabanina degil.
        y: TABAN_PAYI + k * KAT_YUKSEKLIGI + KAT_YUKSEKLIGI / 2,
        z: p.z,
        yon: p.yon,
      });
    }
  }

  return {
    blok,
    merkezX,
    merkezZ,
    genislik,
    derinlik,
    yukseklik,
    katSayisi: kat,
    katBasinaDaire: kbd,
    daireYerleri,
  };
}

/**
 * Butun sitenin yerlesimi.
 *
 * BLOKLAR IZGARAYA DIZILIR ve izgara adimi EN BUYUK BLOGA gore secilir —
 * sabit adim kullanmak, buyuk bloklarin birbirine girmesine yol aciyordu.
 * Konum verisi API'de YOK; rastgelelik yerine KARARLI bir duzen kuruldu
 * (ayni girdi -> ayni sahne; yoksa her cizimde site tasinirdi).
 */
export function siteYerlesimi(bloklar: SahneBlogu[]): {
  bloklar: BlokOlcusu[];
  /** Sitenin (platformun) yaricapi. */
  yaricap: number;
  /** En yuksek kutlenin yuksekligi — kamera kadrajini bu belirler. */
  enYuksek: number;
} {
  if (bloklar.length === 0) return { bloklar: [], yaricap: 5, enYuksek: 3 };

  const olculer = bloklar.map((b) => blokOlcusu(b, 0, 0));
  let enGenis = 0;
  for (const o of olculer) enGenis = Math.max(enGenis, o.genislik, o.derinlik);
  const adim = enGenis + BLOK_ARALIGI;

  const satirBoyu = Math.ceil(Math.sqrt(olculer.length));
  const satirSayisi = Math.ceil(olculer.length / satirBoyu);
  const yerlesik = olculer.map((o, i) => {
    const sx = (i % satirBoyu) - (satirBoyu - 1) / 2;
    const sz = Math.floor(i / satirBoyu) - (satirSayisi - 1) / 2;
    return { ...o, merkezX: sx * adim, merkezZ: sz * adim };
  });

  const yariEn = ((satirBoyu - 1) / 2) * adim + enGenis / 2;
  const yariBoy = ((satirSayisi - 1) / 2) * adim + enGenis / 2;
  // Platform kutleleri KUCUK BIR PAYLA cevreler: peyzaj, yol ve otopark
  // bu payin icine sigar.
  const yaricap = Math.hypot(yariEn, yariBoy) + 2.4;

  let enYuksek = 0;
  for (const o of yerlesik) enYuksek = Math.max(enYuksek, o.yukseklik);

  return { bloklar: yerlesik, yaricap, enYuksek };
}

/**
 * KAMERA UZAKLIGI — butun site kadraja SIGSIN.
 *
 * OLCULEN KUSUR: kamera sabit bir uzaklikta duruyordu ve yedi katli
 * bloklarin ustu kadrajin disinda kaliyordu. Uzaklik artik sitenin
 * SINIR KURESINDEN turer: taban yaricapi ve kutle yuksekligi birlikte
 * bir kure verir, kure de gorus acisina gore bir uzaklik.
 *
 * `pay` (>1) kenar boslugu birakir — kutleler tam cerceveye yapismasin.
 */
export function kameraUzakligi(
  yaricap: number,
  yukseklik: number,
  gorusAcisiDerece: number,
  pay = 1.06,
): number {
  // IZOMETRIK BAKISTA DIKEY IZDUSUM, kutlenin yuksekligi ile taban
  // derinliginin TOPLAMINA yakindir: yukaridan bakan kamera icin taban
  // da ekranda dikey yer kaplar. Sinir KURESI kullanmak iki uc da
  // yaniltiyordu — yayvan bir sitede fazla uzak, ince yuksek bir blokta
  // fazla yakin duruyordu (blogun ustu kadrajdan tasiyordu).
  const izdusum = yukseklik + yaricap * 0.9;
  const yariAci = (gorusAcisiDerece / 2) * (Math.PI / 180);
  return (izdusum / 2 / Math.tan(yariAci)) * pay;
}

/**
 * VERI YOKSA MAKUL BIR SITE (brief: "asla bos ekran gosterme").
 *
 * Bu UYDURMA VERI DEGIL, YER TUTUCUDUR: kimlikleri `ornek:` onekli ve
 * cagiran bunlari tiklanabilir yapmaz. Amaci, tesisin daireleri henuz
 * girilmemisken panelin bos bir dikdortgen gostermemesi.
 */
export const ORNEK_ONEK = "ornek:";

export function ornekSite(): SahneBlogu[] {
  const yap = (ad: string, kat: number, katBasina: number): SahneBlogu => ({
    id: `${ORNEK_ONEK}${ad}`,
    ad,
    daireler: Array.from({ length: kat * katBasina }, (_, i) => ({
      id: `${ORNEK_ONEK}${ad}-${i}`,
      no: String(i + 1),
      kat: Math.floor(i / katBasina),
      sira: i % katBasina,
      durum: "normal" as DaireDurumu,
    })),
  });
  return [yap("A", 6, 4), yap("B", 8, 4), yap("C", 5, 6)];
}
