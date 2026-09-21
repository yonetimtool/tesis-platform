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
export { Modal, OnayDiyalogu, type ModalProps } from "./modal";
export { DokunmaKapisi } from "./dokunma-kapisi";
export { useOnay, type OnayIstegi, type OnayKancasi } from "./onay-kullan";
export { KomutPaleti, PALET_HEDEF, type PaletVurusu } from "./komut-paleti";
export { BildirimMerkezi } from "./bildirim-merkezi";
export { Sekmeler, Ipucu, Cekmece, type Sekme } from "./sekmeler";
export {
  VeriTablosu,
  SAYFA_BOYLARI,
  type Kolon,
  type TabloDurumu,
  type SayfaBoyu,
  type SiraYonu,
  type VeriTablosuProps,
} from "./veri-tablosu";
export {
  Alan,
  CokSatir,
  Secim,
  AlanSarmal,
  AramaAlani,
} from "./alan";
export {
  Grafik,
  grafikTuruSec,
  PASTA_DILIM_SINIRI,
  type GrafikDilimi,
  type GrafikTuru,
} from "./grafik";
export { TarihAraligi, aralikGecerli, type AralikTipi } from "./tarih-araligi";
export { AyTakvimi, gunEkle, isoHaftaGunu } from "./ay-takvimi";

// (P244 §2) Kanonik sayfa basligi — eski `tasarim.tsx::SayfaBasligi` ve
// `form.tsx::PageHeader` bunun yerine gececek (asama 10 temizligi).
export { SayfaBasligi } from "./sayfa-basligi";

// (P244 §3) YENI PAYLASILAN BILESENLER — olculen bosluklarin karsiligi.
// Detay paneli 79 sayfanin 1'inde, KPI 3'unde vardi; paylasilan bir
// filtre cubugu HIC yoktu.
export { DetayCekmecesi, CekmeceSatiri, type CekmeceProps } from "./cekmece";
export { IcerikKarti } from "./icerik-karti";
export { UstaDetayDuzeni, type UstaSecenek } from "./usta-detay";
export { FiltreCubugu } from "./filtre-cubugu";
export {
  OzetKarti,
  OzetSeridi,
  type OzetKartiProps,
  type OzetDurumu,
  type TrendYonu,
} from "./ozet-seridi";

// (P244 §4) ESKI KATMANDAN TASINANLAR.
// `components/tablo.tsx` ve `components/form.tsx` icindeki gorsel
// ilkeller token diline cevrilip buraya alindi; boylece modul siniri
// tasarim dili siniriyla ayni yerde duruyor.
export {
  TabloKart,
  Tablo,
  TabloBasligi,
  Th,
  Tr,
  Td,
  BosSatir,
  Pager,
} from "./tablo-ilkelleri";
export { EksikVeriUyarisi } from "./durumlar";
export { IkonKutu, BolumBasligi } from "./yuzey";
export { Liste, type Kolon as ListeKolonu, type ListeProps } from "./liste";
