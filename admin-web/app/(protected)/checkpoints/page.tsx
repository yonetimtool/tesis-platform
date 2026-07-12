"use client";

import { useState } from "react";
import useSWR from "swr";

import {
  Field,
  ErrorBox,
  Pager,
  inputCls,
  btnPrimary,
  btnGhost,
  btnDanger,
} from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { Checkpoint, CheckpointList } from "@/lib/types";

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

function numOrNull(s: string): number | null {
  const t = s.trim();
  if (t === "") return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export default function CheckpointsPage() {
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
    const body = {
      ad: form.ad,
      nfc_tag_uid: form.nfc_tag_uid.trim(),
      gps_lat: numOrNull(form.gps_lat),
      gps_lng: numOrNull(form.gps_lng),
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/checkpoints/${editingId}`, "PATCH", body);
      else await apiSend("/api/checkpoints", "POST", body);
      setOpen(false);
      mutate();
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Kaydedilemedi.";
      // nfc cakismasi (409) -> anlamli mesaj
      setFormErr(
        /nfc/i.test(msg)
          ? "Bu NFC etiketi başka bir noktada kullanılıyor."
          : msg,
      );
    } finally {
      setSaving(false);
    }
  }

  async function remove(c: Checkpoint) {
    if (!window.confirm(`${c.ad} silinsin mi?`)) return;
    try {
      await apiSend(`/api/checkpoints/${c.id}`, "DELETE");
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">NFC Noktaları</h1>
        <button className={btnPrimary} onClick={openNew}>
          Yeni nokta
        </button>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <form
          onSubmit={save}
          className="space-y-4 rounded-xl border border-slate-200 bg-white p-5"
        >
          <h2 className="font-medium">{editingId ? "Nokta düzenle" : "Yeni nokta"}</h2>
          <Field label="Ad">
            <input
              className={inputCls}
              value={form.ad}
              onChange={(e) => setForm({ ...form, ad: e.target.value })}
              required
            />
          </Field>
          <Field
            label="NFC etiket UID"
            hint="Büyük harf hex, ayraçsız. Örnek: 04A1B2C3D4 (mobil okuyucu bu formatta gönderir)."
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
            <Field label="GPS enlem (opsiyonel)">
              <input
                className={inputCls}
                inputMode="decimal"
                value={form.gps_lat}
                placeholder="41.015137"
                onChange={(e) => setForm({ ...form, gps_lat: e.target.value })}
              />
            </Field>
            <Field label="GPS boylam (opsiyonel)">
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
              <th className="px-3 py-2 font-medium">NFC UID</th>
              <th className="px-3 py-2 font-medium">GPS</th>
              <th className="px-3 py-2 font-medium">Durum</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((c) => (
              <tr key={c.id} className="border-t border-slate-100">
                <td className="px-3 py-2">{c.ad}</td>
                <td className="px-3 py-2 font-mono text-slate-600">{c.nfc_tag_uid}</td>
                <td className="px-3 py-2 text-slate-600">
                  {c.gps_lat != null && c.gps_lng != null
                    ? `${c.gps_lat}, ${c.gps_lng}`
                    : "—"}
                </td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      c.aktif ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {c.aktif ? "aktif" : "pasif"}
                  </span>
                </td>
                <td className="px-3 py-2 text-right">
                  <div className="flex justify-end gap-2">
                    <button className={btnGhost} onClick={() => openEdit(c)}>
                      Düzenle
                    </button>
                    <button className={btnDanger} onClick={() => remove(c)}>
                      Sil
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={5}>
                  Nokta yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
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
