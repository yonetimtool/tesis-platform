"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  Field,
  ErrorBox,
  Pager,
  PageHeader,
  inputCls,
  btnPrimary,
  btnGhost,
  btnDanger,
  panelCls,
  panelMotion,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { Checkpoint, CheckpointList } from "@/lib/types";
import { sayiCoz } from "@/lib/sayi";
import { useT } from "@/lib/i18n/kullan";

const LIMIT = 20;
// Mobil POC ile tutarli: buyuk harf hex, ayracsiz.
const NFC_PLACEHOLDER = "04A1B2C3D4";

interface FormState {
  ad: string;
  nfc_tag_uid: string;
  gps_lat: string;
  gps_lng: string;
  aktif: boolean;
}
const EMPTY: FormState = { ad: "", nfc_tag_uid: "", gps_lat: "", gps_lng: "", aktif: true };

// (P56) `numOrNull` KALDIRILDI: `Number("41,0082")` NaN doner ve NaN
// `null`a cevriliyordu — yani GPS'i Turkce yazimla giren kullanici
// koordinati SESSIZCE SILDIRIYORDU. `sayiCoz` bos ile gecersizi ayirir.

export default function CheckpointsPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const { data, error, isLoading, mutate } = useSWR<CheckpointList>(
    `/api/checkpoints?limit=${LIMIT}&offset=${offset}`,
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(c: Checkpoint) {
    setEditingId(c.id);
    setForm({
      ad: c.ad,
      nfc_tag_uid: c.nfc_tag_uid,
      gps_lat: c.gps_lat != null ? String(c.gps_lat) : "",
      gps_lng: c.gps_lng != null ? String(c.gps_lng) : "",
      aktif: c.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    const lat = sayiCoz(form.gps_lat);
    const lng = sayiCoz(form.gps_lng);
    if (lat.tur === "gecersiz" || lng.tur === "gecersiz") {
      setFormErr(t("noktaKonumGecersiz"));
      setSaving(false);
      return;
    }
    const body = {
      ad: form.ad,
      nfc_tag_uid: form.nfc_tag_uid.trim(),
      gps_lat: lat.tur === "sayi" ? lat.deger : null,
      gps_lng: lng.tur === "sayi" ? lng.deger : null,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/checkpoints/${editingId}`, "PATCH", body);
      else await apiSend("/api/checkpoints", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("noktaGuncellendi") : t("noktaOlusturuldu"));
    } catch (err) {
      const msg = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      // nfc cakismasi (409) -> anlamli mesaj
      setFormErr(
        /nfc/i.test(msg)
          ? t("noktaEtiketKullanimda")
          : msg,
      );
    } finally {
      setSaving(false);
    }
  }

  async function remove(c: Checkpoint) {
    if (!window.confirm(t("ortakSilOnay", { ad: c.ad }))) return;
    try {
      await apiSend(`/api/checkpoints/${c.id}`, "DELETE");
      mutate();
      toast.success(t("noktaSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukNfcNoktalari")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("noktaYeni")}</button>
        }
      />

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("noktaDuzenle") : t("noktaYeni")}</h2>
          <Field label={t("ortakAd")}>
            <input
              className={inputCls}
              value={form.ad}
              onChange={(e) => setForm({ ...form, ad: e.target.value })}
              required
            />
          </Field>
          <Field
            label={t("noktaEtiketUid")}
            hint={t("noktaEtiketIpucu")}
          >
            <input
              className={`${inputCls} font-mono uppercase`}
              value={form.nfc_tag_uid}
              placeholder={NFC_PLACEHOLDER}
              onChange={(e) =>
                setForm({ ...form, nfc_tag_uid: e.target.value.toUpperCase() })
              }
              required
            />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("noktaGpsEnlem")}>
              <input
                className={inputCls}
                inputMode="decimal"
                value={form.gps_lat}
                placeholder="41.015137"
                onChange={(e) => setForm({ ...form, gps_lat: e.target.value })}
              />
            </Field>
            <Field label={t("noktaGpsBoylam")}>
              <input
                className={inputCls}
                inputMode="decimal"
                value={form.gps_lng}
                placeholder="28.979530"
                onChange={(e) => setForm({ ...form, gps_lng: e.target.value })}
              />
            </Field>
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />
            {t("ortakAktif")}
          </label>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              {t("ortakIptal")}
            </button>
          </div>
        </motion.form>
      )}

      <div className="overflow-hidden rounded-kart border kart-kenar bg-white">
        <div className="odak-ic overflow-x-auto" tabIndex={0}>
          <table className="w-full text-sm">
            <thead className="bg-yuzey-bg text-left text-metin-muted">
              <tr>
                <th className="px-4 py-2.5 font-medium">{t("ortakAd")}</th>
                <th className="px-4 py-2.5 font-medium">{t("noktaUid")}</th>
                <th className="px-4 py-2.5 font-medium">GPS</th>
                <th className="px-4 py-2.5 font-medium">{t("ortakDurum")}</th>
                <th className="px-4 py-2.5 font-medium" />
              </tr>
            </thead>
            <tbody>
              {(data?.items ?? []).map((c) => (
                <tr key={c.id} className="border-t border-yuzey-divider transition-colors hover:bg-yuzey-bg">
                  <td className="px-4 py-2.5">{c.ad}</td>
                  <td className="px-4 py-2.5 font-mono text-metin-body">{c.nfc_tag_uid}</td>
                  <td className="px-4 py-2.5 text-metin-body">
                    {c.gps_lat != null && c.gps_lng != null
                      ? `${c.gps_lat}, ${c.gps_lng}`
                      : "—"}
                  </td>
                  <td className="px-4 py-2.5">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        c.aktif ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-metin-body"
                      }`}
                    >
                      {c.aktif ? t("ortakAktif") : t("ortakPasif")}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-right">
                    <div className="flex justify-end gap-2">
                      <button className={btnGhost} onClick={() => openEdit(c)}>
                        {t("ortakDuzenle")}
                      </button>
                      <button className={btnDanger} onClick={() => remove(c)}>
                        {t("ortakSil")}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {data && data.items.length === 0 && (
                <tr>
                  <td colSpan={5}>
                    <EmptyState title={t("noktaYok")} description={t("noktaYokAlt")} />
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
