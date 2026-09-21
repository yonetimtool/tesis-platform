"use client";

// (P126.3) DUYURULAR — sakin görünümü (SALT OKUMA).
//
// Paneldeki `/announcements` yönetim ekranıdır: duyuru yazar, siler.
// Burası okuyan tarafın ekranı; aynı uçtan beslenir çünkü duyuru zaten
// tesise açıktır — kendi-kapsam kuralı gerekmez.
//
// YAZMA DÜĞMESİ YOK: sunucu yönetici olmayanı zaten reddeder, ama
// kullanıcıya basıp 403 alacağı bir düğme göstermek "yetkim var sandım"
// demektir.
import useSWR from "swr";

import {
  BosDurum,
  HataDurumu,
  IcerikKarti,
  IskeletMetin,
  Kart,
  SayfaBasligi,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

/**
 * (P244 §8d) `foto_url` ve `olusturan_ad` EKLENDI.
 *
 * Ikisi de sozlesmenin `Announcement` semasinda SOZ VERILIYOR ve
 * yonetim ekrani gorsel yuklemeyi destekliyor — ama bu yerel tip
 * onlari HIC OKUMUYORDU. Yani yonetici duyuruya kapak gorseli
 * ekliyor, sakin onu HIC GORMUYORDU.
 */
type Duyuru = {
  id: string;
  baslik: string;
  govde: string;
  foto_url: string | null;
  olusturan_ad: string | null;
  created_at: string;
};

export default function DuyurularPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Duyuru[] }>(
    "/api/announcements?limit=50&offset=0",
    jsonFetcher,
  );
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-4">
      <SayfaBasligi baslik={t("sakinDuyurularBaslik")} aciklama={t("sakinDuyurularAlt")} />
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("sakinDuyurularYok")} aciklama={t("sakinDuyurularYokAlt")} />
        </Kart>
      ) : null}
      {kayitlar.map((d) => (
        <IcerikKarti
          key={d.id}
          baslik={d.baslik}
          fotoUrl={d.foto_url}
          fotoAlt={t("gorselAlt", { baslik: d.baslik })}
          // UST VERI ICIN SOZLUK ANAHTARI ACILMADI ve bu bilincli:
          // "{zaman} · {kisi}" yedi dilde AYNI dizedir ve sozluk
          // butunlugu kilidi onu hakli olarak "TR kopyasi" sayar.
          // Ayrac bir cumle degil, bir NOKTALAMA — etkinlik ekrani da
          // ayni deseni kullaniyor.
          ustVeri={`${tarihSaatUzun(d.created_at)}${
            d.olusturan_ad ? ` · ${d.olusturan_ad}` : ""
          }`}
          govde={d.govde}
        />
      ))}
    </div>
  );
}
