"use client";

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, PageHeader, inputCls, btnPrimary, panelCls, panelMotion } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { TenantSettings } from "@/lib/types";

export default function SettingsPage() {
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<TenantSettings>(
    "/api/tenant/settings",
    jsonFetcher,
  );

  const [ad, setAd] = useState("");
  const [timezone, setTimezone] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Ilk yuklemede formu doldur.
  useEffect(() => {
    if (data && !loaded) {
      setAd(data.ad);
      setTimezone(data.timezone);
      setLoaded(true);
    }
  }, [data, loaded]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setFormErr(null);
    setOk(null);
    setSaving(true);
    try {
      await apiSend("/api/tenant/settings", "PATCH", { ad, timezone });
      setOk("Ayarlar kaydedildi.");
      mutate();
      toast.success("Ayarlar kaydedildi.");
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="max-w-xl space-y-5">
      <PageHeader title="Ayarlar" />

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {data && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
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

          <ErrorBox message={formErr} />
          {ok && <p className="text-sm text-emerald-700">{ok}</p>}

          <button type="submit" className={btnPrimary} disabled={saving}>
            {saving ? "Kaydediliyor..." : "Kaydet"}
          </button>
        </motion.form>
      )}
    </div>
  );
}
