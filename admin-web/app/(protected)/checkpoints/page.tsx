"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  Kart,
  Sekmeler,
  Modal,
  Rozet,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
  useOnay,
} from "@/components/ui";
import { RotaSahnesiYukleyici } from "@/components/3d/sahne-yukleyici";
import { KonumHaritasiYukleyici } from "@/components/harita/harita-yukleyici";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type {
  AlarmGrubu,
  Checkpoint,
  CheckpointList,
  DashboardLive,
  OkutmaRaporu,
  TenantSettings,
} from "@/lib/types";
import { sayiCoz } from "@/lib/sayi";
import { useT } from "@/lib/i18n/kullan";
import { alarmHaritasi, noktaDurumu } from "@/lib/rota-durumu";
import { esikSonucu, mesafeMetre } from "@/lib/mesafe";

// Mobil POC ile tutarli: buyuk harf hex, ayracsiz.
const NFC_PLACEHOLDER = "04A1B2C3D4";
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;

/** Nokta durumu -> rozet rengi ve sozluk anahtari (sahneyle ayni aile). */
const ROZET_DURUMU = {
  okutuldu: "olumlu",
  gecikti: "uyari",
  atlandi: "kritik",
  bekliyor: "notr",
} as const;
const DURUM_ANAHTARI = {
  okutuldu: "rotaDurumOkutuldu",
  gecikti: "rotaDurumGecikti",
  atlandi: "rotaDurumAtlandi",
  bekliyor: "rotaDurumBekliyor",
} as const;

/** Nokta durumu -> harita isaretci tonu (anlamli grafik esigi 3.0). */
const HARITA_TONU = {
  okutuldu: "var(--yz-success-edge)",
  gecikti: "var(--yz-warning-edge)",
  atlandi: "var(--yz-danger-edge)",
  bekliyor: "var(--yz-text-3)",
} as const;

