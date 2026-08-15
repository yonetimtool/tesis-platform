"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { UnitDetail } from "@/components/UnitDetail";
import { BagimlilikUyarisi } from "@/components/BagimlilikUyarisi";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { aralikCoz } from "@/lib/aralik";
import {
  Modal,
  Secim,
  Kart,
  AlanSarmal,
  Alan,
  Dugme,
  HataDurumu,
  Rozet,
  VeriTablosu,
  type Kolon,
  type SayfaBoyu,
  type TabloDurumu,
  useOnay,
} from "@/components/ui";
import { sayiBicimi, sayiCoz, tamsayiCoz } from "@/lib/sayi";
import type { Unit, UnitList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

/** Sunucudaki `_BLOK_PATTERN` ile AYNI — ikisi ayrisirsa test duser. */
const BLOK_KALIBI = /^[A-Za-z0-9]+$/;

const LIMIT = 20;

interface FormState {
  no: string;
  blok: string;
  kat: string;
  sira: string;
  metrekare: string;
  aktif: boolean;
}
const EMPTY: FormState = { no: "", blok: "", kat: "", sira: "", metrekare: "", aktif: true };

// (P55) `numOrNull` KALDIRILDI. `Number("120,5")` NaN doner ve eski
// surum bunu `null`a cevirip sunucuya "alani temizle" diye gonderiyordu:
// metrekareyi TURKCE YAZIMLA giren kullanici alani SESSIZCE SILDIRIYORDU.
// `sayiCoz` bos girdi ile gecersiz girdiyi AYIRIR; gecersizde istek hic
// atilmaz ve neden soylenir.

// (P56) `intOrNull` KALDIRILDI — metrekareyle ayni gerekce: gecersiz
// girdi `null` donuyordu ve `null` "alani temizle" demekti.

/** Sayfa boyu artik kullanici secimli; bu yalniz ILK degerdir. */
const ILK_BOY: SayfaBoyu = 25;
/** Sutun basligi — cevrilmeyen SI birimi. */
const BIRIM_M2 = "m²";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;

export default function UnitsPage() {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  // (P160) SAYFALAMA `VeriTablosu`nun durumuna gecti; `offset` ondan
  // TURETILIR. Boylece sayfa basina kayit secimi (10/25/50/100) bedava
  // geldi — eskiden sabit `LIMIT`ti.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: ILK_BOY,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const setOffset = (v: number) =>
    setTabloDurumu((d) => ({ ...d, sayfa: Math.floor(v / d.boy) + 1 }));
  const [blok, setBlok] = useState("");
  const blokQs = blok ? `&blok=${encodeURIComponent(blok)}` : "";
  // (P154 / Asama 7.4) Blok listesi YALNIZ bagimlilik uyarisi icin
  // cekiliyor: daire olusturmada `blok` ZORUNLU (canli-site kurali) ve
  // blok yoksa kullanici formu doldurup takiliyor. Liste kucuk ve
  // sayfa basina bir kez.
  const { data: bloklar } = useSWR<{ items: unknown[] }>("/api/blocks", jsonFetcher);

  // ---------------- (P154 / Asama 5) TOPLU ISLEMLER ----------------------
  // Secim EKRANDAKI listeye gore yapilir; aralik ifadesi de oyle cozulur
  // (bkz. `lib/aralik.ts` — sunucuya KESINLESMIS kimlikler gider).
  const [secili, setSecili] = useState<string[]>([]);
  const [aralikIfade, setAralikIfade] = useState("");
  const [topluAcik, setTopluAcik] = useState(false);
  const [topluHata, setTopluHata] = useState<string | null>(null);
  const [topluAktif, setTopluAktif] = useState("");
  const [katSilKat, setKatSilKat] = useState("");
  const [topluTip, setTopluTip] = useState("");

  // (P154 / Asama 5) TOPLU DAIRE OLUSTURMA — uc ZATEN VARDI
  // (`POST /units/bulk`), eksik olan yalnizca web yuzeyiydi (mobilde
  // caliyordu). Ikinci bir uc yazilmadi.
  const [oAcik, setOAcik] = useState(false);
  const [oBlok, setOBlok] = useState("");
  const [oKat, setOKat] = useState("3");
  const [oDaire, setODaire] = useState("4");
  const [oBaslangicNo, setOBaslangicNo] = useState("1");
  const [oBaslangicKat, setOBaslangicKat] = useState("1");
  const [oTip, setOTip] = useState("");
  const [oHata, setOHata] = useState<string | null>(null);

  const { data: tipler } = useSWR<{ items: { id: string; ad: string }[] }>(
    "/api/tanimlar/unit-tipleri?limit=100",
    jsonFetcher,
  );

  async function topluOlustur(): Promise<void> {
    setOHata(null);
    // (P162 §4.1) BLOK ADI SUNUCUDA `^[A-Za-z0-9]+$` — bosluk, tire ve
    // Turkce harf KABUL EDILMIYOR.
    //
    // KOK NEDEN BUYDU: kullanici "A Blok" ya da "B-1" yaziyor, sunucu 422
    // doneriyor ve ekranda yalnizca "Bir hata olustu" beliriyordu.
    // Kisitlama SUNUCUDA KALIYOR ve bu dogru: daire numarasi `{blok}-{n}`
    // olarak kuruluyor ve `_UNIT_NO_PATTERN` bosluk kabul etmiyor — yani
    // bosluklu bir blok, gecersiz bir daire numarasi uretirdi. Sozlesme
    // degistirilmedi (kilitli kural); ISTEMCI ARTIK SEBEBI SOYLUYOR.
    if (!BLOK_KALIBI.test(oBlok.trim())) {
      setOHata(t("daireBlokKalibi"));
      return;
    }
    const sayilar = {
      kat_sayisi: tamsayiCoz(oKat),
      kat_basi_daire: tamsayiCoz(oDaire),
      baslangic_no: tamsayiCoz(oBaslangicNo),
      baslangic_kat: tamsayiCoz(oBaslangicKat),
    };
    const gecersiz = Object.entries(sayilar).find(([, v]) => v.tur !== "sayi");
    if (!oBlok.trim() || gecersiz) {
      setOHata(t("daireTopluOlusturAlanlar"));
      return;
    }
    try {
      await apiSend("/api/units/bulk", "POST", {
        blok: oBlok.trim(),
        kat_sayisi: (sayilar.kat_sayisi as { deger: number }).deger,
        kat_basi_daire: (sayilar.kat_basi_daire as { deger: number }).deger,
        baslangic_no: (sayilar.baslangic_no as { deger: number }).deger,
        baslangic_kat: (sayilar.baslangic_kat as { deger: number }).deger,
        unit_tip_id: oTip || null,
      });
      setOAcik(false);
      await mutate();
      toast.success(t("daireTopluOlusturuldu"));
    } catch (e) {
      // ALAN AYRINTISI VARSA ONU GOSTER: "Istek govdesi gecersiz" tek
      // basina kullaniciya hicbir sey soylemiyordu.
      setOHata(alanliHataMetni(e, t("ortakHataOlustu")));
    }
  }

  function araligiUygula(): void {
    setTopluHata(null);
    const sonuc = aralikCoz(aralikIfade, (data?.items ?? []).map(
      (u) => ({ id: u.id, no: u.no }),
    ));
    setSecili(sonuc.idler);
    if (sonuc.bulunamayan.length > 0) {
      // SESSIZCE DUSMEZ: "12 daire sectim" deyip 9'unu islemek en kotu
      // sonuctur.
      setTopluHata(t("daireAralikBulunamayan", {
        parca: sonuc.bulunamayan.join(", "),
      }));
    }
  }

  async function topluGuncelle(): Promise<void> {
    setTopluHata(null);
    if (secili.length === 0) return;
    // EN AZ BIR ALAN: bos bir istek kullaniciya "yaptim" deyip hicbir sey
    // yapmamak olurdu (sunucu da 422 doner).
    if (topluAktif === "" && topluTip === "") return;
    const govde: Record<string, unknown> = { unit_ids: secili };
    if (topluAktif !== "") govde.aktif = topluAktif === "1";
    if (topluTip !== "") govde.unit_tip_id = topluTip;
    try {
      await apiSend("/api/units/toplu", "PATCH", govde);
      setTopluAcik(false);
      setSecili([]);
      await mutate();
      toast.success(t("daireTopluGuncellendi"));
    } catch (e) {
      setTopluHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function katSil(): Promise<void> {
    setTopluHata(null);
    const kat = tamsayiCoz(katSilKat);
    if (kat.tur !== "sayi" || !blok) {
      setTopluHata(t("daireKatSilAlanlar"));
      return;
    }
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("daireKatSilOnay", { kat: kat.deger, blok }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend("/api/units/kat-sil", "POST", {
        blok, kat: kat.deger, cascade: true,
      });
      await mutate();
      toast.success(t("daireKatSilindi"));
    } catch (e) {
      setTopluHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }
  const { data, error, isLoading, mutate } = useSWR<UnitList>(
    `/api/units?limit=${tabloDurumu.boy}&offset=${offset}${blokQs}`,
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [detail, setDetail] = useState<Unit | null>(null);

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(u: Unit) {
    setEditingId(u.id);
    setForm({
      no: u.no,
      blok: u.blok ?? "",
      kat: u.kat != null ? String(u.kat) : "",
      sira: u.sira != null ? String(u.sira) : "",
      // ON-DOLGU GOSTERILEN BICIMDE: `String(120.5)` "120.5" verirdi ve
      // kullanici duzenlemeye acinca tablodakinden FARKLI bir metin
      // gorurdu (P49/P50'nin ayni bulgusu).
      metrekare: u.metrekare != null ? sayiBicimi(u.metrekare, "") : "",
      aktif: u.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    const kat = tamsayiCoz(form.kat);
    const sira = tamsayiCoz(form.sira);
    if (kat.tur === "gecersiz" || sira.tur === "gecersiz") {
      setFormErr(t("daireKatSiraGecersiz"));
      setSaving(false);
      return;
    }
    const m2 = sayiCoz(form.metrekare);
    if (m2.tur === "gecersiz") {
      setFormErr(t("daireMetrekareGecersiz"));
      setSaving(false);
      return;
    }
    const body = {
      no: form.no.trim(),
      blok: form.blok.trim(),  // blok ZORUNLU (canli-site kurali)
      kat: kat.tur === "sayi" ? kat.deger : null,
      sira: sira.tur === "sayi" ? sira.deger : null,
      metrekare: m2.tur === "sayi" ? m2.deger : null,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/units/${editingId}`, "PATCH", body);
      else await apiSend("/api/units", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("daireGuncellendi") : t("daireOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setFormErr(/zaten kayitli|conflict|no /i.test(m) ? t("daireNoZatenKayitli") : m);
    } finally {
      setSaving(false);
    }
  }

  async function remove(u: Unit) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("ortakSilOnay", { ad: u.no }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/units/${u.id}`, "DELETE");
      if (detail?.id === u.id) setDetail(null);
      mutate();
      toast.success(t("daireSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  const kolonlar: Kolon<Unit>[] = useMemo(
    () => [
      { id: "no", baslik: t("daireNoKisa"), hucre: (u) => u.no, gizlenebilir: false },
      {
        id: "blok",
        baslik: t("ortakBlok"),
        hucre: (u) => u.blok ?? t("daireBlokAtanmamis"),
      },
      {
        // (Duzeltme) DAIRE TIPI (P26) listede HIC gosterilmiyordu.
        // `unit_tip_ad` API'den ZATEN geliyordu — sayfa okumuyordu.
        // Tip ATANMAMISSA "-": bos hucre "veri gelmedi mi?" sorusunu
        // uretir, tire "atanmamis" der.
        id: "tip",
        baslik: t("tanimAlanTip"),
        hucre: (u) => u.unit_tip_ad ?? "—",
        darEkrandaGizle: true,
      },
      {
        id: "kat",
        baslik: t("daireKatSira"),
        sayisal: true,
        hucre: (u) =>
          u.kat != null || u.sira != null
            ? `${u.kat ?? "—"} / ${u.sira ?? "—"}`
            : "—",
        darEkrandaGizle: true,
      },
      {
        id: "m2",
        baslik: BIRIM_M2,
        sayisal: true,
        hucre: (u) => sayiBicimi(u.metrekare),
        darEkrandaGizle: true,
      },
      {
        id: "durum",
        baslik: t("ortakDurum"),
        hucre: (u) => (
          <Rozet durum={u.aktif ? DURUM_OLUMLU : DURUM_NOTR}>
            {u.aktif ? t("ortakAktif") : t("ortakPasif")}
          </Rozet>
        ),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (u) => (
          <div className="flex justify-end gap-2">
            <Dugme
              boy="kucuk"
              onClick={() => setDetail(detail?.id === u.id ? null : u)}
            >
              {detail?.id === u.id ? t("ortakKapat") : t("daireDetayAidat")}
            </Dugme>
            <Dugme boy="kucuk" onClick={() => openEdit(u)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme boy="kucuk" tur="tehlike" onClick={() => void remove(u)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, detail],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukDaireler")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("daireYeni")}
        </Dugme>
      </div>

      <BagimlilikUyarisi
        kod="blok"
        eksik={(bloklar?.items?.length ?? 1) === 0}
      />

      <div className="flex items-end gap-2">
        <div className="w-full sm:w-48">
          <AlanSarmal etiket={t("daireBlokFiltresi")}>
  {(b) => (
    <Alan {...b} value={blok}
              onChange={(e) => {
                setBlok(e.target.value);
                setOffset(0);
              }}
              placeholder="A" />
  )}
</AlanSarmal>
        </div>
      </div>

      {/* Liste cekilemezse BOS TABLO degil, sebep + "Tekrar dene".
          Yukleme durumu artik `VeriTablosu`nun ISKELETI. */}

      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("daireDuzenle") : t("daireYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme type="submit" form="daire-form" tur="birincil" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="daire-form" onSubmit={save} className="space-y-4">
          <div className="grid grid-cols-3 gap-4">
            <AlanSarmal etiket={t("binaDaireNo")} ipucu={t("daireNoIpucu")}>
  {(b) => (
    <Alan {...b} value={form.no}
                onChange={(e) => setForm({ ...form, no: e.target.value })}
                placeholder="A-12"
                pattern="[A-Za-z0-9-]+"
                title={t("daireNoGecersiz")}
                required />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("ortakBlok")} ipucu={t("blokIpucu")}>
  {(b) => (
    <Alan {...b} value={form.blok}
                onChange={(e) => setForm({ ...form, blok: e.target.value })}
                pattern="[A-Za-z0-9]+"
                maxLength={8}
                title={t("blokGecersiz")}
                placeholder="A"
                required />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("daireMetrekareOpsiyonel")}>
  {(b) => (
    <Alan {...b} inputMode="decimal"
                value={form.metrekare}
                onChange={(e) => setForm({ ...form, metrekare: e.target.value })} />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("daireKatOpsiyonel")} ipucu={t("katIpucu")}>
  {(b) => (
    <Alan {...b} inputMode="numeric"
                value={form.kat}
                onChange={(e) => setForm({ ...form, kat: e.target.value })}
                placeholder="1" />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("siraOpsiyonel")} ipucu={t("siraIpucu")}>
  {(b) => (
    <Alan {...b} inputMode="numeric"
                value={form.sira}
                onChange={(e) => setForm({ ...form, sira: e.target.value })}
                placeholder="2" />
  )}
</AlanSarmal>
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />
            {t("ortakAktif")}
          </label>
          {formErr && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {formErr}
            </p>
          )}
        </form>
      </Modal>

      {/* (P154 / Asama 5) TOPLU ISLEM SERIDI. Aralik ifadesi EKRANDAKI
          listeye uygulanir; blok suzgeci acikken "7-12" o blogun
          daireleridir (bkz. `lib/aralik.ts`). */}
      <section className="flex flex-wrap items-end gap-2">
        <div className="w-full sm:w-56">
          <AlanSarmal etiket={t("daireAralikSec")} ipucu={t("daireAralikIpucu")}>
  {(b) => (
    <Alan {...b} value={aralikIfade}
              onChange={(e) => setAralikIfade(e.target.value)}
              placeholder="3,5,7-12" />
  )}
</AlanSarmal>
        </div>
        <Dugme onClick={araligiUygula}>{t("daireAralikUygula")}</Dugme>
        <Dugme onClick={() => setOAcik(true)}>{t("daireTopluOlustur")}</Dugme>
        <div className="w-full sm:w-32">
          <AlanSarmal etiket={t("daireKatSil")}>
  {(b) => (
    <Alan {...b} value={katSilKat}
              onChange={(e) => setKatSilKat(e.target.value)}
              placeholder="1" />
  )}
</AlanSarmal>
        </div>
        <Dugme tur="tehlike" disabled={!blok} onClick={() => void katSil()}>
          {t("daireKatSil")}
        </Dugme>
      </section>
      {topluHata && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {topluHata}
            </p>
          )}

      {/* (P160 / Asama 6) TABLO -> `VeriTablosu`.
          Satir secimi, "hepsini sec" (BELIRSIZ secimde `indeterminate`),
          toplu islem seridi ve SAYFA BASINA KAYIT SECIMI artik ilkelden
          geliyor; sayfa bunlari kendi yazmiyor. Aralik ifadesi ve toplu
          islem DUGMELERI korundu — onlar bu sayfaya ozel. */}
      <VeriTablosu<Unit>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(u) => u.id}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("daireYok")}
        bosAciklama={t("daireYokAlt")}
        secilebilir
        secili={secili}
        onSeciliDegisti={setSecili}
        sunucuTarafli
        toplam={data?.meta.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
        topluEylemler={() => (
          <Dugme
            boy="kucuk"
            tur="birincil"
            onClick={() => setTopluAcik(true)}
          >
            {t("daireTopluDegistir", { adet: secili.length })}
          </Dugme>
        )}
      />

      {detail && <UnitDetail unit={detail} />}

      <Modal
        baslik={t("daireTopluOlustur")}
        acik={oAcik}
        onKapat={() => setOAcik(false)}
        kirliMi={oBlok !== ""}
        onKirliKapat={() => {
          void onayla({
            baslik: t("modalKirliBaslik"),
            mesaj: t("modalKirliUyari"),
            onayMetni: t("ortakVazgec"),
            tehlikeli: true,
          }).then((o) => {
            if (o) setOAcik(false);
          });
        }}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" onClick={() => void topluOlustur()}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-3">
          {oHata && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {oHata}
            </p>
          )}
          <div className="grid gap-3 sm:grid-cols-2">
            <AlanSarmal etiket={t("ortakBlok")}>
  {(b) => (
    <Alan {...b} value={oBlok}
                     onChange={(e) => setOBlok(e.target.value)} />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("daireKatSayisi")}>
  {(b) => (
    <Alan {...b} value={oKat}
                     onChange={(e) => setOKat(e.target.value)} />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("daireKatBasi")}>
  {(b) => (
    <Alan {...b} value={oDaire}
                     onChange={(e) => setODaire(e.target.value)} />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("daireBaslangicNo")}>
  {(b) => (
    <Alan {...b} value={oBaslangicNo}
                     onChange={(e) => setOBaslangicNo(e.target.value)} />
  )}
</AlanSarmal>
            {/* (P154 / Asama 5) BASLANGIC KATI: bodrum ve zemin gercek
                katlardir. "Zemin" ayri bir DEGER degil 0'dir — metin bir
                kat numarasi siralanamaz. */}
            <AlanSarmal etiket={t("daireBaslangicKat")} ipucu={t("daireBaslangicKatIpucu")}>
  {(b) => (
    <Alan {...b} value={oBaslangicKat}
                     onChange={(e) => setOBaslangicKat(e.target.value)} />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("tanimAlanTip")}>
  {(b) => (
    <Secim {...b} value={oTip}
                      onChange={(e) => setOTip(e.target.value)}>
                <option value="">—</option>
                {(tipler?.items ?? []).map((x) => (
                  <option key={x.id} value={x.id}>{x.ad}</option>
                ))}</Secim>
  )}
</AlanSarmal>
          </div>
        </div>
      </Modal>

      <Modal
        baslik={t("daireTopluBaslik")}
        acik={topluAcik}
        onKapat={() => setTopluAcik(false)}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setTopluAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" onClick={() => void topluGuncelle()}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-3">
          <p className="text-sm text-metin-muted">
            {t("daireTopluSecili", { adet: secili.length })}
          </p>
          <AlanSarmal etiket={t("ortakDurum")}>
  {(b) => (
    <Secim {...b} value={topluAktif}
              onChange={(e) => setTopluAktif(e.target.value)}
            >
              <option value="">{t("daireTopluDegistirme")}</option>
              <option value="1">{t("ortakAktif")}</option>
              <option value="0">{t("ortakPasif")}</option></Secim>
  )}
</AlanSarmal>
          {/* (P154 / Asama 5) DAIRE TIPI DEGISTIRME — brief: "Web'de daire
              tipi degistirme eklensin". Tekil PATCH zaten vardi ama
              arayuzde hicbir yerde acik degildi. */}
          <AlanSarmal etiket={t("tanimAlanTip")}>
  {(b) => (
    <Secim {...b} value={topluTip}
              onChange={(e) => setTopluTip(e.target.value)}
            >
              <option value="">{t("daireTopluDegistirme")}</option>
              {(tipler?.items ?? []).map((x) => (
                <option key={x.id} value={x.id}>{x.ad}</option>
              ))}</Secim>
  )}
</AlanSarmal>
        </div>
      </Modal>

      {diyalog}
    </div>
  );
}
