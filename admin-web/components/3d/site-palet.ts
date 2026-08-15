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
 * DAIRE DURUM RENKLERI — arayuzun `--yz-*-edge` ailesiyle ayni.
 *
 * `pasif` KASTEN SOLUK: "kayit kapali" bir DURUM DEGIL, bir YOKLUK; onu
 * uyari renginde gostermek olmayan bir sorunu isaret ederdi.
 */
export const DURUM_RENGI: Record<DaireDurumu, string> = {
  normal: "#7fa9cf",
  borclu: "#d6963c",
  alarm: "#d45b5e",
  pasif: "#6b7885",
};

/** Secili dairenin vurgu rengi — durumdan BAGIMSIZ (secim bir durum degil). */
export const SECIM_RENGI = "#4da3ff";

const KOYU: SahnePaleti = {
  arkaPlan: "#151b22",
  platform: "#1e262e",
  platformKenar: "#2b3641",
  cim: "#243a33",
  yol: "#232a31",
  patika: "#39424b",
  havuz: "#1d4f6b",
  agacGovde: "#3a3229",
  agacTepe: "#2f5a45",
  kutle: "#8f9aa6",
  katCizgisi: "#6b7580",
  cati: "#7b8692",
  balkon: "#a3aeba",
  pencere: "#7fa9cf",
  serit: "#3d8fd4",
  ortamIsik: "#9fc0e0",
  ortamGuc: 0.45,
  anahtarIsik: "#cfe2f5",
  anahtarGuc: 1.25,
  dolguIsik: "#5f7ea6",
  dolguGuc: 0.5,
};

const ACIK: SahnePaleti = {
  arkaPlan: "#eef2f6",
  platform: "#e2e9f0",
  platformKenar: "#cfd9e3",
  cim: "#cfe0cf",
  yol: "#c2cad2",
  patika: "#dde3e9",
  havuz: "#a9d3e8",
  agacGovde: "#a9977f",
  agacTepe: "#8fb79a",
  kutle: "#e8edf2",
  katCizgisi: "#c6cfd8",
  cati: "#d5dce3",
  balkon: "#f3f6f9",
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
