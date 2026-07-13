"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary, btnGhost } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { ROLE_OPTIONS as ROLES, ROLE_STYLE, roleLabel } from "@/lib/roles";
import type { UserDetail, UserListResponse, UserRole, UserRow } from "@/lib/types";

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
        // PATCH: parola yalniz doluysa gonderilir (bossa degismez)
        const body: Record<string, unknown> = {
          ad: form.ad,
          email: form.email,
          telefon: form.telefon || null,
          aranabilir: form.aranabilir,
          role: form.role,
        };
        if (form.password) body.password = form.password;
        await apiSend(`/api/users/${editingId}`, "PATCH", body);
      } else {
        await apiSend("/api/users", "POST", {
          ad: form.ad,
          email: form.email,
          telefon: form.telefon || null,
          aranabilir: form.aranabilir,
          role: form.role,
          password: form.password,
        });
      }
      setOpen(false);
      mutate();
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(/email|e-posta|zaten kayitli|conflict/i.test(m) ? "Bu e-posta zaten kayıtlı." : m);
    } finally {
      setSaving(false);
    }
  }

  async function setActive(u: UserRow, active: boolean) {
    try {
      await apiSend(`/api/users/${u.id}`, "PATCH", { is_active: active });
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Güncellenemedi.");
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Kullanıcılar</h1>
        <button className={btnPrimary} onClick={openNew}>
          Yeni kullanıcı
        </button>
      </div>

      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <Field label="Rol">
            <select className={inputCls} value={role} onChange={(e) => resetFilters({ role: e.target.value })}>
              <option value="">Tümü</option>
              {ROLES.map((r) => (
                <option key={r.value} value={r.value}>
                  {r.label}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-44">
          <Field label="Durum">
            <select className={inputCls} value={aktif} onChange={(e) => resetFilters({ aktif: e.target.value })}>
              <option value="">Tümü</option>
              <option value="true">Aktif</option>
              <option value="false">Pasif</option>
            </select>
          </Field>
        </div>
        <div className="grow">
          <Field label="Arama (ad / email)">
            <input
              className={inputCls}
              value={q}
              onChange={(e) => resetFilters({ q: e.target.value })}
              placeholder="ad veya email"
            />
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">{editingId ? "Kullanıcı düzenle" : "Yeni kullanıcı"}</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Ad">
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label="E-posta" hint={editingId ? "Değiştirmek isterseniz güncelleyin" : undefined}>
              <input
                type="email"
                className={inputCls}
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                required
              />
            </Field>
            <Field
              label="Telefon (opsiyonel)"
              hint="Rol-bazlı arama için; yalnızca rıza açıkken paylaşılır"
            >
              <input
                className={inputCls}
                value={form.telefon}
                onChange={(e) => setForm({ ...form, telefon: e.target.value })}
              />
            </Field>
            <Field label="Aranabilir (rıza)" hint="Numara aramaya izin verildi mi?">
              <label className="flex h-10 items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={form.aranabilir}
                  onChange={(e) => setForm({ ...form, aranabilir: e.target.checked })}
                />
                Telefonla aranmaya izin ver
              </label>
            </Field>
            <Field label="Rol">
              <select
                className={inputCls}
                value={form.role}
                onChange={(e) => setForm({ ...form, role: e.target.value as UserRole })}
              >
                {ROLES.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </Field>
            <Field
              label={editingId ? "Yeni parola (opsiyonel)" : "Parola"}
              hint="En az 8 karakter"
            >
              <input
                type="password"
                className={inputCls}
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                minLength={8}
                required={!editingId}
                placeholder={editingId ? "Boş bırakırsanız değişmez" : ""}
              />
            </Field>
          </div>
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
              <th className="px-3 py-2 font-medium">E-posta</th>
              <th className="px-3 py-2 font-medium">Aranabilir</th>
              <th className="px-3 py-2 font-medium">Rol</th>
              <th className="px-3 py-2 font-medium">Durum</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((u) => (
              <tr key={u.id} className={`border-t border-slate-100 ${u.is_active ? "" : "opacity-60"}`}>
                <td className="px-3 py-2">{u.ad}</td>
                <td className="px-3 py-2 text-slate-600">{u.email}</td>
                <td className="px-3 py-2 text-slate-600">
                  {u.aranabilir ? "Evet" : "—"}
                </td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${ROLE_STYLE[u.role] ?? "bg-slate-100 text-slate-700"}`}
                  >
                    {roleLabel(u.role)}
                  </span>
                </td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      u.is_active ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-slate-600"
                    }`}
                  >
                    {u.is_active ? "aktif" : "pasif"}
                  </span>
                </td>
                <td className="px-3 py-2 text-right">
                  <div className="flex justify-end gap-2">
                    <button className={btnGhost} onClick={() => openEdit(u)}>
                      Düzenle
                    </button>
                    {u.is_active ? (
                      <button className={btnGhost} onClick={() => setActive(u, false)}>
                        Pasifleştir
                      </button>
                    ) : (
                      <button className={btnGhost} onClick={() => setActive(u, true)}>
                        Aktifleştir
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={6}>
                  Kullanıcı yok.
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
