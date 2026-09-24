"use client";

import { useRef, useState } from "react";
import useSWR from "swr";

import { Foto } from "@/components/Foto";
import { Alan, AlanSarmal, BosDurum, CokSatir, Dugme, HataDurumu, IskeletMetin, Kart, Modal, Pager, Rozet, Secim, useOnay } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Announcement, AnnouncementList, BlockList, PresignTicket } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";
import { rolAdi } from "@/lib/roles";

const LIMIT = 20;

/**
 * (E2E 2026-09, BILDIRIM-12) HEDEF KITLE — anketteki desen + BLOK.
 * Roller arka uctaki `ANKET_HEDEF_ROLLER` ile ayni. Bos secim = HERKES.
 * Sakin tipi ve blok YALNIZ sakinlere uygulanir; roller secilmis ve
 * `resident` aralarinda degilse ikisi de gizlenir VE temizlenir (gizli
 * bir suzgec govdede kalmasin — anketteki P237 §4 olcumu).
 */
const HEDEF_ROLLER = [
  "resident",
  "security",
  "guvenlik_amiri",
  "tesis_gorevlisi",
  "yonetici",
  "admin",
] as const;
const TIP_MALIK = "malik" as const;
const TIP_KIRACI = "kiraci" as const;

function sakinSuzgeciAnlamli(roller: string[]): boolean {
  return roller.length === 0 || roller.includes("resident");
}

/** Hedef kitlenin tek satirlik ozeti; hedefsiz duyuruda `null` (rozet yok). */
function hedefOzeti(t: ReturnType<typeof useT>, a: Announcement): string | null {
  const parcalar: string[] = [];
  const roller = a.hedef_roller ?? [];
  const bloklar = a.hedef_bloklar ?? [];
  if (roller.length > 0) parcalar.push(roller.map((r) => rolAdi(t, r)).join(", "));
  if (bloklar.length > 0) parcalar.push(t("duyuruHedefBlok", { bloklar: bloklar.join(", ") }));
  if (a.hedef_sakin_tipi === TIP_MALIK) parcalar.push(t("anketMalik"));
  if (a.hedef_sakin_tipi === TIP_KIRACI) parcalar.push(t("anketKiraci"));
  return parcalar.length > 0 ? parcalar.join(" · ") : null;
}

interface FormState {
  baslik: string;
  govde: string;
  hedefRoller: string[];
  hedefSakinTipi: string;
  hedefBloklar: string[];
}
const EMPTY: FormState = {
  baslik: "",
  govde: "",
  hedefRoller: [],
  hedefSakinTipi: "",
  hedefBloklar: [],
};

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