const GORUNUM_HARITA = "harita" as const;
const GORUNUM_AKIS = "akis" as const;
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const KONUM_VAR = "var" as const;
/** Ayar ucu gelene kadar kullanilan deger — semadaki DEFAULT ile ayni. */
const VARSAYILAN_ESIK = 50;
/** Esik sonucu -> isaretci tonu. */
const ESIK_TONU = {
  icinde: "var(--yz-accent)",
  disinda: "var(--yz-danger-edge)",
  belirsiz: "var(--yz-text-3)",
} as const;
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;

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
  const { data, error, isLoading, mutate } = useSWR<CheckpointList>(
    `/api/checkpoints?limit=${tabloDurumu.boy}&offset=${offset}`,
    jsonFetcher,
  );

  // (P160 / Asama 5) BUGUNKU OKUTMA DURUMU. Iki kaynak da bu sayfanin
  // ASIL listesiyle ayni yetkiye sahip (admin + yonetici); ek bir kapi
  // gerekmiyor.
  const { data: okutmalar } = useSWR<OkutmaRaporu>("/api/scans", jsonFetcher);
  const { data: pano } = useSWR<DashboardLive>("/api/dashboard/live", jsonFetcher);
  // (P160) ESIK TESIS AYARIDIR. Sunucu her zaman bir deger doner
  // (`NOT NULL DEFAULT 50`); `?? 50` yalniz ayar ucu HENUZ gelmemisken
  // ilk cizim icin — sabit bir kural degil.
  const { data: tesis } = useSWR<TenantSettings>("/api/tenant/settings", jsonFetcher);
  const esik = tesis?.okutma_mesafe_esigi_m ?? VARSAYILAN_ESIK;

  const [gorunum, setGorunum] = useState<string>(GORUNUM_HARITA);
  // OKUTMA KATMANI VARSAYILAN ACIK: kullanicinin haritayi actigi an
  // sordugu sey "bugun nerede okutuldu" — katmani kapali baslatmak o
  // yaniti bir tik arkasina saklamakti.
  const [okutmaKatmani, setOkutmaKatmani] = useState(true);
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
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("ortakSilOnay", { ad: c.ad }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/checkpoints/${c.id}`, "DELETE");
      mutate();
      toast.success(t("noktaSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  const okutulanIdler = useMemo(
    () => new Set((okutmalar?.items ?? []).map((o) => o.checkpoint_id)),
    [okutmalar],
  );
  const alarmlar = useMemo(
    () => alarmHaritasi((pano?.alarm_gruplari ?? []) as AlarmGrubu[]),
    [pano],
  );
  /** Sahnenin noktalari — YALNIZ AKTIF noktalar.
   *
   *  Pasif nokta okutulmasi BEKLENMEZ; onu "bekliyor" diye cizmek,
   *  olmayan bir eksigi varmis gibi gostermekti. */
  const sahneNoktalari = useMemo(
    () =>
      (data?.items ?? [])
        .filter((c) => c.aktif)
        .map((c, i) => ({
          id: c.id,
          ad: c.ad,
          sira: i,
          durum: noktaDurumu(c.id, { okutulanIdler, alarmGruplari: [] }, alarmlar),
        })),
    [data, okutulanIdler, alarmlar],
  );

  /**
   * HARITANIN NOKTALARI — YALNIZ koordinati OLANLAR.
   *
   * `gps_lat/gps_lng` opsiyoneldir. Koordinati olmayan noktayi haritaya
   * bir yere koymak (site merkezine, listenin ortasina...) onu OLMADIGI
   * YERDE gostermekti; girilmeyen sayilir ve sayisi ekranda yazilir.
   */
  const konumNoktalari = useMemo(
    () =>
      (data?.items ?? [])
        .filter((c) => c.aktif && c.gps_lat != null && c.gps_lng != null)
        .map((c) => {
          const d = noktaDurumu(c.id, { okutulanIdler, alarmGruplari: [] }, alarmlar);
          return {
            id: c.id,
            ad: c.ad,
            lat: Number(c.gps_lat),
            lon: Number(c.gps_lng),
            ton: HARITA_TONU[d],
            ipucu: `${c.ad} · ${t(DURUM_ANAHTARI[d])}`,
          };
        }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [data, okutulanIdler, alarmlar, t],
  );
  const koordinatsiz = sahneNoktalari.length - konumNoktalari.length;

  /**
   * OKUTMA KATMANI — YALNIZ konumu OLAN okutmalar.
   *
   * `konum_durumu` bes degerlidir ve DORDU "konum yok" demektir
   * (`izin_yok`, `servis_kapali`, `zaman_asimi`, `bilinmiyor`). Bunlari
   * haritaya bir yere koymak imkansiz; sayilari ayrica yaziliyor.
   *
   * UZAKLIK BIR OLCUMDUR, BIR YARGI DEGIL: yanina GPS dogrulugu da
   * yaziliyor cunku ±50 m dogrulukla olculmus 30 m'lik bir sapma hicbir
   * sey soylemez. Sistemde bir "uzak" esigi YOK ve panelde
   * uydurulmuyor (bkz. `lib/mesafe.ts`).
   */
  const okutmaIsaretleri = useMemo(() => {
    const noktaKonumu = new Map(
      (data?.items ?? [])
        .filter((c) => c.gps_lat != null && c.gps_lng != null)
        .map((c) => [c.id, { lat: Number(c.gps_lat), lon: Number(c.gps_lng) }]),
    );
    return (okutmalar?.items ?? [])
      .filter((o) => o.konum_durumu === KONUM_VAR && o.gps_lat != null && o.gps_lng != null)
      .map((o) => {
        const lat = Number(o.gps_lat);
        const lon = Number(o.gps_lng);
        const nokta = noktaKonumu.get(o.checkpoint_id);
        // AYRAC bir CUMLE DEGIL: sozluge girseydi yedi dilde birebir
        // ayni durur ve "cevrilmemis" taramasini hakli olarak tetiklerdi.
        const bilgi = `${o.guard_ad} · ${formatDateTime(o.okutma_zamani)}`;
        if (!nokta) return { id: o.id, lat, lon, ipucu: bilgi };
        const m = mesafeMetre(lat, lon, nokta.lat, nokta.lon);
        const uzaklik =
          o.gps_dogruluk_m != null
            ? t("haritaOkutmaUzaklik", {
                mesafe: m,
                dogruluk: Math.round(o.gps_dogruluk_m),
              })
            : t("haritaOkutmaUzaklikSade", { mesafe: m });
        // ESIK SONUCU: icinde / disinda / BELIRSIZ. Ucuncusu zorunlu —
        // GPS hatasi esikten buyukse kiyas KARAR VEREMEZ ve olcum
        // hatasini ihlal diye raporlamak birini yanlis suclamakti.
        const sonuc = esikSonucu(m, esik, o.gps_dogruluk_m);
        const not =
          sonuc === "disinda"
            ? ` · ${t("haritaEsikDisi", { esik })}`
            : sonuc === "belirsiz"
              ? ` · ${t("haritaOlcumBelirsiz")}`
              : "";
        return {
          id: o.id,
          lat,
          lon,
          ipucu: `${bilgi} · ${uzaklik}${not}`,
          ton: ESIK_TONU[sonuc],
          nokta,
          sonuc,
        };
      });
  }, [data, okutmalar, t, esik]);
  /** Konumu OLMAYAN okutma sayisi — sunucunun P34 kavramiyla ayni. */
  const konumsuzOkutma =
    (okutmalar?.items ?? []).length - okutmaIsaretleri.length;
  /** Esigin DISINDA olcumlenen okutma sayisi (belirsizler HARIC). */
  const esikDisi = okutmaIsaretleri.filter((o) => o.sonuc === "disinda").length;

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
        id: "okutma",
        baslik: t("rotaSahneNoktaBaslik"),
        hucre: (c) => {
          if (!c.aktif) return "—";
          const d = noktaDurumu(c.id, { okutulanIdler, alarmGruplari: [] }, alarmlar);
          return <Rozet durum={ROZET_DURUMU[d]}>{t(DURUM_ANAHTARI[d])}</Rozet>;
        },
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
    [t, okutulanIdler, alarmlar],
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

      {/* SPATIAL GORUNUMLER — iki sekme, ikisi de AYNI durumu tasiyor.
          Ayrimlari NE IDDIA ETTIKLERI:
            * HARITA  gercek koordinati OLAN noktalari cizer (cografi),
            * AKIS    TUM aktif noktalari cizer (koordinatsiz olanlar da),
                      ama aralarinda sira YOK ve cizgi cizilmez.
          Ikisi de tabloyu ikame etmez: durum her satirda METIN olarak
          zaten yaziyor. */}
      {sahneNoktalari.length > 0 && (
        <Sekmeler
          aktifId={gorunum}
          onDegis={setGorunum}
          sekmeler={[
            {
              id: GORUNUM_HARITA,
              baslik: t("haritaGorunumKonum"),
              icerik:
                konumNoktalari.length > 0 ? (
                  <div className="space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      {/* KATMAN ANAHTARI — secililik `aria-pressed` ile
                          bildirilir, renkle degil. */}
                      <Dugme
                        boy="kucuk"
                        tur={okutmaKatmani ? TUR_BIRINCIL : TUR_IKINCIL}
                        aria-pressed={okutmaKatmani}
                        onClick={() => setOkutmaKatmani((a) => !a)}
                      >
                        {t("haritaOkutmaKatmani")}
                      </Dugme>
                      {okutmaKatmani && okutmaIsaretleri.length === 0 && (
                        <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                          {t("haritaOkutmaYok")}
                        </span>
                      )}
                    </div>
                    <KonumHaritasiYukleyici
                      noktalar={konumNoktalari}
                      okutmalar={okutmaKatmani ? okutmaIsaretleri : []}
                    />
                    {/* SESSIZ EKSIK YOK: konumu olmayan okutma sayilir. */}
                    {/* ESIK DISI SAYISI — renk tek tasiyici degil. */}
                    {okutmaKatmani && esikDisi > 0 && (
                      <p
                        role="status"
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-danger-ink)" }}
                      >
                        {t("haritaEsikDisiSayi", { sayi: esikDisi, esik })}
                      </p>
                    )}
                    {okutmaKatmani && konumsuzOkutma > 0 && (
                      <p
                        role="status"
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}
                      >
                        {t("haritaOkutmaKonumsuz", { sayi: konumsuzOkutma })}
                      </p>
                    )}
                    {/* SESSIZ EKSIK YOK: haritada olmayan nokta sayilir. */}
                    {koordinatsiz > 0 && (
                      <p
                        role="status"
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}
                      >
                        {t("haritaKoordinatsizNokta", { sayi: koordinatsiz })}
                      </p>
                    )}
                  </div>
                ) : (
                  // HICBIRI KOORDINATSIZSA BOS DUNYA HARITASI CIZILMEZ:
                  // ekrani doldurur ama hicbir sey soylemez. Yerine ne
                  // yapilacagi yazilir.
                  <Kart>
                    <BosDurum
                      baslik={t("haritaKoordinatYok")}
                      aciklama={t("haritaKoordinatYokAlt")}
                    />
                  </Kart>
                ),
            },
            {
              id: GORUNUM_AKIS,
              baslik: t("haritaGorunumAkis"),
              icerik: (
                <div className="space-y-1">
                  <RotaSahnesiYukleyici noktalar={sahneNoktalari} rotaCizgisi={false} />
                  <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                    {t("rotaSahneNotSirasiz")}
                  </p>
                </div>
              ),
            },
          ]}
        />
      )}

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
        // (P165) `data?.meta.total` IDI ve `?? 0` yedegi ALDATICIYDI:
        // govde gelmis ama `meta` yoksa okuma CAKIYORDU (yedek hic
        // calismiyordu). Depodaki 16 sayfanin hepsinde ayni kalip vardi.
        toplam={data?.meta?.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />
      {diyalog}
    </div>
  );
}
