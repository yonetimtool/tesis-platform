"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, panelCls, panelMotion } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { ROLE_OPTIONS as ROLES, ROLE_STYLE, rolAdi } from "@/lib/roles";
import type { UserDetail, UserListResponse, UserRole, UserRow } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

const LIMIT = 20;

interface FormState {
  ad: string;
  email: string;
  telefon: string;
  aranabilir: boolean;
  role: UserRole;
  password: string;
}
const EMPTY: FormState = {
  ad: "",
  email: "",
  telefon: "",
  aranabilir: false,
  role: "security",
  password: "",
};

export default function UsersPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const [role, setRole] = useState<string>("");
  const [aktif, setAktif] = useState<string>("");
  const [q, setQ] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (role) qs.set("role", role);
  if (aktif) qs.set("is_active", aktif);
  if (q.trim()) qs.set("q", q.trim());
  const { data, error, isLoading, mutate } = useSWR<UserListResponse>(
    `/api/users?${qs.toString()}`,
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function resetFilters(next: { role?: string; aktif?: string; q?: string }) {
    if (next.role !== undefined) setRole(next.role);
    if (next.aktif !== undefined) setAktif(next.aktif);
    if (next.q !== undefined) setQ(next.q);
    setOffset(0);
  }

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  async function openEdit(u: UserRow) {
    setEditingId(u.id);
    // Numara listede DONMEZ (KVKK); tek-kayit detayindan cekilir.
    setForm({
      ad: u.ad,
      email: u.email,
      telefon: "",
      aranabilir: u.aranabilir ?? false,
      role: (u.role as UserRole) ?? "security",
      password: "",
    });
    setFormErr(null);
    setOpen(true);
    try {
      const d = await jsonFetcher<UserDetail>(`/api/users/${u.id}`);
      setForm((f) => ({
        ...f,
        telefon: d.telefon ?? "",
        aranabilir: d.aranabilir ?? false,
      }));
    } catch {
      // Detay cekilemezse form yine acik kalir (telefon bos); kaydetmeye engel yok.
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      if (editingId) {
        // PATCH: parola yalniz doluysa gonderilir (bossa degismez).
        const body: Record<string, unknown> = {
          ad: form.ad,
          email: form.email || null,
          telefon: form.telefon || null,
          aranabilir: form.aranabilir,
          role: form.role,
        };
        if (form.password) body.password = form.password;
        await apiSend(`/api/users/${editingId}`, "PATCH", body);
      } else {
        // Telefon = global benzersiz giris anahtari (zorunlu). E-posta opsiyonel.
        // Parola bossa backend TEK SEFERLIK gecici kod uretir (temp_code).
        const body: Record<string, unknown> = {
          ad: form.ad,
          telefon: form.telefon,
          aranabilir: form.aranabilir,
          role: form.role,
        };
        if (form.email) body.email = form.email;
        if (form.password) body.password = form.password;
        const created = await apiSend<{ temp_code?: string | null }>(
          "/api/users",
          "POST",
          body,
        );
        if (created?.temp_code) {
          window.alert(
            t("kullaniciGeciciKod", { kod: created.temp_code }),
          );
        }
      }
      setOpen(false);
      mutate();
      toast.success(editingId ? t("kullaniciGuncellendi") : t("kullaniciOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(
        /email|e-posta|telefon|zaten kayitli|conflict/i.test(m)
          ? t("kullaniciZatenKayitli")
          : m,
      );
    } finally {
      setSaving(false);
    }
  }

  async function setActive(u: UserRow, active: boolean) {
    try {
      await apiSend(`/api/users/${u.id}`, "PATCH", { is_active: active });
      mutate();
      toast.success(active ? t("kullaniciAktiflestirildi") : t("kullaniciPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukKullanicilar")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("kullaniciYeni")}</button>
        }
      />

      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <Field label={t("ortakRol")}>
            <select className={inputCls} value={role} onChange={(e) => resetFilters({ role: e.target.value })}>
              <option value="">{t("ortakTumu")}</option>
              {ROLES.map((r) => (
                <option key={r.value} value={r.value}>
                  {t(r.anahtar)}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-44">
          <Field label={t("ortakDurum")}>
            <select className={inputCls} value={aktif} onChange={(e) => resetFilters({ aktif: e.target.value })}>
              <option value="">{t("ortakTumu")}</option>
              <option value="true">{t("ortakAktif")}</option>
              <option value="false">{t("ortakPasif")}</option>
            </select>
          </Field>
        </div>
        <div className="grow">
          <Field label={t("kullaniciArama")}>
            <input
              className={inputCls}
              value={q}
              onChange={(e) => resetFilters({ q: e.target.value })}
              placeholder={t("kullaniciAramaIpucu")}
            />
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("kullaniciDuzenle") : t("kullaniciYeni")}</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("ortakAd")}>
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label={t("kullaniciEpostaOpsiyonel")} hint={t("kullaniciEpostaIpucu")}>
              <input
                type="email"
                className={inputCls}
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            </Field>
            <Field
              label={t("kullaniciTelefon")}
              hint={t("kullaniciTelefonIpucu")}
            >
              <input
                className={inputCls}
                value={form.telefon}
                onChange={(e) => setForm({ ...form, telefon: e.target.value })}
                placeholder={t("kullaniciTelefonOrnek")}
                required
              />
            </Field>
            <Field label={t("kullaniciAranabilir")} hint={t("kullaniciAranabilirIpucu")}>
              <label className="flex h-10 items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={form.aranabilir}
                  onChange={(e) => setForm({ ...form, aranabilir: e.target.checked })}
                />
                {t("kullaniciAranabilirOnay")}
              </label>
            </Field>
            <Field label={t("ortakRol")}>
              <select
                className={inputCls}
                value={form.role}
                onChange={(e) => setForm({ ...form, role: e.target.value as UserRole })}
              >
                {ROLES.map((r) => (
                  <option key={r.value} value={r.value}>
                    {t(r.anahtar)}
                  </option>
                ))}
              </select>
            </Field>
            <Field
              label={
                editingId
                  ? t("kullaniciYeniParola")
                  : t("kullaniciParolaOpsiyonel")
              }
              hint={
                editingId
                  ? t("kullaniciEnAz8")
                  : t("kullaniciParolaBosYeni")
              }
            >
              <input
                type="password"
                className={inputCls}
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                minLength={8}
                placeholder={
                  editingId ? t("kullaniciParolaBosDuzenle") : t("kullaniciParolaBosKisa")
                }
              />
            </Field>
          </div>
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
        <div className="overflow-x-auto" tabIndex={0}>
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-4 py-2.5 font-medium">{t("ortakAd")}</th>
                <th className="px-4 py-2.5 font-medium">{t("girisEposta")}</th>
                <th className="px-4 py-2.5 font-medium">{t("kullaniciAranabilir")}</th>
                <th className="px-4 py-2.5 font-medium">{t("ortakRol")}</th>
                <th className="px-4 py-2.5 font-medium">{t("ortakDurum")}</th>
                <th className="px-4 py-2.5 font-medium" />
              </tr>
            </thead>
            <tbody>
              {(data?.items ?? []).map((u) => (
                <tr key={u.id} className={`border-t border-slate-100 transition-colors hover:bg-slate-50 ${u.is_active ? "" : "opacity-60"}`}>
                  <td className="px-4 py-2.5">{u.ad}</td>
                  <td className="px-4 py-2.5 text-slate-600">{u.email}</td>
                  <td className="px-4 py-2.5 text-slate-600">
                    {u.aranabilir ? "Evet" : "—"}
                  </td>
                  <td className="px-4 py-2.5">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${ROLE_STYLE[u.role] ?? "bg-slate-100 text-slate-700"}`}
                    >
                      {rolAdi(t, u.role)}
                    </span>
                  </td>
                  <td className="px-4 py-2.5">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        u.is_active ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-slate-600"
                      }`}
                    >
                      {u.is_active ? t("ortakAktif") : t("ortakPasif")}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-right">
                    <div className="flex justify-end gap-2">
                      <button className={btnGhost} onClick={() => openEdit(u)}>
                        {t("ortakDuzenle")}
                      </button>
                      {u.is_active ? (
                        <button className={btnGhost} onClick={() => setActive(u, false)}>{t("ortakPasiflestir")}</button>
                      ) : (
                        <button className={btnGhost} onClick={() => setActive(u, true)}>{t("ortakAktiflestir")}</button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {data && data.items.length === 0 && (
                <tr>
                  <td colSpan={6}>
                    <EmptyState title={t("kullaniciYok")} description={t("kullaniciYokAlt")} />
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
