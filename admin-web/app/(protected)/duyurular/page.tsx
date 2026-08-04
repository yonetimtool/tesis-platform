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

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, cardCls } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Duyuru = {
  id: string;
  baslik: string;
  govde: string;
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
    <div className="space-y-5">
      <PageHeader title={t("sakinDuyurularBaslik")} />
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <EmptyState title={t("sakinDuyurularYok")} />
      ) : null}
      {kayitlar.map((d) => (
        <article key={d.id} className={`${cardCls} space-y-1 p-4`}>
          <h2 className="font-medium">{d.baslik}</h2>
          <p className="text-xs text-muted">{tarihSaatUzun(d.created_at)}</p>
          <p className="whitespace-pre-line text-sm">{d.govde}</p>
        </article>
      ))}
    </div>
  );
}
