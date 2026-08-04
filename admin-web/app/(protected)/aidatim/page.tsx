"use client";

// (P126.3) AİDATIM — sakinin KENDİ borcu.
//
// Paneldeki `/dues` YÖNETİM ekranıdır: tahakkuk oluşturur, sitenin bütün
// dairelerini listeler. Bu onun kendi-kaydı karşılığıdır ve AYRI BİR UÇ
// kullanır (`GET /me/dues`) — aynı ucu rol süzgeciyle paylaşmak, bir gün
// süzgeç unutulduğunda tüm sitenin borcunu sakine göstermek olurdu.
//
// Sakin birden çok daireye bağlı olabilir (malik + kiracı); sunucu liste
// döner ve ekran her daireyi ayrı kart olarak gösterir.
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, cardCls } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import { tarihBicimi } from "@/lib/tarih";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL } from "@/lib/money";

type Tahakkuk = {
  id: string;
  donem: string;
  tutar_kurus: number;
  son_odeme_tarihi: string | null;
  aciklama: string | null;
};
type Odeme = { id: string; tutar_kurus: number; odeme_tarihi: string };
type DaireDurum = {
  unit_id: string;
  no: string;
  toplam_tahakkuk_kurus: number;
  toplam_odenen_kurus: number;
  bakiye_kurus: number;
  assessments: Tahakkuk[];
  payments: Odeme[];
};

// (P61) HATA VARKEN "YOK" DENMEZ: liste `data?.items ?? []`den turer, yani
// istek dustugunde de BOS gorunur ve sayfa hem hatayi hem "kayit yok"u
// gosterirdi. Bos-durum kosulu bu yuzden `!error` de arar.
export default function AidatimPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: DaireDurum[] }>(
    "/api/me/dues",
    jsonFetcher,
  );
  const daireler = data?.items ?? [];

  return (
    <div className="space-y-6">
      <PageHeader title={t("aidatimBaslik")} />
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}

      {isLoading ? (
        <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
      ) : null}

      {!isLoading && !error && daireler.length === 0 ? (
        <EmptyState title={t("aidatimYok")} />
      ) : null}

      {daireler.map((d) => (
        <section key={d.unit_id} className={`${cardCls} space-y-4 p-5`}>
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 className="font-medium">{t("aidatimDaire", { no: d.no })}</h2>
            <p
              className={`text-lg font-semibold tabular-nums ${
                d.bakiye_kurus > 0 ? "text-red-700" : "text-emerald-700"
              }`}
            >
              {kurusToTL(d.bakiye_kurus)}
            </p>
          </div>

          <dl className="grid gap-3 sm:grid-cols-2">
            <div>
              <dt className="text-xs text-muted">{t("aidatimTahakkuk")}</dt>
              <dd className="tabular-nums">
                {kurusToTL(d.toplam_tahakkuk_kurus)}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-muted">{t("aidatimOdenen")}</dt>
              <dd className="tabular-nums">
                {kurusToTL(d.toplam_odenen_kurus)}
              </dd>
            </div>
          </dl>

          {d.assessments.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <caption className="sr-only">{t("aidatimTahakkukListe")}</caption>
                <thead>
                  <tr className="text-left text-xs text-muted">
                    <th className="py-1.5">{t("aidatimDonem")}</th>
                    <th className="py-1.5">{t("aidatimTutar")}</th>
                    <th className="py-1.5">{t("aidatimSonOdeme")}</th>
                  </tr>
                </thead>
                <tbody>
                  {d.assessments.map((a) => (
                    <tr key={a.id} className="border-t border-slate-100">
                      <td className="py-2">{a.donem}</td>
                      <td className="py-2 tabular-nums">
                        {kurusToTL(a.tutar_kurus)}
                      </td>
                      <td className="py-2">
                        {a.son_odeme_tarihi
                          ? tarihBicimi(a.son_odeme_tarihi)
                          : "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}
        </section>
      ))}
    </div>
  );
}
