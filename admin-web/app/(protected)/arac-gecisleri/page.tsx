"use client";

// (P126.4) ARAÇ GEÇİŞLERİ — SALT OKUMA.
//
// Kayıtlar ANPR ile OTOMATİK oluşur (P16). Elle giriş formu bilerek yok:
// plakayı elle yazmak, otomatik kayıtla çelişen ikinci bir gerçek üretirdi
// ve "hangisi doğru?" sorusunu operasyona bırakırdı. BFF proxy'si de
// yalnız `GET` açıyor.
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, cardCls } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Gecis = {
  id: string;
  plaka: string;
  arac_tanim: string | null;
  giris_zamani: string;
  cikis_zamani: string | null;
  unit_no: string | null;
  ziyaretci_mi: boolean;
};

export default function AracGecisleriPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Gecis[] }>(
    "/api/vehicle-passes?limit=50&offset=0",
    jsonFetcher,
  );
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-5">
      <PageHeader title={t("aracBaslik")} />
      <p className="text-sm text-metin-muted">{t("aracOtomatikNot")}</p>
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <EmptyState title={t("aracYok")} />
      ) : null}
      {kayitlar.map((g) => (
        <article key={g.id} className={`${cardCls} space-y-1 p-4`}>
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 className="font-medium tabular-nums">{g.plaka}</h2>
            <span className="text-xs text-metin-muted">{g.unit_no ?? "—"}</span>
          </div>
          <p className="text-xs text-metin-muted">
            {tarihSaatUzun(g.giris_zamani)}
            {g.cikis_zamani ? ` → ${tarihSaatUzun(g.cikis_zamani)}` : ""}
          </p>
          {g.arac_tanim ? <p className="text-sm">{g.arac_tanim}</p> : null}
        </article>
      ))}
    </div>
  );
}
