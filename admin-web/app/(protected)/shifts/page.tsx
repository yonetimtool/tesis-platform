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
import type { GunTipi, Shift, ShiftList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

const LIMIT = 20;
// METIN DEGIL KIMLIK: `value` sozlesme degeri, `anahtar` gorunen adin
// sozluk anahtari. Modul duzeyinde `t()` cagrilamaz; cozum cizimde.
const GUN_TIPI_OPTS: { value: GunTipi; anahtar: SozlukAnahtari }[] = [
  { value: "her_gun", anahtar: "vardiyaHerGun" },
  { value: "hafta_ici", anahtar: "vardiyaHaftaIci" },
  { value: "hafta_sonu", anahtar: "vardiyaHaftaSonu" },
  { value: "resmi_tatil", anahtar: "vardiyaResmiTatil" },
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

/// Gun tipi ADI — `t` cizim katmanindan gelir. Taninmayan deger HAM
/// gosterilir (sunucu yeni bir tip eklerse hucre bos kalmasin).
function gunTipiAdi(t: (a: SozlukAnahtari) => string, v: string): string {
  const o = GUN_TIPI_OPTS.find((x) => x.value === v);
  return o ? t(o.anahtar) : v;
}

export default function ShiftsPage() {
  const t = useT();
  const toast = useToast();
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
      toast.success(editingId ? t("vardiyaGuncellendi") : t("vardiyaOlusturuldu"));
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
      toast.success(t("vardiyaSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  const overnight = form.baslangic_saat > form.bitis_saat;

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukVardiyalar")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("vardiyaYeni")}</button>
        }
      />

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("vardiyaDuzenle") : t("vardiyaYeni")}</h2>
          <Field label={t("ortakAd")}>
            <input
              className={inputCls}
              value={form.ad}
              onChange={(e) => setForm({ ...form, ad: e.target.value })}
              required
            />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("ortakBaslangic")} hint={t("ortakSaat24")}>
              <input
                type="time"
                className={inputCls}
                value={form.baslangic_saat}
                onChange={(e) => setForm({ ...form, baslangic_saat: e.target.value })}
                required
              />
            </Field>
            <Field label={t("ortakBitis")} hint={t("ortakSaat24")}>
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
              {t("vardiyaGeceNotu")}
            </p>
          )}
          <Field label={t("vardiyaGunTipi")}>
            <select
              className={inputCls}
              value={form.gun_tipi}
              onChange={(e) => setForm({ ...form, gun_tipi: e.target.value as GunTipi })}
            >
              {GUN_TIPI_OPTS.map((o) => (
                <option key={o.value} value={o.value}>
                  {t(o.anahtar)}
                </option>
              ))}
            </select>
          </Field>
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
                <th className="px-4 py-2.5 font-medium">{t("ortakAd")}</th>
                <th className="px-4 py-2.5 font-medium">{t("ortakSaat")}</th>
                <th className="px-4 py-2.5 font-medium">{t("vardiyaGunTipi")}</th>
                <th className="px-4 py-2.5 font-medium" />
              </tr>
            </thead>
            <tbody>
              {(data?.items ?? []).map((s) => (
                <tr key={s.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                  <td className="px-4 py-2.5">{s.ad}</td>
                  <td className="px-4 py-2.5 text-slate-600 tabular-nums">
                    {s.baslangic_saat} – {s.bitis_saat}
                  </td>
                  <td className="px-4 py-2.5 text-slate-600">{gunTipiAdi(t, s.gun_tipi)}</td>
                  <td className="px-4 py-2.5 text-right">
                    <div className="flex justify-end gap-2">
                      <button className={btnGhost} onClick={() => openEdit(s)}>
                        {t("ortakDuzenle")}
                      </button>
                      <button className={btnDanger} onClick={() => remove(s)}>
                        {t("ortakSil")}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {data && data.items.length === 0 && (
                <tr>
                  <td colSpan={4}>
                    <EmptyState
                      title={t("vardiyaYok")}
                      description={t("vardiyaYokAlt")}
                    />
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
