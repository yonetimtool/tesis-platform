"use client";

// (P126.3) SİTE KURALLARI — sakin görünümü (SALT OKUMA).
//
// `sira` alanına göre sunucu sıralar; ekran o sırayı BOZMAZ — kurallar
// numaralandırılmış bir metindir ve yönetimin verdiği sıra anlamlıdır.
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

/**
 * (P244 §8d) `foto_url` EKLENDI.
 *
 * Kural gorseli P190 §3'te OZELLIKLE eklenmisti — yonetici kural
 * formundan bir gorsel yukluyor ("otopark plani", "atik ayristirma
 * semasi" gibi seyler icin). Sakin tarafi bu alani hic okumuyordu,
 * yani gorsel yuklendigi gunden beri GORUNMUYORDU.
 */
type Kural = {
  id: string;
  baslik: string;
  icerik: string;
  foto_url: string | null;
  sira: number;
};

export default function SiteKurallariPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Kural[] }>(
    "/api/site-rules?limit=50&offset=0",
    jsonFetcher,
  );
  const kurallar = data?.items ?? [];

  return (
    <div className="space-y-4">
      <SayfaBasligi baslik={t("sakinKurallarBaslik")} aciklama={t("sakinKurallarAlt")} />
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && kurallar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("sakinKurallarYok")} aciklama={t("sakinKurallarYokAlt")} />
        </Kart>
      ) : null}
      {/* SIRA KORUNUR ve `<ol>` KALIR: kurallar numaralandirilmis bir
          metindir, yonetimin verdigi sira anlamlidir ve ekran okuyucu
          "1. ogeden N" der. Kart yuzeyi listenin ICINE girer, disina
          degil. */}
      <ol className="space-y-4">
        {kurallar.map((k) => (
          <li key={k.id}>
            <IcerikKarti
              baslik={k.baslik}
              fotoUrl={k.foto_url}
              fotoAlt={t("gorselAlt", { baslik: k.baslik })}
              govde={k.icerik}
            />
          </li>
        ))}
      </ol>
    </div>
  );
}
