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
  IskeletMetin,
  Kart,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Etkinlik = {
  id: string;
  baslik: string;
  aciklama: string;
  tarih: string;
  konum: string | null;
};

export default function EtkinliklerPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Etkinlik[] }>(
    "/api/events?limit=50&offset=0",
    jsonFetcher,
  );
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("sakinEtkinlikBaslik")}
      </h1>
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("sakinEtkinlikYok")} />
        </Kart>
      ) : null}
      {kayitlar.map((e) => (
        <Kart key={e.id} className="space-y-1">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{e.baslik}</h2>
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {tarihSaatUzun(e.tarih)}
            {e.konum ? ` · ${e.konum}` : ""}
          </p>
          <p className="whitespace-pre-line" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>{e.aciklama}</p>
        </Kart>
      ))}
    </div>
  );
}
