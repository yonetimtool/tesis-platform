"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, inputCls, btnPrimary, btnGhost, btnDanger } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type {
  AuthType,
  HttpMethod,
  Integration,
  IntegrationChannel,
  IntegrationList,
  IntegrationPreset,
  IntegrationTriggerResult,
} from "@/lib/types";

interface FormState {
  ad: string;
  channel_type: IntegrationChannel;
  endpoint_url: string;
  http_method: HttpMethod;
  headers_text: string; // JSON metni (gizli OLMAYAN header'lar)
  auth_type: AuthType;
  auth_secret: string; // write-only; doluysa gonderilir
  payload_template: string;
  aktif: boolean;
}
const EMPTY: FormState = {
  ad: "",
  channel_type: "webhook",
  endpoint_url: "",
  http_method: "POST",
  headers_text: "{}",
  auth_type: "none",
  auth_secret: "",
  payload_template: "",
  aktif: true,
};

const CHANNELS: IntegrationChannel[] = ["webhook", "megaphone", "smarthome"];
const METHODS: HttpMethod[] = ["POST", "PUT", "PATCH", "GET"];
const AUTH_TYPES: AuthType[] = ["none", "bearer", "api_key"];

export default function IntegrationsPage() {
  const { data, error, isLoading, mutate } = useSWR<IntegrationList>(
    "/api/integrations?limit=200",
    jsonFetcher,
  );
  const { data: presets } = useSWR<IntegrationPreset[]>(
    "/api/integrations/presets",
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingSecretSet, setEditingSecretSet] = useState(false);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [testResult, setTestResult] = useState<Record<string, IntegrationTriggerResult>>({});
  const [testing, setTesting] = useState<string | null>(null);

  function openNew() {
    setEditingId(null);
    setEditingSecretSet(false);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }

  function applyPreset(key: string) {
    const p = presets?.find((x) => x.key === key);
    if (!p) return;
    setForm((f) => ({
      ...f,
      channel_type: p.channel_type,
      http_method: p.http_method,
      headers_text: JSON.stringify(p.headers_json, null, 2),
      payload_template: p.payload_template,
    }));
  }

  async function openEdit(it: Integration) {
    setEditingId(it.id);
    setEditingSecretSet(it.auth_secret_set);
    setForm({
      ad: it.ad,
      channel_type: it.channel_type,
      endpoint_url: it.endpoint_url,
      http_method: it.http_method,
      headers_text: JSON.stringify(it.headers_json ?? {}, null, 2),
      auth_type: it.auth_type,
      auth_secret: "", // sir GET'te gelmez; boş = değiştirme
      payload_template: it.payload_template,
      aktif: it.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    let headers_json: Record<string, string>;
    try {
      headers_json = form.headers_text.trim() ? JSON.parse(form.headers_text) : {};
    } catch {
      setSaving(false);
      setFormErr("Header'lar geçerli JSON olmalı.");
      return;
    }
    try {
      const base: Record<string, unknown> = {
        ad: form.ad,
        channel_type: form.channel_type,
        endpoint_url: form.endpoint_url,
        http_method: form.http_method,
        headers_json,
        auth_type: form.auth_type,
        payload_template: form.payload_template,
        aktif: form.aktif,
      };
      // Sir yalnızca girildiyse gönderilir (write-only; boş = değiştirme).
      if (form.auth_secret) base.auth_secret = form.auth_secret;
      if (editingId) await apiSend(`/api/integrations/${editingId}`, "PATCH", base);
      else await apiSend("/api/integrations", "POST", base);
      setOpen(false);
      mutate();
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function remove(it: Integration) {
    if (!window.confirm(`"${it.ad}" silinsin mi?`)) return;
    try {
      await apiSend(`/api/integrations/${it.id}`, "DELETE");
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  async function test(it: Integration) {
    setTesting(it.id);
    try {
      const res = await apiSend<IntegrationTriggerResult>(
        `/api/integrations/${it.id}/trigger`,
        "POST",
        { message: "Test mesajı", title: "Test" },
      );
      setTestResult((m) => ({ ...m, [it.id]: res }));
    } catch (err) {
      setTestResult((m) => ({
        ...m,
        [it.id]: { ok: false, error: err instanceof Error ? err.message : "Hata" },
      }));
    } finally {
      setTesting(null);
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Entegrasyonlar</h1>
          <p className="text-sm text-muted">
            Dış sistemler (megafon / akıllı ev / genel webhook) — API bilgisi girin,
            tetikleyin. Giden istekler SSRF korumasından geçer.
          </p>
        </div>
        <button className={btnPrimary} onClick={openNew}>
          Yeni entegrasyon
        </button>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">{editingId ? "Entegrasyon düzenle" : "Yeni entegrasyon"}</h2>
          {!editingId && presets && presets.length > 0 && (
            <Field label="Hazır şablon (preset)" hint="Doldurur; düzenlenebilir">
              <select
                className={inputCls}
                defaultValue=""
                onChange={(e) => e.target.value && applyPreset(e.target.value)}
              >
                <option value="">— şablon seç —</option>
                {presets.map((p) => (
                  <option key={p.key} value={p.key}>
                    {p.key}
                  </option>
                ))}
              </select>
            </Field>
          )}
          <div className="grid grid-cols-2 gap-4">
            <Field label="Ad">
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label="Kanal tipi">
              <select
                className={inputCls}
                value={form.channel_type}
                onChange={(e) =>
                  setForm({ ...form, channel_type: e.target.value as IntegrationChannel })
                }
              >
                {CHANNELS.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Endpoint URL" hint="http(s) — iç/özel adresler engellenir">
              <input
                className={inputCls}
                value={form.endpoint_url}
                onChange={(e) => setForm({ ...form, endpoint_url: e.target.value })}
                placeholder="https://..."
                required
              />
            </Field>
            <Field label="HTTP metodu">
              <select
                className={inputCls}
                value={form.http_method}
                onChange={(e) => setForm({ ...form, http_method: e.target.value as HttpMethod })}
              >
                {METHODS.map((m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Kimlik doğrulama">
              <select
                className={inputCls}
                value={form.auth_type}
                onChange={(e) => setForm({ ...form, auth_type: e.target.value as AuthType })}
              >
                {AUTH_TYPES.map((a) => (
                  <option key={a} value={a}>
                    {a}
                  </option>
                ))}
              </select>
            </Field>
            <Field
              label="Sır (bearer token / API key)"
              hint={
                editingSecretSet
                  ? "Kayıtlı — değiştirmek için yeni değer girin (yazma-özel)"
                  : "Yazma-özel; GET'te asla dönmez"
              }
            >
              <input
                type="password"
                className={inputCls}
                value={form.auth_secret}
                onChange={(e) => setForm({ ...form, auth_secret: e.target.value })}
                placeholder={editingSecretSet ? "•••••• (değiştirmezseniz boş bırakın)" : ""}
                disabled={form.auth_type === "none"}
              />
            </Field>
          </div>
          <Field label="Header'lar (JSON, gizli olmayan)">
            <textarea
              className={`${inputCls} font-mono`}
              rows={3}
              value={form.headers_text}
              onChange={(e) => setForm({ ...form, headers_text: e.target.value })}
            />
          </Field>
          <Field label="Payload şablonu" hint="{{message}} / {{title}} yer tutucuları">
            <textarea
              className={`${inputCls} font-mono`}
              rows={3}
              value={form.payload_template}
              onChange={(e) => setForm({ ...form, payload_template: e.target.value })}
            />
          </Field>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />
            Aktif
          </label>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? "Kaydediliyor..." : "Kaydet"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              İptal
            </button>
          </div>
        </form>
      )}

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-500">
            <tr>
              <th className="px-3 py-2 font-medium">Ad</th>
              <th className="px-3 py-2 font-medium">Kanal</th>
              <th className="px-3 py-2 font-medium">Endpoint</th>
              <th className="px-3 py-2 font-medium">Kimlik</th>
              <th className="px-3 py-2 font-medium">Aktif</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((it) => {
              const tr = testResult[it.id];
              return (
                <tr key={it.id} className={`border-t border-slate-100 ${it.aktif ? "" : "opacity-60"}`}>
                  <td className="px-3 py-2">{it.ad}</td>
                  <td className="px-3 py-2 text-slate-600">{it.channel_type}</td>
                  <td className="px-3 py-2 text-slate-600 max-w-[280px] truncate">
                    {it.http_method} {it.endpoint_url}
                  </td>
                  <td className="px-3 py-2 text-slate-600">
                    {it.auth_type}
                    {it.auth_secret_set ? " 🔒" : ""}
                  </td>
                  <td className="px-3 py-2">{it.aktif ? "Evet" : "—"}</td>
                  <td className="px-3 py-2 text-right">
                    <div className="flex flex-col items-end gap-1">
                      <div className="flex justify-end gap-2">
                        <button
                          className={btnGhost}
                          onClick={() => test(it)}
                          disabled={testing === it.id}
                        >
                          {testing === it.id ? "Test ediliyor..." : "Test"}
                        </button>
                        <button className={btnGhost} onClick={() => openEdit(it)}>
                          Düzenle
                        </button>
                        <button className={btnDanger} onClick={() => remove(it)}>
                          Sil
                        </button>
                      </div>
                      {tr && (
                        <span
                          className={`text-xs ${tr.ok ? "text-emerald-700" : "text-red-700"}`}
                        >
                          {tr.ok
                            ? `✓ Başarılı (${tr.status ?? "—"})`
                            : `✗ ${tr.error ?? "Başarısız"}${tr.status ? ` (${tr.status})` : ""}`}
                        </span>
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={6}>
                  Entegrasyon yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