// Duyuru olusturmada backend HEDEF KITLENIN aktif cihazlarina push dener
// (olusturan haric, BILDIRIM-12) — panelden gonderilen duyuru mobil
// kullanicilara da duser.
export default function AnnouncementsPage() {
  const t = useT();
  const { data: bloklar } = useSWR<BlockList>("/api/blocks", jsonFetcher);
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const { data, error, isLoading, mutate } = useSWR<AnnouncementList>(
    `/api/announcements?limit=${LIMIT}&offset=${offset}`,
    jsonFetcher,
  );

  // (P162 §7.2) Gorsele tiklayinca acilan DETAY modali.

  const [detay, setDetay] = useState<Announcement | null>(null);

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
    // Hedef DUZENLENEMEZ (sunucu PATCH'te tasimaz); formda da gosterilmez.
    setForm({ ...EMPTY, baslik: a.baslik, govde: a.govde });
    setFormErr(null);
    resetPhoto();
    setOpen(true);
  }

  // (P190 §3) WEB'DEN OLUSTURMA: "yalniz mobil" kisiti kaldirildi. Ayni
  // form/modal kullanilir; backend POST zaten yonetici+admin'e acik.
  function openNew() {
    setEditingId(null);
    setEditing(null);
    setForm(EMPTY);
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
    const body: Record<string, unknown> = { baslik: form.baslik, govde: form.govde };
    if (!editingId) {
      const sakinli = sakinSuzgeciAnlamli(form.hedefRoller);
      body.hedef_roller = form.hedefRoller;
      body.hedef_sakin_tipi = sakinli ? form.hedefSakinTipi || null : null;
      body.hedef_bloklar = sakinli ? form.hedefBloklar : [];
    }
    if (photo.fotoKey) body.foto_key = photo.fotoKey;
    else if (photo.removed) body.foto_key = null;
    try {
      // (P190 §3) OLUSTURMA + DUZENLEME ayni formdan: editingId varsa PATCH,
      // yoksa POST. Iki yuzey (web+mobil) ayni tabloyu kullanir.
      if (editingId) {
        await apiSend(`/api/announcements/${editingId}`, "PATCH", body);
      } else {
        await apiSend("/api/announcements", "POST", body);
      }
      setOpen(false);
      resetPhoto();
      mutate();
      toast.success(editingId ? t("duyuruGuncellendi") : t("duyuruOlusturuldu"));
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
      <div className="flex items-center justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukDuyurular")}
        </h1>
        {/* (P190 §3) Web'den olusturma acildi. */}
        <Dugme tur="birincil" onClick={openNew}>
          {t("duyuruYeni")}
        </Dugme>
      </div>

      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("duyuruPanelNotu")}
      </p>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={3} />}

      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("duyuruDuzenle") : t("duyuruYeni")}
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
          {/* (E2E 2026-09, BILDIRIM-12) HEDEF KITLE — yalniz olusturmada.
              "Herkes" diye ayri kutu yok (anketteki gerekce: digerleriyle
              celisirdi); bos secim herkestir. */}
          {!editingId && (
            <fieldset className="space-y-2" data-test="duyuru-hedef">
              <legend style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                {t("anketHedefKitle")}
              </legend>
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("anketHedefHerkes")} · {t("duyuruHedefNotu")}
              </p>
              <div className="flex flex-wrap gap-3">
                {HEDEF_ROLLER.map((r) => (
                  <label key={r} className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      data-test={`duyuru-hedef-${r}`}
                      checked={form.hedefRoller.includes(r)}
                      onChange={(e) =>
                        setForm((f) => {
                          const hedefRoller = e.target.checked
                            ? [...f.hedefRoller, r]
                            : f.hedefRoller.filter((x) => x !== r);
                          const sakinli = sakinSuzgeciAnlamli(hedefRoller);
                          return {
                            ...f,
                            hedefRoller,
                            hedefSakinTipi: sakinli ? f.hedefSakinTipi : "",
                            hedefBloklar: sakinli ? f.hedefBloklar : [],
                          };
                        })
                      }
                    />
                    {rolAdi(t, r)}
                  </label>
                ))}
              </div>
              {sakinSuzgeciAnlamli(form.hedefRoller) && (
                <>
                  <AlanSarmal etiket={t("anketHedefSakinTipi")}>
                    {(b) => (
                      <Secim
                        {...b}
                        data-test="duyuru-sakin-tipi"
                        value={form.hedefSakinTipi}
                        onChange={(e) => setForm({ ...form, hedefSakinTipi: e.target.value })}
                      >
                        <option value="">{t("ortakSecimYok")}</option>
                        <option value={TIP_MALIK}>{t("anketMalik")}</option>
                        <option value={TIP_KIRACI}>{t("anketKiraci")}</option>
                      </Secim>
                    )}
                  </AlanSarmal>
                  {(bloklar?.items ?? []).length > 0 && (
                    <div className="space-y-1">
                      <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
                        {t("duyuruHedefBloklar")}
                      </span>
                      <div className="flex flex-wrap gap-3">
                        {(bloklar?.items ?? []).map((bl) => (
                          <label key={bl.id} className="flex items-center gap-2 text-sm">
                            <input
                              type="checkbox"
                              data-test={`duyuru-blok-${bl.ad}`}
                              checked={form.hedefBloklar.includes(bl.ad)}
                              onChange={(e) =>
                                setForm((f) => ({
                                  ...f,
                                  hedefBloklar: e.target.checked
                                    ? [...f.hedefBloklar, bl.ad]
                                    : f.hedefBloklar.filter((x) => x !== bl.ad),
                                }))
                              }
                            />
                            {bl.ad}
                          </label>
                        ))}
                      </div>
                    </div>
                  )}
                </>
              )}
            </fieldset>
          )}
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

      {/* DETAY: baslik + TAM aciklama + gorsel BIRLIKTE. */}
      <Modal
        acik={detay !== null}
        onKapat={() => setDetay(null)}
        baslik={detay?.baslik ?? ""}
        genislikSinifi="max-w-2xl"
      >
        <div className="space-y-3">
          {detay?.foto_url && (
            <Foto
              src={detay.foto_url}
              alt={t("gorselAlt", { baslik: detay.baslik })}
              className="max-h-[55vh] w-full object-contain"
            />
          )}
          <p
            className="whitespace-pre-wrap"
            style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
          >
            {detay?.govde}
          </p>
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("duyuranRol")} · {detay ? formatDateTime(detay.created_at) : ""}
          </p>
        </div>
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
                  // (P162 §7.2) GORSELE TIKLAYINCA DETAY MODALI acilir —
                  // ham dosya yeni sekmede DEGIL.
                  //
                  // OLCULEN KUSUR: fotograf `<a href={foto_url}>` idi;
                  // tiklayinca kullanici uygulamadan CIKIP bir depolama
                  // URL'sine dusuyordu. Orada duyurunun basligi da
                  // aciklamasi da YOKTU — yalnizca bir resim. Yaziya
                  // tiklayinca gorulen bilginin tamami, resme tiklayinca
                  // KAYBOLUYORDU.
                  //
                  // Presigned GET URL kisa omurlu — liste her
                  // yenilendiginde taze gelir.
                  <button
                    type="button"
                    onClick={() => setDetay(a)}
                    aria-label={t("duyuruDetayAc", { baslik: a.baslik })}
                    className="mt-2 block w-fit"
                  >
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
                  </button>
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
                {/* (E2E 2026-09, BILDIRIM-12) Hedefli duyuruda KIME gittigi
                    yonetim listesinde gorunur; hedefsizde rozet yok. */}
                {hedefOzeti(t, a) && (
                  <div className="mt-2" data-test="duyuru-hedef-rozet">
                    <Rozet durum="bilgi">
                      {t("duyuruHedefEtiket")}: {hedefOzeti(t, a)}
                    </Rozet>
                  </div>
                )}
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
            {/* (E2E 2026-09) Eski metin "yalniz mobilden olusturulur"
                diyordu; P190'dan beri web'de de olusturuluyor ve ustteki
                dugme bunu yapiyor. Bos durum da ayni cikisi verir. */}
            <BosDurum
              baslik={t("duyuruYok")}
              aciklama={t("duyuruYokWeb")}
              eylem={
                <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
                  {t("duyuruYeni")}
                </Dugme>
              }
            />
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
