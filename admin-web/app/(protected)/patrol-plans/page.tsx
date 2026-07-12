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
import type {
  CheckpointList,
  PatrolPlan,
  PatrolPlanCheckpoint,
  PatrolPlanList,
  ShiftList,
} from "@/lib/types";

const LIMIT = 20;

interface FormState {
  ad: string;
  shift_id: string;
  baslangic_saat: string;
  bitis_saat: string;
  periyot_dakika: string;
  aktif: boolean;
}
const EMPTY: FormState = {
  ad: "",
  shift_id: "",
  baslangic_saat: "00:00",
  bitis_saat: "06:00",
  periyot_dakika: "60",
  aktif: true,
};

function windowCount(bas: string, bit: string, per: number): number {
  if (!per || per <= 0) return 0;
  const [bh, bm] = bas.split(":").map(Number);
  const [eh, em] = bit.split(":").map(Number);
  let span = eh * 60 + em - (bh * 60 + bm);
  if (span <= 0) span += 1440; // gece sarkmasi
  return Math.floor(span / per);
}

export default function PatrolPlansPage() {
  const [offset, setOffset] = useState(0);
  const { data, error, isLoading, mutate } = useSWR<PatrolPlanList>(
    `/api/patrol-plans?limit=${LIMIT}&offset=${offset}`,
    jsonFetcher,
  );
  const { data: shifts } = useSWR<ShiftList>("/api/shifts?limit=200&offset=0", jsonFetcher);
  const { data: checkpoints } = useSWR<CheckpointList>(
    "/api/checkpoints?limit=200&offset=0",
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // atama
  const [assignPlan, setAssignPlan] = useState<PatrolPlan | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [assignErr, setAssignErr] = useState<string | null>(null);
  const [assignSaving, setAssignSaving] = useState(false);
  const [addPick, setAddPick] = useState<string>("");

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(p: PatrolPlan) {
    setEditingId(p.id);
    setForm({
      ad: p.ad,
      shift_id: p.shift_id ?? "",
      baslangic_saat: p.baslangic_saat,
      bitis_saat: p.bitis_saat,
      periyot_dakika: String(p.periyot_dakika),
      aktif: p.aktif,
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
      shift_id: form.shift_id || null,
      baslangic_saat: form.baslangic_saat,
      bitis_saat: form.bitis_saat,
      periyot_dakika: Number(form.periyot_dakika),
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/patrol-plans/${editingId}`, "PATCH", body);
      else await apiSend("/api/patrol-plans", "POST", body);
      setOpen(false);
      mutate();
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function remove(p: PatrolPlan) {
    if (!window.confirm(`${p.ad} silinsin mi?`)) return;
    try {
      await apiSend(`/api/patrol-plans/${p.id}`, "DELETE");
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  async function openAssign(p: PatrolPlan) {
    setAssignPlan(p);
    setAssignErr(null);
    setAddPick("");
    try {
      const list = await apiSend<PatrolPlanCheckpoint[]>(
        `/api/patrol-plans/${p.id}/checkpoints`,
        "GET",
      );
      const ordered = [...list].sort((a, b) => a.sira - b.sira).map((x) => x.checkpoint_id);
      setSelected(ordered);
    } catch {
      setSelected([]);
    }
  }

  async function saveAssign() {
    if (!assignPlan) return;
    setAssignSaving(true);
    setAssignErr(null);
    try {
      await apiSend(`/api/patrol-plans/${assignPlan.id}/checkpoints`, "PUT", {
        items: selected.map((cid, i) => ({ checkpoint_id: cid, sira: i })),
      });
      setAssignPlan(null);
    } catch (err) {
      setAssignErr(err instanceof Error ? err.message : "Atama kaydedilemedi.");
    } finally {
      setAssignSaving(false);
    }
  }

  function cpName(id: string): string {
    return checkpoints?.items.find((c) => c.id === id)?.ad ?? id.slice(0, 8);
  }
  function shiftName(id?: string | null): string {
    if (!id) return "—";
    return shifts?.items.find((s) => s.id === id)?.ad ?? id.slice(0, 8);
  }
  function move(i: number, dir: -1 | 1) {
    const j = i + dir;
    if (j < 0 || j >= selected.length) return;
    const next = [...selected];
    [next[i], next[j]] = [next[j], next[i]];
    setSelected(next);
  }

  const available = (checkpoints?.items ?? []).filter((c) => !selected.includes(c.id));
  const previewWindows = windowCount(
    form.baslangic_saat,
    form.bitis_saat,
    Number(form.periyot_dakika),
  );

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Devriye Planları</h1>
        <button className={btnPrimary} onClick={openNew}>
          Yeni plan
        </button>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <form
          onSubmit={save}
          className="space-y-4 rounded-xl border border-slate-200 bg-white p-5"
        >
          <h2 className="font-medium">{editingId ? "Plan düzenle" : "Yeni plan"}</h2>
          <Field label="Ad">
            <input
              className={inputCls}
              value={form.ad}
              onChange={(e) => setForm({ ...form, ad: e.target.value })}
              required
            />
          </Field>
          <Field label="Vardiya (opsiyonel)">
            <select
              className={inputCls}
              value={form.shift_id}
              onChange={(e) => setForm({ ...form, shift_id: e.target.value })}
            >
              <option value="">— yok —</option>
              {(shifts?.items ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {s.ad}
                </option>
              ))}
            </select>
          </Field>
          <div className="grid grid-cols-3 gap-4">
            <Field label="Başlangıç" hint="HH:MM">
              <input
                type="time"
                className={inputCls}
                value={form.baslangic_saat}
                onChange={(e) => setForm({ ...form, baslangic_saat: e.target.value })}
                required
              />
            </Field>
            <Field label="Bitiş" hint="HH:MM">
              <input
                type="time"
                className={inputCls}
                value={form.bitis_saat}
                onChange={(e) => setForm({ ...form, bitis_saat: e.target.value })}
                required
              />
            </Field>
            <Field label="Periyot (dk)">
              <input
                type="number"
                min={1}
                className={inputCls}
                value={form.periyot_dakika}
                onChange={(e) => setForm({ ...form, periyot_dakika: e.target.value })}
                required
              />
            </Field>
          </div>
          <p className="text-xs text-muted">
            Önizleme: bu plan günde yaklaşık {previewWindows} pencere üretir.
          </p>
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

      {assignPlan && (
        <div className="space-y-4 rounded-xl border border-slate-300 bg-white p-5">
          <h2 className="font-medium">Noktalar: {assignPlan.ad}</h2>
          <p className="text-xs text-muted">
            Sıralı liste; kaydedince planın noktaları tamamen bununla değişir.
          </p>

          <ol className="space-y-2">
            {selected.map((cid, i) => (
              <li
                key={cid}
                className="flex items-center justify-between rounded-lg border border-slate-200 px-3 py-2 text-sm"
              >
                <span>
                  <span className="mr-2 text-muted">{i + 1}.</span>
                  {cpName(cid)}
                </span>
                <span className="flex gap-1">
                  <button className={btnGhost} onClick={() => move(i, -1)} disabled={i === 0}>
                    Yukarı
                  </button>
                  <button
                    className={btnGhost}
                    onClick={() => move(i, 1)}
                    disabled={i === selected.length - 1}
                  >
                    Aşağı
                  </button>
                  <button
                    className={btnDanger}
                    onClick={() => setSelected(selected.filter((x) => x !== cid))}
                  >
                    Çıkar
                  </button>
                </span>
              </li>
            ))}
            {selected.length === 0 && (
              <li className="rounded-lg border border-dashed border-slate-300 px-3 py-4 text-center text-muted">
                Henüz nokta eklenmedi.
              </li>
            )}
          </ol>

          <div className="flex items-end gap-2">
            <div className="grow">
              <Field label="Nokta ekle">
                <select
                  className={inputCls}
                  value={addPick}
                  onChange={(e) => setAddPick(e.target.value)}
                >
                  <option value="">— seç —</option>
                  {available.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.ad} ({c.nfc_tag_uid})
                    </option>
                  ))}
                </select>
              </Field>
            </div>
            <button
              className={btnGhost}
              disabled={!addPick}
              onClick={() => {
                if (addPick) setSelected([...selected, addPick]);
                setAddPick("");
              }}
            >
              Ekle
            </button>
          </div>

          <ErrorBox message={assignErr} />
          <div className="flex gap-2">
            <button className={btnPrimary} onClick={saveAssign} disabled={assignSaving}>
              {assignSaving ? "Kaydediliyor..." : "Atamayı kaydet"}
            </button>
            <button className={btnGhost} onClick={() => setAssignPlan(null)}>
              Kapat
            </button>
          </div>
        </div>
      )}

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-500">
            <tr>
              <th className="px-3 py-2 font-medium">Ad</th>
              <th className="px-3 py-2 font-medium">Vardiya</th>
              <th className="px-3 py-2 font-medium">Saat / Periyot</th>
              <th className="px-3 py-2 font-medium">Durum</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((p) => (
              <tr key={p.id} className="border-t border-slate-100">
                <td className="px-3 py-2">{p.ad}</td>
                <td className="px-3 py-2 text-slate-600">{shiftName(p.shift_id)}</td>
                <td className="px-3 py-2 text-slate-600">
                  {p.baslangic_saat}–{p.bitis_saat} · {p.periyot_dakika} dk
                </td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      p.aktif ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {p.aktif ? "aktif" : "pasif"}
                  </span>
                </td>
                <td className="px-3 py-2 text-right">
                  <div className="flex justify-end gap-2">
                    <button className={btnGhost} onClick={() => openAssign(p)}>
                      Noktalar
                    </button>
                    <button className={btnGhost} onClick={() => openEdit(p)}>
                      Düzenle
                    </button>
                    <button className={btnDanger} onClick={() => remove(p)}>
                      Sil
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={5}>
                  Plan yok.
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
