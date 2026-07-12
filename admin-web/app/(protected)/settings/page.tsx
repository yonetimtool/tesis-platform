"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, inputCls, btnPrimary } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { TenantSettings } from "@/lib/types";

export default function SettingsPage() {
  const { data, error, isLoading, mutate } = useSWR<TenantSettings>(
    "/api/tenant/settings",
    jsonFetcher,
  );

  const [ad, setAd] = useState("");
  const [timezone, setTimezone] = useState("");
  const [telefon, setTelefon] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Ilk yuklemede formu doldur.
  useEffect(() => {
    if (data && !loaded) {
      setAd(data.ad);
      setTimezone(data.timezone);
      setTelefon(data.acil_durum_telefon ?? "");
      setLoaded(true);
    }
  }, [data, loaded]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setFormErr(null);
    setOk(null);
    const tel = telefon.trim();
    if (tel && !/^[+0-9 ()-]{7,}$/.test(tel)) {
      setFormErr("Telefon formatı geçersiz (örn. +905551234567).");
      return;
    }
    setSaving(true);
    try {
      await apiSend("/api/tenant/settings", "PATCH", {
        ad,
        timezone,
        acil_durum_telefon: tel || null,
      });
      setOk("Ayarlar kaydedildi.");
      mutate();
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="max-w-xl space-y-5">
      <h1 className="text-2xl font-semibold">Ayarlar</h1>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {data && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <div className="grid grid-cols-2 gap-3 text-sm text-muted">
            <div>
              <span className="block font-medium text-slate-700">Tesis kodu (slug)</span>
              {data.slug}
            </div>
            <div>
              <span className="block font-medium text-slate-700">Tenant ID</span>
              <span className="font-mono">{data.tenant_id.slice(0, 8)}</span>
            </div>
          </div>

          <Field label="Tesis adı">
            <input className={inputCls} value={ad} onChange={(e) => setAd(e.target.value)} required />
          </Field>

          <Field label="Zaman dilimi (timezone)" hint="Örn: Europe/Istanbul">
            <input
              className={inputCls}
              value={timezone}
              onChange={(e) => setTimezone(e.target.value)}
              required
            />
          </Field>

          <Field
            label="Acil durum yönetim telefonu"
            hint="Saha güvenliği panik bastığında mobil bu numarayı tel: ile arar. Örn: +905551234567"
          >
            <input
              className={inputCls}
              value={telefon}
              onChange={(e) => setTelefon(e.target.value)}
              placeholder="+905551234567"
              inputMode="tel"
            />
          </Field>

          <ErrorBox message={formErr} />
          {ok && <p className="text-sm text-emerald-700">{ok}</p>}

          <button type="submit" className={btnPrimary} disabled={saving}>
            {saving ? "Kaydediliyor..." : "Kaydet"}
          </button>
        </form>
      )}
    </div>
  );
}
