"use client";

import { useRef, useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary, btnGhost, btnDanger } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Announcement, AnnouncementList, PresignTicket } from "@/lib/types";

const LIMIT = 20;

interface FormState {
  baslik: string;
  govde: string;
}
const EMPTY: FormState = { baslik: "", govde: "" };

/**
 * Opsiyonel gorselin form icindeki yasam dongusu (mobil akisla ayni desen):
 * dosya secilir secilmez presign + dogrudan MinIO'ya PUT; kaydet'te yalniz
 * `foto_key` gonderilir. `removed` duzenlemede mevcut gorselin acikca
 * kaldirilmasini isaretler (PATCH foto_key=null).
 */
interface PhotoState {
  uploading: boolean;
  error: string | null;
  /// Yeni yuklenen obje anahtari (create/PATCH'te gonderilir).
  fotoKey: string | null;
  /// Onizleme icin: yeni secilen dosyanin object URL'i.
  previewUrl: string | null;
  removed: boolean;
}
const PHOTO_EMPTY: PhotoState = {
  uploading: false,
  error: null,
  fotoKey: null,
  previewUrl: null,
  removed: false,
};

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
  const [editing, setEditing] = useState<Announcement | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [photo, setPhoto] = useState<PhotoState>(PHOTO_EMPTY);
  const fileRef = useRef<HTMLInputElement>(null);

  function resetPhoto() {
    setPhoto((p) => {
      if (p.previewUrl) URL.revokeObjectURL(p.previewUrl);
      return PHOTO_EMPTY;
    });
    if (fileRef.current) fileRef.current.value = "";
  }

  function openEdit(a: Announcement) {
    setEditingId(a.id);
    setEditing(a);
    setForm({ baslik: a.baslik, govde: a.govde });
    setFormErr(null);
    resetPhoto();
    setOpen(true);
  }

  // Dosya secilir secilmez yukle: presign -> dogrudan MinIO'ya PUT.
  // Kaydet'e kadar yalniz foto_key bekletilir (mobil akisla ayni).
  async function pickPhoto(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setPhoto((p) => {
      if (p.previewUrl) URL.revokeObjectURL(p.previewUrl);
      return {
        ...PHOTO_EMPTY,
        uploading: true,
        previewUrl: URL.createObjectURL(file),
      };
    });
    try {
      const ticket = await apiSend<PresignTicket>("/api/uploads/presign", "POST", {
        content_type: file.type || "image/jpeg",
        dosya_adi: file.name,
      });
      const put = await fetch(ticket.upload_url, {
        method: "PUT",
        headers: { "Content-Type": file.type || "image/jpeg" },
        body: file,
      });
      if (!put.ok) throw new Error(`Yükleme başarısız (HTTP ${put.status}).`);
      setPhoto((p) => ({ ...p, uploading: false, fotoKey: ticket.foto_key }));
    } catch (err) {
      setPhoto((p) => ({
        ...p,
        uploading: false,
        error: err instanceof Error ? err.message : "Görsel yüklenemedi.",
      }));
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (photo.uploading) {
      setFormErr("Görsel henüz yükleniyor — bitmesini bekleyin veya kaldırın.");
      return;
    }
    if (photo.previewUrl && !photo.fotoKey) {
      setFormErr("Görsel yüklenemedi. Tekrar seçin veya kaldırın.");
      return;
    }
    setSaving(true);
    setFormErr(null);
    // foto_key yalniz degistiginde govdeye girer: yeni yukleme -> anahtar;
    // "kaldir" -> null; dokunulmadi -> alan yok (backend mevcut gorseli korur).
    const body: Record<string, unknown> = { ...form };
    if (photo.fotoKey) body.foto_key = photo.fotoKey;
    else if (photo.removed) body.foto_key = null;
    try {
      // Panelde yalniz DUZENLEME var: olusturma site yoneticisine ait
      // (mobil; auth.md §4 — POST /announcements admin'e 403).
      await apiSend(`/api/announcements/${editingId}`, "PATCH", body);
      setOpen(false);
      resetPhoto();
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
      <h1 className="text-2xl font-semibold">Duyurular</h1>

      <p className="text-sm text-muted">
        Duyuruyu SİTE YÖNETİCİSİ mobil uygulamadan oluşturur; panel yalnız
        düzenleme/silme (moderasyon) içindir. Duyurular tüm rollere görünür;
        yayınlandığında tesisin kayıtlı tüm cihazlarına bildirim denenir.
      </p>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">Duyuru düzenle</h2>
          <Field label="Başlık" hint="En fazla 200 karakter">
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
          <Field label="Görsel (opsiyonel)" hint="Okuyan herkes duyuruda görür">
            <div className="space-y-2">
              {/* Onizleme: yeni secim > mevcut gorsel (kaldirilmadiysa) */}
              {(photo.previewUrl || (editing?.foto_url && !photo.removed && !photo.fotoKey)) && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={photo.previewUrl ?? editing?.foto_url ?? ""}
                  alt="Duyuru görseli"
                  className="max-h-40 rounded-lg border border-slate-200 object-cover"
                />
              )}
              {photo.uploading && <p className="text-sm text-muted">Yükleniyor...</p>}
              {photo.error && <ErrorBox message={photo.error} />}
              <div className="flex items-center gap-2">
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/*"
                  onChange={pickPhoto}
                  className="text-sm"
                  disabled={photo.uploading || saving}
                />
                {(photo.fotoKey || (editing?.foto_key && !photo.removed)) && (
                  <button
                    type="button"
                    className={btnGhost}
                    disabled={photo.uploading || saving}
                    onClick={() => {
                      resetPhoto();
                      setPhoto((p) => ({ ...p, removed: true }));
                    }}
                  >
                    Görseli kaldır
                  </button>
                )}
              </div>
            </div>
          </Field>
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

      <ul className="space-y-3">
        {(data?.items ?? []).map((a) => (
          <li key={a.id} className="rounded-xl border border-slate-200 bg-white p-5">
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0">
                <h3 className="font-medium">{a.baslik}</h3>
                <p className="mt-1 whitespace-pre-wrap text-sm text-slate-600">{a.govde}</p>
                {a.foto_url && (
                  // Presigned GET URL kisa omurlu — liste her yenilendiginde taze gelir.
                  <a href={a.foto_url} target="_blank" rel="noreferrer" className="mt-2 block w-fit">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={a.foto_url}
                      alt={`${a.baslik} görseli`}
                      className="max-h-40 rounded-lg border border-slate-200 object-cover"
                    />
                  </a>
                )}
                <p className="mt-2 text-xs text-muted">
                  {a.olusturan_ad ?? "—"} · {formatDateTime(a.created_at)}
                  {a.updated_at !== a.created_at && " · düzenlendi"}
                </p>
              </div>
              <div className="flex shrink-0 gap-2">
                <button className={btnGhost} onClick={() => openEdit(a)}>
                  Düzenle
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
            Henüz duyuru yok.
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
