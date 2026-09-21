/**
 * (P161) SAHNE PALETI — koyu ve acik tema AYRI TANIMLI.
 *
 * =========================================================================
 * NEDEN CSS DEGISKENI OKUNMUYOR
 * =========================================================================
 * WebGL malzemesi `var(--yz-*)` ANLAMAZ; renk GPU'ya sayi olarak gider.
 * Bu yuzden sahnenin kendi paleti var. Ama palet ARAYUZDEN KOPUK DEGIL:
 * durum renkleri `--yz-*-edge` ailesinin sayisal karsiligidir, yani
 * rozet/harita ile ayni dili konusur.
 *
 * =========================================================================
 * IKI TEMA, IKI ISIK KURULUMU (brief §4)
 * =========================================================================
 * Brief "3D sahne isiklandirmasi ayri tanimlanacak" der. Koyu temada
 * SERIN MAVI anahtar isik + dusuk ortam (gece maketi); acik temada NOTR
 * GUN ISIGI + yuksek ortam (masa ustu maket). Ayni sahneyi iki kez
 * "renk cevirerek" elde etmek, koyu temada kutleleri gri camura
 * ceviriyordu.
 */
import type { DaireDurumu } from "./site-yerlesim";

export interface SahnePaleti {
  /** Tuval arka plani. */
  arkaPlan: string;
  /** Platform (maket tablasi). */
  platform: string;
  platformKenar: string;
  /** Zemin ortusu — cim/peyzaj. */
  cim: string;
  /** Yol ve otopark asfalti. */
  yol: string;
  /** Yaya yolu. */
  patika: string;
  /** Havuz. */
  havuz: string;
  /** Agac govdesi ve tepesi. */
  agacGovde: string;
  agacTepe: string;
  /** Bina govdesi + kat cizgileri + catisi. */
  kutle: string;
  katCizgisi: string;
  cati: string;
  balkon: string;
  /** Pencere (daire) — durumsuz temel renk. */
  pencere: string;
  /** Isik seridi. */
  serit: string;
  /** Isiklar. */
  ortamIsik: string;
  ortamGuc: number;
  anahtarIsik: string;
  anahtarGuc: number;
  dolguIsik: string;
  dolguGuc: number;
}

/**
 * DAIRE DURUM RENKLERI — TEMAYA BAGLI, cunku OLCULDU.
 *
 * =========================================================================
 * ILK PALET IKI TEMADA DA DUSUYORDU
 * =========================================================================
 * Tek bir renk kumesi vardi ve duvar renginin degistigi hesaba
 * katilmamisti. Olcum (WCAG 1.4.11, anlamli grafik ogesi icin 3.0):
 *
 *   acik temada duvar #e8edf2 uzerinde: normal 2.10, borclu 2.15,
 *   secim 2.23 — UCU DE DUSUK.
 *   koyu temada duvar #8f9aa6 uzerinde: 1.09 ile 1.58 arasi — HEPSI.
 *
 * Yani koyu temada pencere ile duvari ayirt etmek neredeyse imkansizdi
 * ve "daire durumunu renkle goster" maddesi kagit uzerinde kaliyordu.
 *
 * COZUM IKI YONLU: koyu temada duvar KOYULASTI (#5a646e) ve pencereler
 * PARLADI — gece maketinde isikli pencere zaten dogru okuma. Acik temada
 * duvar ayni kaldi, pencereler koyulastirildi. Butun degerler >= 3.2
 * (esikten pay birakilarak) ve `tests/sahne-kontrast.test.ts` ile kilitli.
 *
 * `pasif` KASTEN SOLUK KALDI: "kayit kapali" bir DURUM DEGIL, bir YOKLUK;
 * onu uyari renginde gostermek olmayan bir sorunu isaret ederdi. Ama artik
 * SOLUK OLMAK ile GORUNMEZ OLMAK ayrildi — o da esigi geciyor.
 */
/**
 * (P244 §10e) DEGERLER ARTIK TOKEN AILELERINDEN TURETILIYOR.
 *
 * Dosya basindaki aciklama "durum renkleri `--yz-*-edge` ailesinin
 * sayisal karsiligidir" diyordu ama DEGILDI: eski degerler elle
 * secilmis, doygunlugu dusurulmus tonlardi (#6586a4, #ad7930...).
 * Iddia ile kod ayrisikti.
 *
 * ARTIK GERCEKTEN TURETILIYOR. Yontem P244 asama 1'in aynisi: token'in
 * TON ve DOYGUNLUGU korunur, yalniz ISIKLIK duvara karsi esigi tutana
 * kadar kaydirilir.
 *
 *   normal -> `--yz-accent`   (#2563eb)
 *   borclu -> `--yz-warning`  (#f59e0b)
 *   alarm  -> `--yz-danger`   (#ef4444)
 *   pasif  -> `--yz-text-2`   (#566173)
 *
 * IKI TON BILEREK "EN SAKIN GECEN" DEGER:
 *   * `normal` cogunluk durumudur; ham vurgu (acik temada 5.17) butun
 *     cepheyi doygun maviye boyardi ve borclu/alarm ayirt edilemezdi.
 *     Esigi tutan EN SAKIN ton secildi (3.42).
 *   * `pasif` bir DURUM DEGIL bir YOKLUK (P161 karari). Onu one
 *     cikarmak olmayan bir sorunu isaret ederdi; yine esige en yakin
 *     ton (3.26).
 * Borclu ve alarm ise esikten pay birakilarak SECILEBILIR kaldi.
 */
