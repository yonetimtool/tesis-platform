"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";
import { useMemo } from "react";

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
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Modal,
  Secim,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
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
  // (P160) SAYFALAMA `VeriTablosu` durumuna gecti; `offset` ondan
  // TURETILIR ve sayfa basina kayit secimi bedava geldi.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const { data, error, isLoading, mutate } = useSWR<ShiftList>(
    `/api/shifts?limit=${tabloDurumu.boy}&offset=${offset}`,
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
      setFormErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  async function remove(s: Shift) {
    if (!window.confirm(t("ortakSilOnay", { ad: s.ad }))) return;
    try {
      await apiSend(`/api/shifts/${s.id}`, "DELETE");
      mutate();
      toast.success(t("vardiyaSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  const overnight = form.baslangic_saat > form.bitis_saat;

  const kolonlar: Kolon<Shift>[] = useMemo(
    () => [
      { id: "ad", baslik: t("ortakAd"), hucre: (v) => v.ad, gizlenebilir: false },
      {
        id: "saat",
        baslik: t("ortakSaat"),
        sayisal: true,
        hucre: (v) => `${v.baslangic_saat} – ${v.bitis_saat}`,
      },
      {
        id: "gun",
        baslik: t("vardiyaGunTipi"),
        hucre: (v) => gunTipiAdi(t, v.gun_tipi),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (v) => (
          <div className="flex justify-end gap-2">
            <Dugme boy="kucuk" onClick={() => openEdit(v)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme boy="kucuk" tur="tehlike" onClick={() => void remove(v)}>
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
          {t("kabukVardiyalar")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("vardiyaYeni")}
        </Dugme>
      </div>

      {/* Liste cekilemezse BOS TABLO degil, sebep + "Tekrar dene".
          Yukleme durumu artik `VeriTablosu`nun ISKELETI. */}
      {error && <HataDurumu mesaj={error.message} onTekrar={() => void mutate()} />}

      {/* FORM ARTIK MODALDA (brief). Odak tuzagi, ESC ve kapanista
          odagin geri donmesi `Modal`dan geliyor. */}
      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("vardiyaDuzenle") : t("vardiyaYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="vardiya-form" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="vardiya-form" onSubmit={save} className="space-y-4">
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
          <div className="grid grid-cols-2 gap-4">
            <AlanSarmal etiket={t("ortakBaslangic")} ipucu={t("ortakSaat24")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  type="time"
                  value={form.baslangic_saat}
                  onChange={(e) => setForm({ ...form, baslangic_saat: e.target.value })}
                  required
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("ortakBitis")} ipucu={t("ortakSaat24")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  type="time"
                  value={form.bitis_saat}
                  onChange={(e) => setForm({ ...form, bitis_saat: e.target.value })}
                  required
                />
              )}
            </AlanSarmal>
          </div>
          {overnight && (
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
              {t("vardiyaGeceNotu")}
            </p>
          )}
          <AlanSarmal etiket={t("vardiyaGunTipi")}>
            {(b) => (
              <Secim
                {...b}
                value={form.gun_tipi}
                onChange={(e) => setForm({ ...form, gun_tipi: e.target.value as GunTipi })}
              >
              {GUN_TIPI_OPTS.map((o) => (
                <option key={o.value} value={o.value}>
                  {t(o.anahtar)}
                </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
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

      <VeriTablosu<Shift>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(v) => v.id}
        yukleniyor={isLoading && !data}
        bosBaslik={t("vardiyaYok")}
        bosAciklama={t("vardiyaYokAlt")}
        sunucuTarafli
        toplam={data?.meta.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />
    </div>
  );
}
