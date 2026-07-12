"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary, btnGhost } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type {
  Asset,
  AssetCheckoutList,
  AssetKategori,
  AssetList,
  UserListResponse,
} from "@/lib/types";

const LIMIT = 20;
const NFC_PLACEHOLDER = "04A1B2C3D4";
const KATEGORI: { value: AssetKategori; label: string }[] = [
  { value: "ekipman", label: "Ekipman" },
  { value: "arac", label: "Araç" },
  { value: "alet", label: "Alet" },
  { value: "diger", label: "Diğer" },
];
const DURUM_STYLE: Record<string, string> = {
  musait: "bg-emerald-100 text-emerald-800",
  zimmetli: "bg-amber-100 text-amber-800",
  bakimda: "bg-slate-200 text-slate-700",
};

interface FormState {
  ad: string;
  kategori: string;
  nfc_tag_uid: string;
  aciklama: string;
  aktif: boolean;
}
const EMPTY: FormState = { ad: "", kategori: "", nfc_tag_uid: "", aciklama: "", aktif: true };

export default function AssetsPage() {
  const [offset, setOffset] = useState(0);
  const [kategori, setKategori] = useState("");
  const [durum, setDurum] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (kategori) qs.set("kategori", kategori);
  if (durum) qs.set("durum", durum);
  const { data, error, isLoading, mutate } = useSWR<AssetList>(
    `/api/assets?${qs.toString()}`,
    jsonFetcher,
  );
  const { data: users } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [detail, setDetail] = useState<Asset | null>(null);

  const { data: history } = useSWR<AssetCheckoutList>(
    detail ? `/api/assets/${detail.id}/history?limit=50&offset=0` : null,
    jsonFetcher,
  );

  function userName(id: string): string {
    return users?.items.find((u) => u.id === id)?.ad ?? id.slice(0, 8);
  }

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(a: Asset) {
    setEditingId(a.id);
    setForm({
      ad: a.ad,
      kategori: a.kategori ?? "",
      nfc_tag_uid: a.nfc_tag_uid ?? "",
      aciklama: a.aciklama ?? "",
      aktif: a.aktif,
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
      kategori: form.kategori || null,
      nfc_tag_uid: form.nfc_tag_uid.trim() || null,
      aciklama: form.aciklama || null,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/assets/${editingId}`, "PATCH", body);
      else await apiSend("/api/assets", "POST", body);
      setOpen(false);
      mutate();
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(/nfc/i.test(m) ? "Bu NFC etiketi başka bir demirbaşta kullanılıyor." : m);
    } finally {
      setSaving(false);
    }
  }

  async function setActive(a: Asset, active: boolean) {
    try {
      await apiSend(`/api/assets/${a.id}`, "PATCH", { aktif: active });
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Güncellenemedi.");
    }
  }

  const openCheckout = (history?.items ?? []).find((h) => !h.birakma_zamani) ?? null;

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Demirbaş</h1>
        <button className={btnPrimary} onClick={openNew}>
          Yeni demirbaş
        </button>
      </div>

      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <Field label="Kategori">
            <select
              className={inputCls}
              value={kategori}
              onChange={(e) => {
                setKategori(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">Tümü</option>
              {KATEGORI.map((k) => (
                <option key={k.value} value={k.value}>
                  {k.label}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-44">
          <Field label="Durum">
            <select
              className={inputCls}
              value={durum}
              onChange={(e) => {
                setDurum(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">Tümü</option>
              <option value="musait">Müsait</option>
              <option value="zimmetli">Zimmetli</option>
              <option value="bakimda">Bakımda</option>
            </select>
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">{editingId ? "Demirbaş düzenle" : "Yeni demirbaş"}</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Ad">
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label="Kategori (opsiyonel)">
              <select
                className={inputCls}
                value={form.kategori}
                onChange={(e) => setForm({ ...form, kategori: e.target.value })}
              >
                <option value="">— yok —</option>
                {KATEGORI.map((k) => (
                  <option key={k.value} value={k.value}>
                    {k.label}
                  </option>
                ))}
              </select>
            </Field>
            <Field
              label="NFC etiket UID (opsiyonel)"
              hint="Büyük harf hex, ayraçsız. Örnek: 04A1B2C3D4 (mobil ile tutarlı)."
            >
              <input
                className={`${inputCls} font-mono uppercase`}
                value={form.nfc_tag_uid}
                placeholder={NFC_PLACEHOLDER}
                onChange={(e) => setForm({ ...form, nfc_tag_uid: e.target.value.toUpperCase() })}
              />
            </Field>
            <Field label="Açıklama (opsiyonel)">
              <input
                className={inputCls}
                value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
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
              <th className="px-3 py-2 font-medium">Kategori</th>
              <th className="px-3 py-2 font-medium">NFC</th>
              <th className="px-3 py-2 font-medium">Durum</th>
              <th className="px-3 py-2 font-medium">Aktif</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((a) => (
              <tr key={a.id} className={`border-t border-slate-100 ${a.aktif ? "" : "opacity-60"}`}>
                <td className="px-3 py-2">{a.ad}</td>
                <td className="px-3 py-2 text-slate-600">{a.kategori ?? "—"}</td>
                <td className="px-3 py-2 font-mono text-slate-600">{a.nfc_tag_uid ?? "—"}</td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${DURUM_STYLE[a.durum] ?? "bg-slate-100 text-slate-700"}`}
                  >
                    {a.durum}
                  </span>
                </td>
                <td className="px-3 py-2 text-slate-600">{a.aktif ? "evet" : "hayır"}</td>
                <td className="px-3 py-2 text-right">
                  <div className="flex justify-end gap-2">
                    <button
                      className={btnGhost}
                      onClick={() => setDetail(detail?.id === a.id ? null : a)}
                    >
                      {detail?.id === a.id ? "Kapat" : "Zimmet"}
                    </button>
                    <button className={btnGhost} onClick={() => openEdit(a)}>
                      Düzenle
                    </button>
                    <button className={btnGhost} onClick={() => setActive(a, !a.aktif)}>
                      {a.aktif ? "Pasifleştir" : "Aktifleştir"}
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={6}>
                  Demirbaş yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {detail && (
        <div className="space-y-3 rounded-xl border border-slate-300 bg-white p-5">
          <h2 className="text-lg font-medium">Zimmet — {detail.ad}</h2>
          <p className="text-sm">
            {openCheckout ? (
              <span className="text-amber-700">
                Şu an <strong>{userName(openCheckout.alan_user_id)}</strong> üzerinde (alındı:{" "}
                {formatDateTime(openCheckout.alma_zamani)})
              </span>
            ) : (
              <span className="text-emerald-700">Şu an kimsede değil (müsait).</span>
            )}
          </p>
          <p className="text-xs text-muted">
            Zimmet al/bırak sahada NFC ile mobilde yapılır; panel yalnızca görüntüler.
          </p>
          <div className="overflow-hidden rounded-lg border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-slate-500">
                <tr>
                  <th className="px-3 py-2 font-medium">Alan</th>
                  <th className="px-3 py-2 font-medium">Alma</th>
                  <th className="px-3 py-2 font-medium">Bırakma</th>
                </tr>
              </thead>
              <tbody>
                {(history?.items ?? []).map((h) => (
                  <tr key={h.id} className="border-t border-slate-100">
                    <td className="px-3 py-2">{userName(h.alan_user_id)}</td>
                    <td className="px-3 py-2 text-slate-600">{formatDateTime(h.alma_zamani)}</td>
                    <td className="px-3 py-2 text-slate-600">
                      {h.birakma_zamani ? formatDateTime(h.birakma_zamani) : "— açık —"}
                    </td>
                  </tr>
                ))}
                {history && history.items.length === 0 && (
                  <tr>
                    <td className="px-3 py-4 text-center text-muted" colSpan={3}>
                      Zimmet kaydı yok.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
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
