"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary, btnGhost, btnDanger } from "@/components/form";
import { UnitDetail } from "@/components/UnitDetail";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { Unit, UnitList } from "@/lib/types";

const LIMIT = 20;

interface FormState {
  no: string;
  blok: string;
  metrekare: string;
  aktif: boolean;
}
const EMPTY: FormState = { no: "", blok: "", metrekare: "", aktif: true };

function numOrNull(s: string): number | null {
  const t = s.trim();
  if (t === "") return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export default function UnitsPage() {
  const [offset, setOffset] = useState(0);
  const [blok, setBlok] = useState("");
  const blokQs = blok ? `&blok=${encodeURIComponent(blok)}` : "";
  const { data, error, isLoading, mutate } = useSWR<UnitList>(
    `/api/units?limit=${LIMIT}&offset=${offset}${blokQs}`,
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [detail, setDetail] = useState<Unit | null>(null);

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(u: Unit) {
    setEditingId(u.id);
    setForm({
      no: u.no,
      blok: u.blok ?? "",
      metrekare: u.metrekare != null ? String(u.metrekare) : "",
      aktif: u.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    const body = {
      no: form.no.trim(),
      blok: form.blok.trim() || null,
      metrekare: numOrNull(form.metrekare),
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/units/${editingId}`, "PATCH", body);
      else await apiSend("/api/units", "POST", body);
      setOpen(false);
      mutate();
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(/zaten kayitli|conflict|no /i.test(m) ? "Bu daire no zaten kayitli." : m);
    } finally {
      setSaving(false);
    }
  }

  async function remove(u: Unit) {
    if (!window.confirm(`${u.no} silinsin mi?`)) return;
    try {
      await apiSend(`/api/units/${u.id}`, "DELETE");
      if (detail?.id === u.id) setDetail(null);
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Daireler</h1>
        <button className={btnPrimary} onClick={openNew}>
          Yeni daire
        </button>
      </div>

      <div className="flex items-end gap-2">
        <div className="w-48">
          <Field label="Blok filtresi">
            <input
              className={inputCls}
              value={blok}
              onChange={(e) => {
                setBlok(e.target.value);
                setOffset(0);
              }}
              placeholder="A"
            />
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yukleniyor...</p>}

      {open && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">{editingId ? "Daire duzenle" : "Yeni daire"}</h2>
          <div className="grid grid-cols-3 gap-4">
            <Field label="Daire no" hint="Tesiste benzersiz">
              <input
                className={inputCls}
                value={form.no}
                onChange={(e) => setForm({ ...form, no: e.target.value })}
                placeholder="A-12"
                required
              />
            </Field>
            <Field label="Blok (opsiyonel)">
              <input
                className={inputCls}
                value={form.blok}
                onChange={(e) => setForm({ ...form, blok: e.target.value })}
              />
            </Field>
            <Field label="Metrekare (opsiyonel)">
              <input
                className={inputCls}
                inputMode="decimal"
                value={form.metrekare}
                onChange={(e) => setForm({ ...form, metrekare: e.target.value })}
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
              Iptal
            </button>
          </div>
        </form>
      )}

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-500">
            <tr>
              <th className="px-3 py-2 font-medium">No</th>
              <th className="px-3 py-2 font-medium">Blok</th>
              <th className="px-3 py-2 font-medium">m²</th>
              <th className="px-3 py-2 font-medium">Durum</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((u) => (
              <tr key={u.id} className="border-t border-slate-100">
                <td className="px-3 py-2">{u.no}</td>
                <td className="px-3 py-2 text-slate-600">{u.blok ?? "—"}</td>
                <td className="px-3 py-2 text-slate-600">{u.metrekare ?? "—"}</td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      u.aktif ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {u.aktif ? "aktif" : "pasif"}
                  </span>
                </td>
                <td className="px-3 py-2 text-right">
                  <div className="flex justify-end gap-2">
                    <button
                      className={btnGhost}
                      onClick={() => setDetail(detail?.id === u.id ? null : u)}
                    >
                      {detail?.id === u.id ? "Kapat" : "Detay / Aidat"}
                    </button>
                    <button className={btnGhost} onClick={() => openEdit(u)}>
                      Duzenle
                    </button>
                    <button className={btnDanger} onClick={() => remove(u)}>
                      Sil
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={5}>
                  Daire yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {detail && <UnitDetail unit={detail} />}

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
