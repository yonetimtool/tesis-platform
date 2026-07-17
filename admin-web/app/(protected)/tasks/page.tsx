"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, btnDanger, panelCls, panelMotion } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { SAHA_ROLLERI, roleLabel } from "@/lib/roles";
import type {
  Task,
  TaskCategoryList,
  TaskCompletionList,
  TaskList,
  TaskTip,
  UserListResponse,
} from "@/lib/types";

const LIMIT = 20;
const TIPLER: { value: TaskTip; label: string }[] = [
  { value: "temizlik", label: "Temizlik" },
  { value: "kontrol", label: "Kontrol" },
  { value: "ilaclama", label: "İlaçlama" },
  { value: "bakim", label: "Bakım" },
  { value: "peyzaj", label: "Peyzaj" },
  { value: "diger", label: "Diğer" },
];
function tipLabel(v: string): string {
  return TIPLER.find((t) => t.value === v)?.label ?? v;
}

function toIso(local: string): string | null {
  if (!local) return null;
  const d = new Date(local);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}
function isoToLocalInput(iso?: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

interface FormState {
  tip: TaskTip;
  ad: string;
  aciklama: string;
  atanan_user_id: string;
  kategori_id: string;
  periyot_dakika: string;
  sonraki_planlanan: string;
  foto_zorunlu: boolean;
  aktif: boolean;
}
const EMPTY: FormState = {
  tip: "temizlik",
  ad: "",
  aciklama: "",
  atanan_user_id: "",
  kategori_id: "",
  periyot_dakika: "",
  sonraki_planlanan: "",
  foto_zorunlu: false,
  aktif: true,
};

export default function TasksPage() {
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const [tip, setTip] = useState("");
  const [aktif, setAktif] = useState("");
  const [atananFiltre, setAtananFiltre] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (tip) qs.set("tip", tip);
  if (aktif) qs.set("aktif", aktif);
  if (atananFiltre) qs.set("atanan_user_id", atananFiltre);
  const { data, error, isLoading, mutate } = useSWR<TaskList>(
    `/api/tasks?${qs.toString()}`,
    jsonFetcher,
  );
  // Atanan picker: saha personeli (security + tesis_gorevlisi — lib/roles SAHA_ROLLERI).
  const { data: users } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  // Kategori picker: yonetici-tanimli aktif kategoriler (A6).
  const { data: kategoriler } = useSWR<TaskCategoryList>("/api/task-categories", jsonFetcher);
  function kategoriAd(id?: string | null): string {
    if (!id) return "—";
    return kategoriler?.items.find((k) => k.id === id)?.ad ?? id.slice(0, 8);
  }
  const personel = (users?.items ?? []).filter(
    (u) => u.is_active && (SAHA_ROLLERI as string[]).includes(u.role),
  );
  function userName(id?: string | null): string {
    if (!id) return "—";
    return users?.items.find((u) => u.id === id)?.ad ?? id.slice(0, 8);
  }

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [detail, setDetail] = useState<Task | null>(null);

  const { data: completions } = useSWR<TaskCompletionList>(
    detail ? `/api/tasks/${detail.id}/completions?limit=50&offset=0` : null,
    jsonFetcher,
  );

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(t: Task) {
    setEditingId(t.id);
    setForm({
      tip: (t.tip as TaskTip) ?? "temizlik",
      ad: t.ad,
      aciklama: t.aciklama ?? "",
      atanan_user_id: t.atanan_user_id ?? "",
      kategori_id: t.kategori_id ?? "",
      periyot_dakika: t.periyot_dakika != null ? String(t.periyot_dakika) : "",
      sonraki_planlanan: isoToLocalInput(t.sonraki_planlanan),
      foto_zorunlu: t.foto_zorunlu,
      aktif: t.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    const per = form.periyot_dakika.trim();
    const body = {
      tip: form.tip,
      ad: form.ad,
      aciklama: form.aciklama || null,
      atanan_user_id: form.atanan_user_id || null,
      kategori_id: form.kategori_id || null,
      periyot_dakika: per ? Number(per) : null,
      sonraki_planlanan: toIso(form.sonraki_planlanan),
      foto_zorunlu: form.foto_zorunlu,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/tasks/${editingId}`, "PATCH", body);
      else await apiSend("/api/tasks", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? "Görev güncellendi." : "Görev oluşturuldu.");
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function remove(t: Task) {
    if (!window.confirm(`${t.ad} silinsin mi?`)) return;
    try {
      await apiSend(`/api/tasks/${t.id}`, "DELETE");
      if (detail?.id === t.id) setDetail(null);
      mutate();
      toast.success("Görev silindi.");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title="Görevler"
        action={
          <button className={btnPrimary} onClick={openNew}>
            Yeni görev
          </button>
        }
      />

      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <Field label="Tip">
            <select
              className={inputCls}
              value={tip}
              onChange={(e) => {
                setTip(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">Tümü</option>
              {TIPLER.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-44">
          <Field label="Durum">
            <select
              className={inputCls}
              value={aktif}
              onChange={(e) => {
                setAktif(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">Tümü</option>
              <option value="true">Aktif</option>
              <option value="false">Pasif</option>
            </select>
          </Field>
        </div>
        <div className="w-56">
          <Field label="Atanan">
            <select
              className={inputCls}
              value={atananFiltre}
              onChange={(e) => {
                setAtananFiltre(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">Tümü</option>
              {personel.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.ad} ({roleLabel(u.role)})
                </option>
              ))}
            </select>
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? "Görev düzenle" : "Yeni görev"}</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Tip">
              <select
                className={inputCls}
                value={form.tip}
                onChange={(e) => setForm({ ...form, tip: e.target.value as TaskTip })}
              >
                {TIPLER.map((t) => (
                  <option key={t.value} value={t.value}>
                    {t.label}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Başlık">
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label="Açıklama (opsiyonel)">
              <input
                className={inputCls}
                value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
              />
            </Field>
            <Field label="Atanan personel (opsiyonel)">
              <select
                className={inputCls}
                value={form.atanan_user_id}
                onChange={(e) => setForm({ ...form, atanan_user_id: e.target.value })}
              >
                <option value="">— yok —</option>
                {personel.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.ad} ({roleLabel(u.role)})
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Kategori (opsiyonel)" hint="Yönetici tanımlı kategoriler">
              <select
                className={inputCls}
                value={form.kategori_id}
                onChange={(e) => setForm({ ...form, kategori_id: e.target.value })}
              >
                <option value="">— yok —</option>
                {(kategoriler?.items ?? []).map((k) => (
                  <option key={k.id} value={k.id}>
                    {k.ad}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Periyot dakika (opsiyonel)" hint="Periyodik/peyzaj görevi için">
              <input
                type="number"
                min={1}
                className={inputCls}
                value={form.periyot_dakika}
                onChange={(e) => setForm({ ...form, periyot_dakika: e.target.value })}
              />
            </Field>
            <Field label="Sonraki planlanan (opsiyonel)" hint="Peyzaj takvimi; yerel saat girilir">
              <input
                type="datetime-local"
                className={inputCls}
                value={form.sonraki_planlanan}
                onChange={(e) => setForm({ ...form, sonraki_planlanan: e.target.value })}
              />
            </Field>
          </div>
          <div className="flex gap-6">
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={form.foto_zorunlu}
                onChange={(e) => setForm({ ...form, foto_zorunlu: e.target.checked })}
              />
              Foto kanıtı zorunlu
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={form.aktif}
                onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
              />
              Aktif
            </label>
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
        </motion.form>
      )}

      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-500">
            <tr>
              <th className="px-4 py-2.5 font-medium">Başlık</th>
              <th className="px-4 py-2.5 font-medium">Tip</th>
              <th className="px-4 py-2.5 font-medium">Kategori</th>
              <th className="px-4 py-2.5 font-medium">Atanan</th>
              <th className="px-4 py-2.5 font-medium">Sonraki</th>
              <th className="px-4 py-2.5 font-medium">Aktif</th>
              <th className="px-4 py-2.5 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((t) => (
              <tr key={t.id} className={`border-t border-slate-100 transition-colors hover:bg-slate-50 ${t.aktif ? "" : "opacity-60"}`}>
                <td className="px-4 py-2.5">
                  {t.ad}
                  {t.foto_zorunlu && (
                    <span className="ml-2 rounded-full bg-sky-100 px-2 py-0.5 text-xs text-sky-800">
                      foto zorunlu
                    </span>
                  )}
                </td>
                <td className="px-4 py-2.5 text-slate-600">{tipLabel(t.tip)}</td>
                <td className="px-4 py-2.5 text-slate-600">{kategoriAd(t.kategori_id)}</td>
                <td className="px-4 py-2.5 text-slate-600">{userName(t.atanan_user_id)}</td>
                <td className="px-4 py-2.5 text-slate-600">
                  {t.sonraki_planlanan ? formatDateTime(t.sonraki_planlanan) : "—"}
                </td>
                <td className="px-4 py-2.5 text-slate-600">{t.aktif ? "evet" : "hayır"}</td>
                <td className="px-4 py-2.5 text-right">
                  <div className="flex justify-end gap-2">
                    <button
                      className={btnGhost}
                      onClick={() => setDetail(detail?.id === t.id ? null : t)}
                    >
                      {detail?.id === t.id ? "Kapat" : "Kayıtlar"}
                    </button>
                    <button className={btnGhost} onClick={() => openEdit(t)}>
                      Düzenle
                    </button>
                    <button className={btnDanger} onClick={() => remove(t)}>
                      Sil
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td colSpan={7}>
                  <EmptyState title="Görev yok" description="Filtreyi değiştirin ya da yeni bir görev ekleyin." />
                </td>
              </tr>
            )}
          </tbody>
          </table>
        </div>
      </div>

      {detail && (
        <motion.div {...panelMotion} className={`space-y-3 ${panelCls}`}>
          <h2 className="text-lg font-medium">Tamamlanma kayıtları — {detail.ad}</h2>
          <div className="overflow-hidden rounded-lg border border-slate-200">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Zaman</th>
                  <th className="px-4 py-2.5 font-medium">Tamamlayan</th>
                  <th className="px-4 py-2.5 font-medium">Foto</th>
                  <th className="px-4 py-2.5 font-medium">Not</th>
                </tr>
              </thead>
              <tbody>
                {(completions?.items ?? []).map((c) => (
                  <tr key={c.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                    <td className="px-4 py-2.5 text-slate-600">{formatDateTime(c.tamamlanma_zamani)}</td>
                    <td className="px-4 py-2.5">{userName(c.tamamlayan_user_id)}</td>
                    <td className="px-4 py-2.5">
                      {c.foto_key ? (
                        <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">
                          foto var
                        </span>
                      ) : (
                        <span className="text-muted">yok</span>
                      )}
                    </td>
                    <td className="px-4 py-2.5 text-slate-600">{c.notlar ?? "—"}</td>
                  </tr>
                ))}
                {completions && completions.items.length === 0 && (
                  <tr>
                    <td colSpan={4}>
                      <EmptyState title="Kayıt yok" />
                    </td>
                  </tr>
                )}
              </tbody>
              </table>
            </div>
          </div>
        </motion.div>
      )}

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
