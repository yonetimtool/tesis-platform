"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  Dugme,
  Modal,
  Rozet,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { Checkpoint, CheckpointList } from "@/lib/types";
import { sayiCoz } from "@/lib/sayi";
import { useT } from "@/lib/i18n/kullan";

// Mobil POC ile tutarli: buyuk harf hex, ayracsiz.
const NFC_PLACEHOLDER = "04A1B2C3D4";
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;

interface FormState {
  ad: string;
  nfc_tag_uid: string;
  gps_lat: string;
  gps_lng: string;
  aktif: boolean;
}
const EMPTY: FormState = { ad: "", nfc_tag_uid: "", gps_lat: "", gps_lng: "", aktif: true };

// (P56) `numOrNull` KALDIRILDI: `Number("41,0082")` NaN doner ve NaN
// `null`a cevriliyordu — yani GPS'i Turkce yazimla giren kullanici
// koordinati SESSIZCE SILDIRIYORDU. `sayiCoz` bos ile gecersizi ayirir.

export default function CheckpointsPage() {
  const t = useT();
  const toast = useToast();
  // (P160) SAYFALAMA `VeriTablosu` durumuna gecti; `offset` ondan
  // TURETILIR ve sayfa basina kayit secimi bedava geldi.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const { data, error, isLoading, mutate } = useSWR<CheckpointList>(
    `/api/checkpoints?limit=${tabloDurumu.boy}&offset=${offset}`,
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
  function openEdit(c: Checkpoint) {
    setEditingId(c.id);
    setForm({
      ad: c.ad,
      nfc_tag_uid: c.nfc_tag_uid,
      gps_lat: c.gps_lat != null ? String(c.gps_lat) : "",
      gps_lng: c.gps_lng != null ? String(c.gps_lng) : "",
      aktif: c.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    const lat = sayiCoz(form.gps_lat);
    const lng = sayiCoz(form.gps_lng);
    if (lat.tur === "gecersiz" || lng.tur === "gecersiz") {
      setFormErr(t("noktaKonumGecersiz"));
      setSaving(false);
      return;
    }
    const body = {
      ad: form.ad,
      nfc_tag_uid: form.nfc_tag_uid.trim(),
      gps_lat: lat.tur === "sayi" ? lat.deger : null,
      gps_lng: lng.tur === "sayi" ? lng.deger : null,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/checkpoints/${editingId}`, "PATCH", body);
      else await apiSend("/api/checkpoints", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("noktaGuncellendi") : t("noktaOlusturuldu"));
    } catch (err) {
      const msg = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      // nfc cakismasi (409) -> anlamli mesaj
      setFormErr(/nfc/i.test(msg) ? t("noktaEtiketKullanimda") : msg);
    } finally {
      setSaving(false);
    }
  }

  async function remove(c: Checkpoint) {
    if (!window.confirm(t("ortakSilOnay", { ad: c.ad }))) return;
    try {
      await apiSend(`/api/checkpoints/${c.id}`, "DELETE");
      mutate();
      toast.success(t("noktaSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  const kolonlar: Kolon<Checkpoint>[] = useMemo(
    () => [
      { id: "ad", baslik: t("ortakAd"), hucre: (c) => c.ad, gizlenebilir: false },
      {
        id: "uid",
        baslik: t("noktaUid"),
        // TEK ARALIKLI: NFC UID'i gozle karsilastirilan bir dizedir;
        // oranti yazi tipinde 8 ile B ayirt edilemez.
        hucre: (c) => <span className="font-mono">{c.nfc_tag_uid}</span>,
      },
      {
        id: "gps",
        baslik: t("noktaGps"),
        // Dar ekranda GIZLI: koordinat cifti tek satira sigmaz ve
        // telefonda okunan bir sey degil.
        darEkrandaGizle: true,
        hucre: (c) =>
          c.gps_lat != null && c.gps_lng != null ? `${c.gps_lat}, ${c.gps_lng}` : "—",
      },
      {
        id: "durum",
        baslik: t("ortakDurum"),
        hucre: (c) => (
          <Rozet durum={c.aktif ? DURUM_OLUMLU : DURUM_NOTR}>
            {c.aktif ? t("ortakAktif") : t("ortakPasif")}
          </Rozet>
        ),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (c) => (
          <div className="flex justify-end gap-2">
            <Dugme boy="kucuk" onClick={() => openEdit(c)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme boy="kucuk" tur="tehlike" onClick={() => void remove(c)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukNfcNoktalari")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("noktaYeni")}
        </Dugme>
      </div>

      {/* FORM ARTIK MODALDA. Odak tuzagi, ESC ve kapanista odagin geri
          donmesi `Modal`dan geliyor. */}
      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("noktaDuzenle") : t("noktaYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="nokta-form" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="nokta-form" onSubmit={save} className="space-y-4">
          <AlanSarmal etiket={t("ortakAd")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            )}
          </AlanSarmal>

          <AlanSarmal etiket={t("noktaEtiketUid")} ipucu={t("noktaEtiketIpucu")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                className="font-mono uppercase"
                value={form.nfc_tag_uid}
                placeholder={NFC_PLACEHOLDER}
                onChange={(e) =>
                  setForm({ ...form, nfc_tag_uid: e.target.value.toUpperCase() })
                }
                required
              />
            )}
          </AlanSarmal>

          <div className="grid grid-cols-2 gap-4">
            <AlanSarmal etiket={t("noktaGpsEnlem")}>
              {(b) => (
                <Alan
                  {...b}
                  inputMode="decimal"
                  value={form.gps_lat}
                  placeholder="41.015137"
                  onChange={(e) => setForm({ ...form, gps_lat: e.target.value })}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("noktaGpsBoylam")}>
              {(b) => (
                <Alan
                  {...b}
                  inputMode="decimal"
                  value={form.gps_lng}
                  placeholder="28.979530"
                  onChange={(e) => setForm({ ...form, gps_lng: e.target.value })}
                />
              )}
            </AlanSarmal>
          </div>

          <label className="flex items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />
            {t("ortakAktif")}
          </label>

          {formErr && (
            <p
              role="alert"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {formErr}
            </p>
          )}
        </form>
      </Modal>

      <VeriTablosu<Checkpoint>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(c) => c.id}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("noktaYok")}
        bosAciklama={t("noktaYokAlt")}
        sunucuTarafli
        toplam={data?.meta.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />
    </div>
  );
}
