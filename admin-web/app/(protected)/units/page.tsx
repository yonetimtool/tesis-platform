"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, btnDanger, panelCls, panelMotion } from "@/components/form";
import { useToast } from "@/components/Toast";
import { UnitDetail } from "@/components/UnitDetail";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { Unit, UnitList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

const LIMIT = 20;

interface FormState {
  no: string;
  blok: string;
  kat: string;
  sira: string;
  metrekare: string;
  aktif: boolean;
}
const EMPTY: FormState = { no: "", blok: "", kat: "", sira: "", metrekare: "", aktif: true };

function numOrNull(s: string): number | null {
  const t = s.trim();
  if (t === "") return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

// Yerlesim: kat/sira tam sayi olmali (ondalik girilirse null -> gonderilmez).
function intOrNull(s: string): number | null {
  const t = s.trim();
  if (t === "") return null;
  const n = Number(t);
  return Number.isInteger(n) ? n : null;
}

export default function UnitsPage() {
  const t = useT();
  const toast = useToast();
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
      kat: u.kat != null ? String(u.kat) : "",
      sira: u.sira != null ? String(u.sira) : "",
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
      blok: form.blok.trim(),  // blok ZORUNLU (canli-site kurali)
      kat: intOrNull(form.kat),
      sira: intOrNull(form.sira),
      metrekare: numOrNull(form.metrekare),
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/units/${editingId}`, "PATCH", body);
      else await apiSend("/api/units", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("daireGuncellendi") : t("daireOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(/zaten kayitli|conflict|no /i.test(m) ? t("daireNoZatenKayitli") : m);
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
      toast.success("Daire silindi.");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukDaireler")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("daireYeni")}</button>
        }
      />

      <div className="flex items-end gap-2">
        <div className="w-full sm:w-48">
          <Field label={t("daireBlokFiltresi")}>
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
      {isLoading && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("daireDuzenle") : t("daireYeni")}</h2>
          <div className="grid grid-cols-3 gap-4">
            <Field label={t("binaDaireNo")} hint={t("daireNoIpucu")}>
              <input
                className={inputCls}
                value={form.no}
                onChange={(e) => setForm({ ...form, no: e.target.value })}
                placeholder="A-12"
                pattern="[A-Za-z0-9-]+"
                title={t("daireNoGecersiz")}
                required
              />
            </Field>
            <Field label={t("ortakBlok")} hint={t("blokIpucu")}>
              <input
                className={inputCls}
                value={form.blok}
                onChange={(e) => setForm({ ...form, blok: e.target.value })}
                pattern="[A-Za-z0-9]+"
                maxLength={8}
                title={t("blokGecersiz")}
                placeholder="A"
                required
              />
            </Field>
            <Field label={t("daireMetrekareOpsiyonel")}>
              <input
                className={inputCls}
                inputMode="decimal"
                value={form.metrekare}
                onChange={(e) => setForm({ ...form, metrekare: e.target.value })}
              />
            </Field>
            <Field label={t("daireKatOpsiyonel")} hint={t("katIpucu")}>
              <input
                className={inputCls}
                inputMode="numeric"
                value={form.kat}
                onChange={(e) => setForm({ ...form, kat: e.target.value })}
                placeholder="1"
              />
            </Field>
            <Field label={t("siraOpsiyonel")} hint={t("siraIpucu")}>
              <input
                className={inputCls}
                inputMode="numeric"
                value={form.sira}
                onChange={(e) => setForm({ ...form, sira: e.target.value })}
                placeholder="2"
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

      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
        <div className="odak-ic overflow-x-auto" tabIndex={0}>
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-4 py-2.5 font-medium">{t("daireNoKisa")}</th>
                <th className="px-4 py-2.5 font-medium">{t("ortakBlok")}</th>
                <th className="px-4 py-2.5 font-medium">{t("daireKatSira")}</th>
                <th className="px-4 py-2.5 font-medium">m²</th>
                <th className="px-4 py-2.5 font-medium">{t("ortakDurum")}</th>
                <th className="px-4 py-2.5 font-medium" />
              </tr>
            </thead>
            <tbody>
              {(data?.items ?? []).map((u) => (
                <tr key={u.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                  <td className="px-4 py-2.5">{u.no}</td>
                  <td className="px-4 py-2.5 text-slate-600">{u.blok ?? t("daireBlokAtanmamis")}</td>
                  <td className="px-4 py-2.5 text-slate-600 tabular-nums">
                    {u.kat != null || u.sira != null ? `${u.kat ?? "—"} / ${u.sira ?? "—"}` : "—"}
                  </td>
                  <td className="px-4 py-2.5 text-slate-600 tabular-nums">{u.metrekare ?? "—"}</td>
                  <td className="px-4 py-2.5">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        u.aktif ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-slate-600"
                      }`}
                    >
                      {u.aktif ? t("ortakAktif") : t("ortakPasif")}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-right">
                    <div className="flex justify-end gap-2">
                      <button
                        className={btnGhost}
                        onClick={() => setDetail(detail?.id === u.id ? null : u)}
                      >
                        {detail?.id === u.id ? t("ortakKapat") : t("daireDetayAidat")}
                      </button>
                      <button className={btnGhost} onClick={() => openEdit(u)}>
                        {t("ortakDuzenle")}
                      </button>
                      <button className={btnDanger} onClick={() => remove(u)}>
                        {t("ortakSil")}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {data && data.items.length === 0 && (
                <tr>
                  <td colSpan={6}>
                    <EmptyState title={t("daireYok")} description={t("daireYokAlt")} />
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
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