const DURUM_ACIK: Record<DaireDurumu, string> = {
  normal: "#5887f0",
  borclu: "#c47e08",
  alarm: "#ef4444",
  pasif: "#848fa3",
};

const DURUM_KOYU: Record<DaireDurumu, string> = {
  normal: "#6f98f2",
  borclu: "#f59e0b",
  alarm: "#f36d6d",
  pasif: "#8b97a9",
};

export function durumRenkleri(koyu: boolean): Record<DaireDurumu, string> {
  return koyu ? DURUM_KOYU : DURUM_ACIK;
}

/**
 * SECIM RENGI — (P162 §8.1) MAVIDEN YESILE.
 *
 * OLCULEN KUSUR: secim rengi maviydi (#3f86d2 / #5fc8ff) ve `normal`
 * durum da mavi. Kullanici bir daireye tikladiginda "mavi tonu maviye
 * donuyor" — yani secim ANLASILMIYORDU. Kontrast oranlari duvara gore
 * dogruydu ama SECIM ILE NORMALIN BIRBIRINE gore farki degildi.
 *
 * Yesil secildi cunku durum ailesinde (mavi=normal, amber=borclu,
 * kirmizi=alarm, gri=pasif) KULLANILMAYAN tek belirgin ton oydu; yani
 * hicbir durumla karistirilmaz.
 */
// (P244 §10e) `--yz-success` (#16a34a) ailesinden turetildi. P162 §8.1
// karari AYNEN GECERLI: yesil, durum ailesinde kullanilmayan tek
// belirgin ton oldugu icin secildi ve hicbir durumla karistirilamaz.
const SECIM_ACIK = "#16a24a";
const SECIM_KOYU = "#17ae4f";

export function secimRengi(koyu: boolean): string {
  return koyu ? SECIM_KOYU : SECIM_ACIK;
}

/**
 * HOVER RENGI — secimden AYRI ton (brief: "Hover ayri bir ton, secim
 * ayri"). Yesilin daha soluk/soguk bir kademesi: ayni aileden oldugu
 * icin "buraya tiklarsan secilir" der, ama secili olanla karistirilmaz.
 */
// (P244 §10e) Ayni yesil ailenin IKINCI kademesi — "buraya tiklarsan
// secilir" der ama secili olanla karistirilmaz.
const HOVER_ACIK = "#12873d";
const HOVER_KOYU = "#1cd360";

export function hoverRengi(koyu: boolean): string {
  return koyu ? HOVER_KOYU : HOVER_ACIK;
}

/**
 * (P244 §10e) SAHNE YUZEYLERI TOKEN KATMANINA HIZALANDI.
 *
 * OLCULEN KUSUR: maket kendi gri ailesini tasiyordu (#151b22, #e8edf2,
 * #d8e0e9...) ve P244'ten sonra ana sayfadaki TEK uyumsuz oge oydu —
 * cevresindeki kartlar token yuzeylerinde, maket baska bir gri.
 *
 * ESLEME (WebGL `var(--yz-*)` anlamaz; sayisal karsiliklari yazildi):
 *   arkaPlan      <- --yz-bg-app          (tuval sayfayla ayni zeminde)
 *   platform      <- --yz-surface-sunken  (tabla sayfadan COKUK)
 *   platformKenar <- --yz-border
 *   kutle         <- --yz-surface-1       (bina = kart yuzeyi)
 *   katCizgisi    <- --yz-border
 *   cati / balkon <- --yz-surface-2
 *
 * DOGA OGELERI (cim, havuz, agac, yol) TOKEN AILESINDE YOK ve
 * uydurulmadi: cimin semantik bir karsiligi yoktur. Dokunulmadilar.
 *
 * ISIK KURULUMU DEGISMEDI — brief §4'un iki-tema karari (koyu: serin
 * mavi anahtar + dusuk ortam; acik: notr gun isigi) gecerli.
 */
const KOYU: SahnePaleti = {
  arkaPlan: "#313a44",
  platform: "#2c353e",
  platformKenar: "#55616d",
  cim: "#243a33",
  yol: "#232a31",
  patika: "#39424b",
  havuz: "#1d4f6b",
  agacGovde: "#3a3229",
  agacTepe: "#2f5a45",
  kutle: "#3b4650",
  katCizgisi: "#55616d",
  cati: "#46515c",
  balkon: "#46515c",
  pencere: "#7fa9cf",
  serit: "#3d8fd4",
  ortamIsik: "#9fc0e0",
  ortamGuc: 0.58,
  anahtarIsik: "#cfe2f5",
  anahtarGuc: 1.25,
  dolguIsik: "#5f7ea6",
  dolguGuc: 0.62,
};

const ACIK: SahnePaleti = {
  arkaPlan: "#eef2f7",
  platform: "#e2e8f0",
  platformKenar: "#dde4ec",
  cim: "#cfe0cf",
  yol: "#c2cad2",
  patika: "#dde3e9",
  havuz: "#a9d3e8",
  agacGovde: "#a9977f",
  agacTepe: "#8fb79a",
  kutle: "#ffffff",
  katCizgisi: "#dde4ec",
  cati: "#eaeff5",
  balkon: "#eaeff5",
  pencere: "#6f9cc4",
  serit: "#3d8fd4",
  ortamIsik: "#ffffff",
  ortamGuc: 0.8,
  anahtarIsik: "#fffaf0",
  anahtarGuc: 1.45,
  dolguIsik: "#dbe6f0",
  dolguGuc: 0.45,
};

export function sahnePaleti(koyu: boolean): SahnePaleti {
  return koyu ? KOYU : ACIK;
}
