"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary, btnGhost, btnDanger } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Announcement, AnnouncementList } from "@/lib/types";

const LIMIT = 20;

interface FormState {
  baslik: string;
  govde: string;
}
const EMPTY: FormState = { baslik: "", govde: "" };

// Duyuru olusturmada backend, tenant'in TUM aktif cihazlarina push dener
// (auth.md §4) — panelden gonderilen duyuru mobil kullanicilara da duser.
export default function AnnouncementsPage() {
  const [offset, setOffset] = useState(0);
  const { data, error, isLoading, mutate } = useSWR<AnnouncementList>(
    `/api/announcements?limit=${LIMIT}&offset=${offset}`,
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
  function openEdit(a: Announcement) {
    setEditingId(a.id);
    setForm({ baslik: a.baslik, govde: a.govde });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      if (editingId) {
        await apiSend(`/api/announcements/${editingId}`, "PATCH", form);
      } else {
        await apiSend("/api/announcements", "POST", form);
      }
      setOpen(false);
      mutate();
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function remove(a: Announcement) {
    if (!window.confirm(`"${a.baslik}" duyurusu silinsin mi?`)) return;
    try {
      await apiSend(`/api/announcements/${a.id}`, "DELETE");
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Duyurular</h1>
        <button className={btnPrimary} onClick={openNew}>
          Yeni duyuru
        </button>
      </div>

      <p className="text-sm text-muted">
        Duyurular tum rollere gorunur; yayinlandiginda tesisin kayitli tum
        cihazlarina bildirim denenir.
      </p>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yukleniyor...</p>}

      {open && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">{editingId ? "Duyuru duzenle" : "Yeni duyuru"}</h2>
          <Field label="Baslik" hint="En fazla 200 karakter">
            <input
              className={inputCls}
              value={form.baslik}
              onChange={(e) => setForm({ ...form, baslik: e.target.value })}
              maxLength={200}
              required
            />
          </Field>
          <Field label="Duyuru metni" hint="En fazla 5000 karakter">
            <textarea
              className={`${inputCls} min-h-32`}
              value={form.govde}
              onChange={(e) => setForm({ ...form, govde: e.target.value })}
              maxLength={5000}
              required
            />
          </Field>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? "Kaydediliyor..." : editingId ? "Kaydet" : "Yayinla"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              Iptal
            </button>
          </div>
        </form>
      )}

      <ul className="space-y-3">
        {(data?.items ?? []).map((a) => (
          <li key={a.id} className="rounded-xl border border-slate-200 bg-white p-5">
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0">
                <h3 className="font-medium">{a.baslik}</h3>
                <p className="mt-1 whitespace-pre-wrap text-sm text-slate-600">{a.govde}</p>
                <p className="mt-2 text-xs text-muted">
                  {a.olusturan_ad ?? "—"} · {formatDateTime(a.created_at)}
                  {a.updated_at !== a.created_at && " · duzenlendi"}
                </p>
              </div>
              <div className="flex shrink-0 gap-2">
                <button className={btnGhost} onClick={() => openEdit(a)}>
                  Duzenle
                </button>
                <button className={btnDanger} onClick={() => remove(a)}>
                  Sil
                </button>
              </div>
            </div>
          </li>
        ))}
        {data && data.items.length === 0 && (
          <li className="rounded-xl border border-slate-200 bg-white p-6 text-center text-muted">
            Henuz duyuru yok.
          </li>
        )}
      </ul>

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
