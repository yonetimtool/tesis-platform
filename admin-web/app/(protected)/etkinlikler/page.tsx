"use client";

// (P126.3) ETKİNLİKLER — sakin görünümü (SALT OKUMA).
//
// KATILIM (RSVP) BU DİLİMDE YOK: sunucuda `PUT /events/{id}/rsvp` var ama
// katılım bir YAZMA akışıdır ve kendi doğrulama/geri alma davranışını
// ister. Yarım bir katılım düğmesi ("bastım, ne oldu?") eklemektense
// listeyi dürüstçe salt-okuma bırakmak daha iyi; katılım kendi
// alt-adımında gelir.
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, cardCls } from "@/components/form";
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
      <PageHeader title={t("sakinEtkinlikBaslik")} />
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <EmptyState title={t("sakinEtkinlikYok")} />
      ) : null}
      {kayitlar.map((e) => (
        <article key={e.id} className={`${cardCls} space-y-1 p-4`}>
          <h2 className="font-medium">{e.baslik}</h2>
          <p className="text-xs text-metin-muted">
            {tarihSaatUzun(e.tarih)}
            {e.konum ? ` · ${e.konum}` : ""}
          </p>
          <p className="whitespace-pre-line text-sm">{e.aciklama}</p>
        </article>
      ))}
    </div>
  );
}
