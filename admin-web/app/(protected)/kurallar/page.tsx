"use client";

// (P126.3) SİTE KURALLARI — sakin görünümü (SALT OKUMA).
//
// `sira` alanına göre sunucu sıralar; ekran o sırayı BOZMAZ — kurallar
// numaralandırılmış bir metindir ve yönetimin verdiği sıra anlamlıdır.
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, cardCls } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

type Kural = {
  id: string;
  baslik: string;
  icerik: string;
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
    <div className="space-y-5">
      <PageHeader title={t("sakinKurallarBaslik")} />
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
      ) : null}
      {!isLoading && !error && kurallar.length === 0 ? (
        <EmptyState title={t("sakinKurallarYok")} />
      ) : null}
      <ol className="space-y-3">
        {kurallar.map((k) => (
          <li key={k.id} className={`${cardCls} space-y-1 p-4`}>
            <h2 className="font-medium">{k.baslik}</h2>
            <p className="whitespace-pre-line text-sm">{k.icerik}</p>
          </li>
        ))}
      </ol>
    </div>
  );
}
