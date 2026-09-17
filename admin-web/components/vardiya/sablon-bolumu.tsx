"use client";

import { useState } from "react";
import useSWR from "swr";
import { useMemo } from "react";

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
  useOnay,
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

/** (P232 §A) Kadro secicide kullanilan personel ozeti. */
export type Personel = { id: string; ad: string; role: string };

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

export function SablonBolumu({ personel }: { personel: Personel[] }) {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
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
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("ortakSilOnay", { ad: s.ad }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/shifts/${s.id}`, "DELETE");
      mutate();
      toast.success(t("vardiyaSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  const overnight = form.baslangic_saat > form.bitis_saat;

  // (P232 §A) VARSAYILAN KADRO — web'de EKSIK OLAN YARISI.
  //
  // Arka ucta `PUT /shifts/{id}/assignments` VARDI ve mobil kullaniyordu;
  // web'de karsiligi YOKTU. Sonucu sasirticiydi: "Haftayi doldur"
  // kadroyu okuyup haftayi dolduruyor ama kadro yalniz telefondan
  // girilebildigi icin web kullanicisinda HICBIR SEY yapmiyordu.
  const [kadroShift, setKadroShift] = useState<Shift | null>(null);
  const [kadroSecili, setKadroSecili] = useState<string[]>([]);
  const [kadroKaydediyor, setKadroKaydediyor] = useState(false);

  async function kadroAc(v: Shift) {
    setKadroShift(v);
    // Mevcut kadro `Shift.personel` ile geliyor (sunucu `_shift_out`
    // dolduruyor); ayri bir istek atmak gereksiz bir gidis-donus olurdu.
    setKadroSecili((v.personel ?? []).map((p) => p.user_id));
  }

  async function kadroKaydet() {
    if (!kadroShift) return;
    setKadroKaydediyor(true);
    try {
      await apiSend(`/api/shifts/${kadroShift.id}/assignments`, "PUT", {
        user_ids: kadroSecili,
      });
      await mutate();
      setKadroShift(null);
      toast.success(t("vardiyaKadroGuncellendi"));
    } catch {
      toast.error(t("ortakHataOlustu"));
    } finally {
      setKadroKaydediyor(false);
    }
  }

  // UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`): tarayici ucludaki
  // her dizgeyi cevrilmemis metin adayi sayar. Baslik JSX DISINDA kurulur.
  const kadroBasligi = kadroShift
    ? `${t("vardiyaKadro")} — ${kadroShift.ad}`
    : t("vardiyaKadro");

  const kolonlar: Kolon<Shift>[] = useMemo(
    () => [
      { id: "ad", kartRolu: "baslik", baslik: t("ortakAd"), hucre: (v) => v.ad, gizlenebilir: false },
      {
        id: "saat", kartRolu: "ozet",
        baslik: t("ortakSaat"),
        sayisal: true,
        hucre: (v) => `${v.baslangic_saat} – ${v.bitis_saat}`,
      },
      {
        id: "gun", kartRolu: "ozet",
        baslik: t("vardiyaGunTipi"),
        hucre: (v) => gunTipiAdi(t, v.gun_tipi),
      },
      {
        id: "kadro",
        baslik: t("vardiyaKadro"),
        hucre: (v) =>
          (v.personel ?? []).length === 0
            ? t("vardiyaKadroYok")
            : (v.personel ?? []).map((p) => p.ad).join(", "),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (v) => (
          <div className="flex justify-end gap-2">
            <Dugme
              boy="kucuk"
              data-test={`vardiya-kadro-${v.id}`}
              onClick={() => void kadroAc(v)}
            >
              {t("vardiyaKadro")}
            </Dugme>
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
        {/* (P232 §A) ARTIK SAYFA BASLIGI DEGIL, BOLUM BASLIGI: `h1`
            sayfada tektir ve o `/vardiya-plani`nin basligidir. */}
        {/* (P239 §2) BASLIK + ACIKLAMA, ve dugme ARTIK "Yeni sablon".

            OLCULEN KUSUR: bu dugme ile sayfanin ustundeki "Vardiya
            ekle" dugmesi AYNI sozluk anahtarini (`vardiyaYeni`)
            kullaniyordu — ekranda iki ayri yerde AYNI YAZI vardi ve
            FARKLI modallar aciyorlardi. Kullanici sablon modalini
            "vardiya olusturma" sanip takvim/kisi ariyordu.

            Sablon bir TANIM (ad + saat + gun tipi); cizelgeye kisi
            eklemek ustteki birlesik modaldan (takvim -> kisi -> onizleme,
            P235 §1) yapilir. Aciklama satiri bunu SOYLER — dugme adini
            degistirmek tek basina "peki bu ne zaman kullanilir"
            sorusunu yanitlamazdi. */}
        <div>
          <h2 style={{ fontSize: "var(--yz-fs-h2)", color: "var(--yz-text)" }}>
            {t("vardiyaSablonlari")}
          </h2>
          <p
            data-test="vardiya-sablon-aciklama"
            className="mt-1"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("vardiyaSablonAciklama", { dugme: t("vardiyaYeni") })}
          </p>
        </div>
        <Dugme
          tur="birincil"
          boy="kucuk"
          data-test="vardiya-sablon-yeni"
          onClick={openNew}
        >
          {t("vardiyaSablonYeni")}
        </Dugme>
      </div>

      {/* Liste cekilemezse BOS TABLO degil, sebep + "Tekrar dene".
          Yukleme durumu artik `VeriTablosu`nun ISKELETI. */}

      {/* FORM ARTIK MODALDA (brief). Odak tuzagi, ESC ve kapanista
          odagin geri donmesi `Modal`dan geliyor. */}
      {/* (P232 §A) KADRO MODALI. Ayri bir modal cunku iki KARAR ayri:
          "bu vardiya ne zaman" (sablon) ile "normalde kim calisir"
          (kadro). Tek forma sikistirmak, sablon adini degistirmek
          isteyen kullaniciya kadro listesini de gostermek olurdu. */}
      <Modal
        acik={kadroShift !== null}
        onKapat={() => setKadroShift(null)}
        baslik={kadroBasligi}
        eylemler={
          <>
            <Dugme
              tur="sessiz"
              onClick={() => setKadroShift(null)}
              disabled={kadroKaydediyor}
            >
              {t("ortakIptal")}
            </Dugme>
            <Dugme
              tur="birincil"
              data-test="vardiya-kadro-kaydet"
              yukleniyor={kadroKaydediyor}
              onClick={() => void kadroKaydet()}
            >
              {kadroKaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("vardiyaKadroAciklama")}
        </p>
        <div className="mt-3 space-y-2">
          {personel.length === 0 && <p>{t("vardiyaKadroYok")}</p>}
          {personel.map((p) => (
            <label key={p.id} className="flex items-center gap-2">
              <input
                type="checkbox"
                // ETIKET ACIKCA BAGLANIR: `<label>` sarmasi tarayicida
                // calisir ama depo taramasi ACIK ad istiyor ve hakli —
                // ekran okuyucu bazi kuruluslarda sarmali etiketi
                // baglamiyor.
                aria-label={p.ad}
                data-test={`vardiya-kadro-kisi-${p.id}`}
                checked={kadroSecili.includes(p.id)}
                onChange={(e) =>
                  setKadroSecili((onceki) =>
                    e.target.checked
                      ? [...onceki, p.id]
                      : onceki.filter((x) => x !== p.id),
                  )
                }
              />
              <span>{p.ad}</span>
            </label>
          ))}
        </div>
      </Modal>

      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("vardiyaSablonDuzenle") : t("vardiyaSablonYeni")}
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
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
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
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("vardiyaYok")}
        bosAciklama={t("vardiyaYokAlt")}
        sunucuTarafli
        toplam={data?.meta?.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />
      {diyalog}
    </div>
  );
}
