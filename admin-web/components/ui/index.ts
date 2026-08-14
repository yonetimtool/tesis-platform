/**
 * (P160 / Asama 3) ORTAK BILESEN KATMANI — tek giris noktasi.
 *
 * Ekranlar `@/components/ui`den ice aktarir, tek tek dosyalardan DEGIL.
 * Sebep: bir bilesen bolunup iki dosyaya ayrildiginda (ya da adi
 * degistiginde) 50 sayfayi duzenlemek gerekmesin.
 *
 * ESKI BILESENLER (`components/tablo.tsx`, `Liste.tsx`, `Modal.tsx`,
 * `EmptyState.tsx`) BURAYA DAHIL EDILMEDI ve bu bilincli: onlar eski
 * tasarim dilini kullaniyor ve 42'ye kadar sayfada calisiyor. Ikisini
 * ayni kapidan sunmak, hangi dilin gecerli oldugunu belirsizlestirirdi.
 * Gecis bitince eskiler kaldirilacak.
 */
export { Kart, Bolum, Girinti, type YuzeyTonu, type KartProps } from "./yuzey";
export {
  Dugme,
  IkonDugmesi,
  type DugmeProps,
  type DugmeTuru,
  type DugmeBoyu,
} from "./dugme";
export { Rozet, type RozetDurumu } from "./rozet";
export { Kpi, type KpiProps, type KpiDurumu } from "./kpi";
export {
  Iskelet,
  IskeletMetin,
  IskeletTablo,
  IskeletKpi,
  BosDurum,
  HataDurumu,
} from "./durumlar";
export {
  Alan,
  CokSatir,
  Secim,
  AlanSarmal,
  AramaAlani,
} from "./alan";
