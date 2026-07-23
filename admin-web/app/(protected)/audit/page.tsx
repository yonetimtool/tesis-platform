"use client";

import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, Field, PageHeader, Pager, inputCls } from "@/components/form";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AuditLog, AuditLogList } from "@/lib/types";

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
        title="Denetim Kaydı"
        subtitle="Değiştirilemez KVKK denetim izi (append-only). Yalnızca platform admini görür."
      />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        <Field label="İşlem">
          <select
            className={inputCls}
            value={action}
            onChange={(e) => reset(setAction)(e.target.value)}
          >
            {ACTIONS.map((a) => (
              <option key={a} value={a}>
                {a === "" ? "Tümü" : a}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Kaynak tipi">
          <input
            className={inputCls}
            value={resourceType}
            onChange={(e) => reset(setResourceType)(e.target.value)}
            placeholder="app_user"
          />
        </Field>
        <Field label="Tenant ID">
          <input
            className={inputCls}
            value={tenantId}
            onChange={(e) => reset(setTenantId)(e.target.value)}
            placeholder="(tümü)"
          />
        </Field>
        <Field label="Başlangıç">
          <input
            type="date"
            className={inputCls}
            value={from}
            onChange={(e) => reset(setFrom)(e.target.value)}
          />
        </Field>
        <Field label="Bitiş">
          <input
            type="date"
            className={inputCls}
            value={to}
            onChange={(e) => reset(setTo)(e.target.value)}
          />
        </Field>
      </div>

      {error && <ErrorBox message="Denetim kaydı yüklenemedi." />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-4 py-2.5 font-medium">Zaman</th>
                <th className="px-4 py-2.5 font-medium">İşlem</th>
                <th className="px-4 py-2.5 font-medium">Rol</th>
                <th className="px-4 py-2.5 font-medium">Kaynak</th>
                <th className="px-4 py-2.5 font-medium">Tenant</th>
                <th className="px-4 py-2.5 font-medium">Meta</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-t border-slate-100 align-top">
                  <td className="whitespace-nowrap px-4 py-2.5 text-slate-600 tabular-nums">
                    {formatDateTime(r.ts)}
                  </td>
                  <td className="px-4 py-2.5">
                    <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">
                      {r.action}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-slate-600">{r.actor_rol ?? "—"}</td>
                  <td className="px-4 py-2.5 text-slate-600">
                    {r.resource_type ? (
                      <span className="font-mono text-xs">
                        {r.resource_type}
                        {r.resource_id ? `:${r.resource_id.slice(0, 8)}…` : ""}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-4 py-2.5 font-mono text-xs text-slate-500">
                    {r.tenant_id ? `${r.tenant_id.slice(0, 8)}…` : "platform"}
                  </td>
                  <td className="max-w-xs px-4 py-2.5">
                    <code className="block truncate text-xs text-slate-500">
                      {Object.keys(r.meta ?? {}).length ? JSON.stringify(r.meta) : "—"}
                    </code>
                  </td>
                </tr>
              ))}
              {data && rows.length === 0 && (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      title="Kayıt yok"
                      description="Filtreleri değiştirin ya da işlem gerçekleştikçe kayıtlar burada birikir."
                    />
                  </td>
                </tr>
              )}
            </tbody>
          </table>
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
