"use client";

import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, Field, PageHeader, Pager, inputCls } from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { rolAdi } from "@/lib/roles";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AuditLog, AuditLogList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

const LIMIT = 50;

// Yaygin action'lar (serbest-metin; liste yalniz kolaylik). Bos = tumu.
const ACTIONS = [
  "", "login_ok", "login_fail", "password_change", "password_set",
  "resident_create", "resident_update", "resident_delete", "resident_erasure",
  "user_create", "user_update", "user_contact_update",
  "phone_reveal", "call_initiate", "kargo_photo_view",
  "visitor_create", "kargo_create", "kargo_receive",
  "unit_access_request", "unit_access_decide",
  "complaint_create", "complaint_resolve", "complaint_decline",
  "dues_assessment_create", "dues_payment_record",
  "block_create", "block_delete", "unit_create", "unit_delete",
  "erasure_run",
];

export default function AuditPage() {
  const t = useT();
  const [offset, setOffset] = useState(0);
  const [action, setAction] = useState("");
  const [resourceType, setResourceType] = useState("");
  const [tenantId, setTenantId] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (action) qs.set("action", action);
  if (resourceType) qs.set("resource_type", resourceType);
  if (tenantId) qs.set("tenant_id", tenantId);
  if (from) qs.set("from", from);
  if (to) qs.set("to", to);

  const { data, error, isLoading } = useSWR<AuditLogList>(
    `/api/audit?${qs.toString()}`,
    jsonFetcher,
  );

  function reset(setter: (v: string) => void) {
    return (v: string) => {
      setter(v);
      setOffset(0);
    };
  }

  const rows: AuditLog[] = data?.items ?? [];

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukDenetimKaydi")}
        subtitle={t("denetimAciklama")}
      />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        <Field label={t("denetimIslem")}>
          <select
            className={inputCls}
            value={action}
            onChange={(e) => reset(setAction)(e.target.value)}
          >
            {ACTIONS.map((a) => (
              <option key={a} value={a}>
                {a === "" ? t("ortakTumu") : a}
              </option>
            ))}
          </select>
        </Field>
        <Field label={t("denetimKaynakTipi")}>
          <input
            className={inputCls}
            value={resourceType}
            onChange={(e) => reset(setResourceType)(e.target.value)}
            placeholder="app_user"
          />
        </Field>
        <Field label={t("ayarTenantId")}>
          <input
            className={inputCls}
            value={tenantId}
            onChange={(e) => reset(setTenantId)(e.target.value)}
            placeholder={t("denetimTumu")}
          />
        </Field>
        <Field label={t("ortakBaslangic")}>
          <input
            type="date"
            className={inputCls}
            value={from}
            onChange={(e) => reset(setFrom)(e.target.value)}
          />
        </Field>
        <Field label={t("ortakBitis")}>
          <input
            type="date"
            className={inputCls}
            value={to}
            onChange={(e) => reset(setTo)(e.target.value)}
          />
        </Field>
      </div>

      {error && <ErrorBox message={t("denetimYuklenemedi")} />}
      {isLoading && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

      <div className="overflow-hidden rounded-kart border kart-kenar bg-white">
        <div className="odak-ic overflow-x-auto" tabIndex={0}>
          <Tablo>
            <TabloBasligi>
                <Th>{t("denetimZaman")}</Th>
                <Th>{t("denetimIslem")}</Th>
                <Th>{t("ortakRol")}</Th>
                <Th>{t("denetimKaynak")}</Th>
                <Th>{t("ortakTesis")}</Th>
                <Th>{t("denetimMeta")}</Th>
              </TabloBasligi>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-t border-yuzey-divider align-top">
                  <Td sayi className="whitespace-nowrap text-metin-body">
                    {formatDateTime(r.ts)}
                  </Td>
                  <Td>
                    <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-metin-body">
                      {r.action}
                    </span>
                  </Td>
                  {/* (P66) HAM TEL DEGERI DEGIL: denetim kaydinda rol
                      `admin`/`yonetici` diye ciziliyordu, oysa panelin geri
                      kalani `rolAdi` ile cevirir. Denetim kaydi "kim ne
                      yapti"nin kanitidir; orada kullanicinin taniyamadigi
                      bir jeton gostermek, kaydi okunamaz kilar. */}
                  <Td className="text-metin-body">
                    {r.actor_rol ? rolAdi(t, r.actor_rol) : "—"}
                  </Td>
                  <Td className="text-metin-body">
                    {r.resource_type ? (
                      <span className="font-mono text-xs">
                        {r.resource_type}
                        {r.resource_id ? `:${r.resource_id.slice(0, 8)}…` : ""}
                      </span>
                    ) : (
                      "—"
                    )}
                  </Td>
                  <Td className="font-mono text-xs text-metin-muted">
                    {r.tenant_id ? `${r.tenant_id.slice(0, 8)}…` : "platform"}
                  </Td>
                  <Td className="max-w-xs">
                    <code className="block truncate text-xs text-metin-muted">
                      {Object.keys(r.meta ?? {}).length ? JSON.stringify(r.meta) : "—"}
                    </code>
                  </Td>
                </tr>
              ))}
              {data && rows.length === 0 && (
                <tr>
                  <Td colSpan={6}>
                    <EmptyState
                      title={t("denetimKayitYok")}
                      description={t("denetimKayitYokAlt")}
                    />
                  </Td>
                </tr>
              )}
            </tbody>
          </Tablo>
        </div>
      </div>

      {data && (
        <Pager
          offset={offset}
          limit={LIMIT}
          total={data.meta.total}
          onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
          onNext={() => setOffset(offset + LIMIT)}
        />
      )}
    </div>
  );
}
