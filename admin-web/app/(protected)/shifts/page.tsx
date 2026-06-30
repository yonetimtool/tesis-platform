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
import type { GunTipi, Shift, ShiftList } from "@/lib/types";

const LIMIT = 20;
const GUN_TIPI_OPTS: { value: GunTipi; label: string }[] = [
  { value: "her_gun", label: "Her gun" },
  { value: "hafta_ici", label: "Hafta ici" },
  { value: "hafta_sonu", label: "Hafta sonu" },
  { value: "resmi_tatil", label: "Resmi tatil" },
];

interface FormState {
  ad: string;
  baslangic_saat: string;
  bitis_saat: string;
  gun_tipi: GunTipi;
}
const EMPTY: FormState = {
  ad: "",
  baslangic_saat: "00:00",
  bitis_saat: "08:00",
  gun_tipi: "her_gun",
};

function gunTipiLabel(v: string): string {
  return GUN_TIPI_OPTS.find((o) => o.value === v)?.label ?? v;
}

export default function ShiftsPage() {
  const [offset, setOffset] = useState(0);
  const { data, error, isLoading, mutate } = useSWR<ShiftList>(
    `/api/shifts?limit=${LIMIT}&offset=${offset}`,
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
  function openEdit(s: Shift) {
    setEditingId(s.id);
    setForm({
      ad: s.ad,
      baslangic_saat: s.baslangic_saat,
      bitis_saat: s.bitis_saat,
      gun_tipi: (s.gun_tipi as GunTipi) ?? "her_gun",
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      if (editingId) await apiSend(`/api/shifts/${editingId}`, "PATCH", form);
      else await apiSend("/api/shifts", "POST", form);
      setOpen(false);
      mutate();
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function remove(s: Shift) {
    if (!window.confirm(`${s.ad} silinsin mi?`)) return;
    try {
      await apiSend(`/api/shifts/${s.id}`, "DELETE");
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  const overnight = form.baslangic_saat > form.bitis_saat;

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Vardiyalar</h1>
        <button className={btnPrimary} onClick={openNew}>
          Yeni vardiya
        </button>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yukleniyor...</p>}

      {open && (
        <form
          onSubmit={save}
          className="space-y-4 rounded-xl border border-slate-200 bg-white p-5"
        >
          <h2 className="font-medium">{editingId ? "Vardiya duzenle" : "Yeni vardiya"}</h2>
          <Field label="Ad">
            <input
              className={inputCls}
              value={form.ad}
              onChange={(e) => setForm({ ...form, ad: e.target.value })}
              required
            />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Baslangic" hint="24 saat (HH:MM)">
              <input
                type="time"
                className={inputCls}
                value={form.baslangic_saat}
                onChange={(e) => setForm({ ...form, baslangic_saat: e.target.value })}
                required
              />
            </Field>
            <Field label="Bitis" hint="24 saat (HH:MM)">
              <input
                type="time"
                className={inputCls}
                value={form.bitis_saat}
                onChange={(e) => setForm({ ...form, bitis_saat: e.target.value })}
                required
              />
            </Field>
          </div>
          {overnight && (
            <p className="text-xs text-amber-700">
              Bilgi: baslangic bitisten sonra; gece vardiyasi (ertesi gune sarkar).
            </p>
          )}
          <Field label="Gun tipi">
            <select
              className={inputCls}
              value={form.gun_tipi}
              onChange={(e) => setForm({ ...form, gun_tipi: e.target.value as GunTipi })}
            >
              {GUN_TIPI_OPTS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </Field>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? "Kaydediliyor..." : "Kaydet"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              Iptal
            </button>
          </div>
        </form>
      )}

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-500">
            <tr>
              <th className="px-3 py-2 font-medium">Ad</th>
              <th className="px-3 py-2 font-medium">Saat</th>
              <th className="px-3 py-2 font-medium">Gun tipi</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((s) => (
              <tr key={s.id} className="border-t border-slate-100">
                <td className="px-3 py-2">{s.ad}</td>
                <td className="px-3 py-2 text-slate-600">
                  {s.baslangic_saat} – {s.bitis_saat}
                </td>
                <td className="px-3 py-2 text-slate-600">{gunTipiLabel(s.gun_tipi)}</td>
                <td className="px-3 py-2 text-right">
                  <div className="flex justify-end gap-2">
                    <button className={btnGhost} onClick={() => openEdit(s)}>
                      Duzenle
                    </button>
                    <button className={btnDanger} onClick={() => remove(s)}>
                      Sil
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={4}>
                  Vardiya yok.
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
