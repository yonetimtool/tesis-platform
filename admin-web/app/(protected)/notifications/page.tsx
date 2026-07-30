"use client";

import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, Pager, cardCls } from "@/components/form";
import { useToast } from "@/components/Toast";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AppNotification, NotificationList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

type OkunduFiltre = "" | "true" | "false";
const LIMIT = 20;

export default function NotificationsPage() {
  const t = useT();
  const toast = useToast();
  const [okundu, setOkundu] = useState<OkunduFiltre>("");
  const [offset, setOffset] = useState(0);

  const key = `/api/notifications?limit=${LIMIT}&offset=${offset}${
    okundu ? `&okundu=${okundu}` : ""
  }`;
  const { data, error, isLoading, mutate } = useSWR<NotificationList>(key, jsonFetcher);

  async function markRead(id: string) {
    await fetch(`/api/notifications/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ okundu: true }),
    });
    mutate();
    toast.success(t("bildirimOkunduIsaretlendi"));
  }

  function setFilter(v: OkunduFiltre) {
    setOkundu(v);
    setOffset(0);
  }

  const total = data?.meta.total ?? 0;

  return (
    <div className="space-y-5">
      <PageHeader title={t("kabukBildirimler")} />

      {/* SARILABILIR: uc filtre dugmesi 360 dp + buyuk kok yazi boyunda tek
          satira sigmiyordu (tur 28 surusu: tr +9 px, ru +79 px). Sekme
          degil dugme oldugu icin sarmak dogru cozum — kaydirma gerekmez. */}
      <div className="flex flex-wrap items-center gap-2">
        {([
          ["", t("ortakTumu")],
          ["false", t("bildirimOkunmamis")],
          ["true", t("bildirimOkunmus")],
        ] as [OkunduFiltre, string][]).map(([v, label]) => (
          <button
            key={label}
            onClick={() => setFilter(v)}
            className={`rounded-lg px-3 py-1.5 text-sm transition ${
              okundu === v ? "bg-ink text-white" : "border border-slate-300 text-slate-700 hover:bg-slate-100"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      <ul className="space-y-2">
        {(data?.items ?? []).map((n: AppNotification) => (
          <li
            key={n.id}
            className={`flex flex-wrap items-start justify-between gap-3 ${cardCls} px-3 py-2`}
          >
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-semibold text-slate-500">{n.tip}</span>
                {!n.okundu && (
                  <span className="rounded-full bg-blue-100 px-2 py-0.5 text-xs text-blue-700">
                    {t("bildirimYeniRozet")}
                  </span>
                )}
              </div>
              <p className="text-sm text-slate-800">{n.mesaj}</p>
              <span className="text-xs text-muted">{formatDateTime(n.created_at)}</span>
            </div>
            {!n.okundu && (
              <button
                onClick={() => markRead(n.id)}
                className="shrink-0 rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-700 hover:bg-slate-100"
              >
                {t("bildirimOkunduIsaretle")}
              </button>
            )}
          </li>
        ))}
        {data && data.items.length === 0 && (
          <li className={cardCls}>
            <EmptyState title={t("bildirimYok")} />
          </li>
        )}
      </ul>

      <Pager
        offset={offset}
        limit={LIMIT}
        total={total}
        onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
        onNext={() => setOffset(offset + LIMIT)}
      />
    </div>
  );
}
