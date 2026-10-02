/**
 * (P252 §3) Personel detayi adresi — TEK yerden.
 *
 * Detay iki kimlikle acilir: hesap (`kisi`, Kisiler › Personel satiri) ya
 * da maas karti (`kart`, kasa hareketleri ve hesapsiz personel). Adresi
 * her cagri yerinde elle kurmak, bir gun parametre adi degistiginde bir
 * baglantinin sessizce bos sayfa acmasi demekti.
 */
export function personelDetayYolu(k: { kisi?: string | null; kart?: string | null }): string {
  const qs = new URLSearchParams();
  if (k.kisi) qs.set("kisi", k.kisi);
  else if (k.kart) qs.set("kart", k.kart);
  return `/kisiler/personel?${qs.toString()}`;
}

export type OdemeTuru = "maas" | "mesai" | "diger";

export interface PersonelDetay {
  kart_id: string | null;
  user_id: string | null;
  ad: string;
  rol: string | null;
  calisma: {
    giris_tarihi: string | null;
    cikis_tarihi: string | null;
    gorev: string | null;
    maas_kurus: number | null;
    odeme_gunu: number | null;
    kasa_id: string | null;
    kasa_ad: string | null;
    iban: string | null;
    notlar: string | null;
    aktif: boolean;
  } | null;
  odemeler: {
    id: string;
    tarih: string;
    donem: string | null;
    tutar_kurus: number;
    tur: OdemeTuru;
    durum: string;
    kasa_ad: string | null;
  }[];
  bu_ay: { vardiya_sayisi: number; vardiya_saat: number; devriye_tur: number; okutma_sayisi: number };
  yil_odenen_kurus: number;
}
