"use client";

import { useRef, useState } from "react";
import useSWR from "swr";

import { Foto } from "@/components/Foto";
import { Pager } from "@/components/form";
import {
  Modal,
  Alan,
  BosDurum,
  CokSatir,
  Kart,
  AlanSarmal,
  Dugme,
  HataDurumu,
  IskeletMetin,
  useOnay,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Announcement, AnnouncementList, PresignTicket } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

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
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
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
      if (!put.ok) throw new Error(t("yuklemeBasarisiz", { kod: put.status }));
      setPhoto((p) => ({ ...p, uploading: false, fotoKey: ticket.foto_key }));
    } catch (err) {
      setPhoto((p) => ({
        ...p,
        uploading: false,
        error: err instanceof Error ? err.message : t("duyuruGorselYuklenemedi"),
      }));
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (photo.uploading) {
      setFormErr(t("duyuruGorselBekleyin"));
      return;
    }
    if (photo.previewUrl && !photo.fotoKey) {
      setFormErr(t("duyuruGorselTekrarSecin"));
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
      toast.success(t("duyuruGuncellendi"));
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  async function remove(a: Announcement) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("ortakSilOnay", { ad: a.baslik }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/announcements/${a.id}`, "DELETE");
      mutate();
      toast.success(t("duyuruSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kabukDuyurular")}
      </h1>

      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("duyuruPanelNotu")}
      </p>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={3} />}

      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={t("duyuruDuzenle")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme type="submit" form="duyuru-form" tur="birincil" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="duyuru-form" onSubmit={save} className="space-y-4">
          <AlanSarmal etiket={t("ortakBaslik")} ipucu={t("duyuruEnFazla200")}>
  {(b) => (
    <Alan {...b} value={form.baslik}
              onChange={(e) => setForm({ ...form, baslik: e.target.value })}
              maxLength={200}
              required />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("duyuruMetni")} ipucu={t("duyuruEnFazla5000")}>
            {(b) => (
              <CokSatir
                {...b}
                rows={6}
                value={form.govde}
                onChange={(e) => setForm({ ...form, govde: e.target.value })}
                maxLength={5000}
                required
              />
            )}
          </AlanSarmal>
          {/* GORSEL ALANI bir `AlanSarmal` DEGIL: icinde tek bir denetim
              yok (onizleme + dosya secici + kaldir dugmesi). Dosya
              secicinin kendi etiketi var. */}
          <div className="space-y-2">
            <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
              {t("duyuruGorselOpsiyonel")}
            </span>
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {t("duyuruGorselHerkes")}
            </p>
            <div className="space-y-2">
              {/* Onizleme: yeni secim > mevcut gorsel (kaldirilmadiysa) */}
              {(photo.previewUrl || (editing?.foto_url && !photo.removed && !photo.fotoKey)) && (
                <div
                  className="overflow-hidden"
                  style={{
                    borderRadius: "var(--yz-radius-btn)",
                    border: "1px solid var(--yz-border)",
                  }}
                >
                  <Foto
                    src={photo.previewUrl ?? editing?.foto_url ?? ""}
                    alt={t("duyuruGorseli")}
                    className="h-40 w-full object-cover"
                  />
                </div>
              )}
              {photo.uploading && <IskeletMetin satir={3} />}
              {photo.error && <HataDurumu mesaj={photo.error} />}
              <div className="flex items-center gap-2">
                <input
                  ref={fileRef}
                  aria-label={t("duyuruGorselOpsiyonel")}
                  type="file"
                  accept="image/*"
                  onChange={pickPhoto}
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                  disabled={photo.uploading || saving}
                />
                {(photo.fotoKey || (editing?.foto_key && !photo.removed)) && (
                  <Dugme
                    type="button"
                    boy="kucuk"
                    disabled={photo.uploading || saving}
                    onClick={() => {
                      resetPhoto();
                      setPhoto((p) => ({ ...p, removed: true }));
                    }}
                  >
                    {t("duyuruGorseliKaldir")}
                  </Dugme>
                )}
              </div>
            </div>
          </div>
          {formErr && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {formErr}
            </p>
          )}
        </form>
      </Modal>

      <ul className="space-y-3">
        {(data?.items ?? []).map((a) => (
          <li key={a.id}>
            <Kart>
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-0 flex-1">
                <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{a.baslik}</h3>
                <p className="mt-1 whitespace-pre-wrap" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>{a.govde}</p>
                {a.foto_url && (
                  // Presigned GET URL kisa omurlu — liste her yenilendiginde taze gelir.
                  <a href={a.foto_url} target="_blank" rel="noreferrer" className="mt-2 block w-fit">
                    <div
                      className="overflow-hidden"
                      style={{
                        borderRadius: "var(--yz-radius-btn)",
                        border: "1px solid var(--yz-border)",
                      }}
                    >
                      <Foto
                        src={a.foto_url}
                        alt={t("gorselAlt", { baslik: a.baslik })}
                        className="h-40 w-full object-cover"
                      />
                    </div>
                  </a>
                )}
                <p className="mt-2" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
{/* (P162 §7.3) DUYURAN ADI YERINE ROL.
                  Duyuru TESIS YONETIMI adina yapilir; hangi calisanin
                  yazdigi sakin icin bilgi degildir ve kisiyi gereksizce
                  one cikarir. Kayit `olusturan_user_id` ile denetimde
                  DURUYOR — gizlenen sey veri degil, GORUNUM. */}
                  {t("duyuranRol")} · {formatDateTime(a.created_at)}
                  {a.updated_at !== a.created_at && ` ${t("duyuruDuzenlendiEki")}`}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <Dugme boy="kucuk" onClick={() => openEdit(a)}>
                  {t("ortakDuzenle")}
                </Dugme>
                <Dugme tur="tehlike" boy="kucuk" onClick={() => remove(a)}>
                  {t("ortakSil")}
                </Dugme>
              </div>
            </div>
            </Kart>
          </li>
        ))}
        {data && data.items.length === 0 && !error && (
          <Kart>
            <BosDurum baslik={t("duyuruYok")} aciklama={t("duyuruYokAlt")} />
          </Kart>
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
      {diyalog}
    </div>
  );
}
