"use client";

// (P126.3) ETKİNLİKLER — sakin görünümü (SALT OKUMA).
//
// KATILIM (RSVP) BU DİLİMDE YOK: sunucuda `PUT /events/{id}/rsvp` var ama
// katılım bir YAZMA akışıdır ve kendi doğrulama/geri alma davranışını
// ister. Yarım bir katılım düğmesi ("bastım, ne oldu?") eklemektense
// listeyi dürüstçe salt-okuma bırakmak daha iyi; katılım kendi
// alt-adımında gelir.
import useSWR from "swr";

import {
  BosDurum,
  HataDurumu,
  IcerikKarti,
  IskeletMetin,
  Kart,
  Rozet,
  SayfaBasligi,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

/**
 * (P244 §8d) `foto_url`, `olusturan_ad` ve KATILIM SAYILARI EKLENDI.
 *
 * Hepsi sozlesmenin `Etkinlik` semasinda SOZ VERILIYOR. Katilim
 * sayilari icin sema acikca "SEFFAF katilim sayilari; sayilar herkese
 * acik" diyor — yani OKUMASI urun geregi. Ekran ikisini de
 * gostermiyordu.
 *
 * KATILIM BEYANI (RSVP) HALA YOK ve bu dosya basindaki karar GECERLI:
 * beyan bir YAZMA akisidir, kendi dogrulama/geri alma davranisini
 * ister. Degisen sey, SALT OKUNUR sayilarin gorunur olmasi — yarim bir
 * dugme eklemek degil.
 */
type Etkinlik = {
  id: string;
  baslik: string;
  aciklama: string;
  tarih: string;
  konum: string | null;
  foto_url: string | null;
  olusturan_ad: string | null;
  katiliyorum_sayisi: number;
  katilmiyorum_sayisi: number;
};

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const R_OLUMLU = "olumlu" as const;
const R_NOTR = "notr" as const;

export default function EtkinliklerPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Etkinlik[] }>(
    "/api/events?limit=50&offset=0",
    jsonFetcher,
  );
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-4">
      <SayfaBasligi baslik={t("sakinEtkinlikBaslik")} aciklama={t("sakinEtkinlikAlt")} />
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("sakinEtkinlikYok")} aciklama={t("sakinEtkinlikYokAlt")} />
        </Kart>
      ) : null}
      {kayitlar.map((e) => (
        <IcerikKarti
          key={e.id}
          baslik={e.baslik}
          fotoUrl={e.foto_url}
          fotoAlt={t("gorselAlt", { baslik: e.baslik })}
          ustVeri={`${tarihSaatUzun(e.tarih)}${e.konum ? ` · ${e.konum}` : ""}${
            e.olusturan_ad ? ` · ${e.olusturan_ad}` : ""
          }`}
          govde={e.aciklama}
          altBilgi={
            // SAYILAR ROZETTE, DUGMEDE DEGIL: bu ekranda katilim
            // BEYAN EDILEMEZ; rozet okunur, dugme basilir. Basilamayan
            // bir dugme cizmek kullaniciyi bir kez aldatirdi.
            <div className="flex flex-wrap gap-2 pt-1">
              <Rozet durum={R_OLUMLU}>
                {t("sakinEtkinlikKatiliyor", { n: e.katiliyorum_sayisi })}
              </Rozet>
              <Rozet durum={R_NOTR}>
                {t("sakinEtkinlikKatilmiyor", { n: e.katilmiyorum_sayisi })}
              </Rozet>
            </div>
          }
        />
      ))}
    </div>
  );
}
