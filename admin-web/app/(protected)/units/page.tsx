"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
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
import { useAcilinca } from "@/lib/kaydir";
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
  /** (P192 §3.3) Kat Mulkiyeti Kanunu md. 20 gider paylasimini ARSA
   *  PAYINA gore tanimlar; toplu borclandirmanin "arsa payina gore"
   *  dagitimi bu alani okur. Girilmemis daire dagitimin DISINDA kalir ve
   *  bu kullaniciya soylenir (sessizce sifir borclandirilmaz). */
  arsa_payi: string;
  aktif: boolean;
}
const EMPTY: FormState = {
  no: "", blok: "", kat: "", sira: "", metrekare: "", arsa_payi: "", aktif: true,
};

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
  const router = useRouter();
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
  const [topluAcik, setTopluAcik] = useState(false);
  const [topluHata, setTopluHata] = useState<string | null>(null);
  const [topluAktif, setTopluAktif] = useState("");
  const [topluTip, setTopluTip] = useState("");
  // (P193 §6) ARSA PAYI TOPLU GIRIS — daire basina FARKLI deger.
  const [payAcik, setPayAcik] = useState(false);
  const [paylar, setPaylar] = useState<Record<string, string>>({});
  const [payHata, setPayHata] = useState<string | null>(null);

  // (P154 / Asama 5) TOPLU DAIRE OLUSTURMA — uc ZATEN VARDI
  // (`POST /units/bulk`), eksik olan yalnizca web yuzeyiydi (mobilde
  // caliyordu). Ikinci bir uc yazilmadi.

  const { data: tipler } = useSWR<{ items: { id: string; ad: string }[] }>(
    "/api/tanimlar/unit-tipleri?limit=100",
    jsonFetcher,
  );

  // (P193 §6) TOPLAM AYRI UCTAN GELIR, ekranda toplanmaz: liste SAYFALI
  // ve gorunen 25 satirin toplami "toplam arsa payi" DEGILDIR. Yanlis
  // bir toplam, dogru gorunen bir hatadir.
  const { data: payOzet, mutate: payOzetTazele } = useSWR<{
    daire_sayisi: number; girilmis: number; girilmemis: number; toplam: number;
  }>("/api/units/arsa-payi-ozeti", jsonFetcher);



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

  async function arsaPayiKaydet(): Promise<void> {
    setPayHata(null);
    const satirlar: { id: string; arsa_payi: number | null }[] = [];
    for (const id of secili) {
      const ham = (paylar[id] ?? "").trim();
      if (ham === "") {
        // BOS = KALDIR. "Dokunmadim" ile "temizledim" ayrimi burada
        // gerekmiyor: modal yalniz SECILI daireleri gosterir ve
        // kullanici hepsini gormus olur.
        satirlar.push({ id, arsa_payi: null });
        continue;
      }
      const coz = sayiCoz(ham);
      if (coz.tur !== "sayi" || coz.deger < 0) {
        setPayHata(t("daireArsaPayiGecersiz"));
        return;
      }
      satirlar.push({ id, arsa_payi: coz.deger });
    }
    try {
      await apiSend("/api/units/arsa-payi", "PATCH", { satirlar });
      setPayAcik(false);
      setSecili([]);
      await Promise.all([mutate(), payOzetTazele()]);
      toast.success(t("daireTopluGuncellendi"));
    } catch (e) {
      setPayHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
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
  // (P162 §7.1) Acilan detay alanina yumusak kaydirma — tek yardimci.
  const { ref: detayRef, kaydir: detayKaydir } = useAcilinca();
  const [detail, setDetail] = useState<Unit | null>(null);

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
      arsa_payi: u.arsa_payi != null ? sayiBicimi(u.arsa_payi, "") : "",
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
    const pay = sayiCoz(form.arsa_payi);
    if (m2.tur === "gecersiz" || pay.tur === "gecersiz") {
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
      arsa_payi: pay.tur === "sayi" ? pay.deger : null,
      aktif: form.aktif,
    };
    try {
      // (P165 §2) MODAL ARTIK YALNIZ DUZENLEME. Olusturma dali
      // KALDIRILDI cunku bu sayfada onu acan bir yol kalmadi (olu kod).
      // Daire olusturma BINA DUZENLEME'de kendi formuyla duruyor —
      // `POST /units` ucu ORADA kullaniliyor, yani uc olu DEGIL.
      await apiSend(`/api/units/${editingId}`, "PATCH", body);
      setOpen(false);
      mutate();
      toast.success(t("daireGuncellendi"));
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
      { id: "no", kartRolu: "baslik", baslik: t("daireNoKisa"), hucre: (u) => u.no, gizlenebilir: false },
      {
        id: "blok", kartRolu: "ozet",
        baslik: t("ortakBlok"),
        hucre: (u) => u.blok ?? t("daireBlokAtanmamis"),
      },
      {
        // (Duzeltme) DAIRE TIPI (P26) listede HIC gosterilmiyordu.
        // `unit_tip_ad` API'den ZATEN geliyordu — sayfa okumuyordu.
        // Tip ATANMAMISSA "-": bos hucre "veri gelmedi mi?" sorusunu
        // uretir, tire "atanmamis" der.
        id: "tip", kartRolu: "ozet",
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
        // (P193 §6) ARSA PAYI SUTUNU. Listede gorunmedigi surece "hangi
        // dairede eksik" sorusu ancak daire daire acilarak yanitlanirdi
        // — ve eksik arsa payi, arsa payina gore dagitimi SESSIZCE
        // eksik birakir.
        id: "arsa_payi",
        baslik: t("daireArsaPayi"),
        sayisal: true,
        hucre: (u) => sayiBicimi(u.arsa_payi),
        darEkrandaGizle: true,
      },
      {
        id: "durum", kartRolu: "rozet",
        baslik: t("ortakDurum"),
        hucre: (u) => (
          <Rozet durum={u.aktif ? DURUM_OLUMLU : DURUM_NOTR}>
            {u.aktif ? t("ortakAktif") : t("ortakPasif")}
          </Rozet>
        ),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (u) => (
          <div className="flex justify-end gap-2">
            <Dugme
              boy="kucuk"
              onClick={() => { setDetail(detail?.id === u.id ? null : u); detayKaydir(); }}
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
        {/* (P165 §2) "YENI DAIRE" DUGMESI KALDIRILDI.
            Daire ekleme artik BINA DUZENLEME ekraninda; iki giris
            noktasi, kullaniciyi "hangisi dogru" sorusuyla birakiyordu.
            Ekran YINE DE cikmaza sokmuyor: bosken ve baslikta oraya
            goturen bir bag var. */}
        {/* (P181 6.2) Düz metin bağlantı yerine birincil düğme; diğer ekranlarla tutarlı. */}
        <Dugme
          tur="birincil"
          boy="kucuk"
          onClick={() => router.push("/building-editor")}
        >
          {t("daireBinaDuzenlemeGit")}
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
        baslik={t("daireDuzenle")}
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
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
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
            <AlanSarmal etiket={t("unitsArsaPayi")}>
  {(b) => (
    <Alan {...b} inputMode="decimal"
                value={form.arsa_payi}
                onChange={(e) => setForm({ ...form, arsa_payi: e.target.value })} />
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

      {/* (P163 §4) YAPISAL ARACLAR BURADAN KALDIRILDI.
          Toplu daire olusturma, kat silme ve "numara ile sec" artik
          BINA DUZENLEME ekraninda. Gerekce: bu sayfa bir LISTE/CRUD
          yuzeyi; binanin yapisini degistiren islemler, liste suzulurken
          yanlislikla basilacak yerde durmamali. Uclar degismedi. */}
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
        bosEylem={
          <Link
            href="/building-editor"
            className="odak-ic rounded-btn px-3 py-1.5 text-satiralt underline"
            style={{ color: "var(--yz-accent-ink)" }}
          >
            {t("daireBosDurumEylem")}
          </Link>
        }
        bosAciklama={t("daireYokAlt")}
        secilebilir
        secili={secili}
        onSeciliDegisti={setSecili}
        sunucuTarafli
        toplam={data?.meta?.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
        topluEylemler={() => (
          <>
            <Dugme
              boy="kucuk"
              tur="birincil"
              onClick={() => setTopluAcik(true)}
            >
              {t("daireTopluDegistir", { adet: secili.length })}
            </Dugme>
            {/* (P193 §6) AYRI DUGME, ayni modalin bir alani DEGIL:
                "hepsine ayni degeri yaz" ile "her daireye kendi
                degerini yaz" iki farkli istir ve tek formda
                birlestirmek ikisini de belirsizlestirirdi. */}
            <Dugme
              boy="kucuk"
              onClick={() => {
                const baslangic: Record<string, string> = {};
                for (const u of data?.items ?? []) {
                  if (!secili.includes(u.id)) continue;
                  baslangic[u.id] =
                    u.arsa_payi != null ? sayiBicimi(u.arsa_payi, "") : "";
                }
                setPaylar(baslangic);
                setPayHata(null);
                setPayAcik(true);
              }}
            >
              {t("daireArsaPayiToplu", { adet: secili.length })}
            </Dugme>
          </>
        )}
      />

      {/* (P193 §6) ARSA PAYI OZETI — toplam ve EKSIK GIRIS sayisi.
          Arsa payi bir PAYDIR: toplami beklenen degeri tutmayan bir
          dagilim gider paylasimini sessizce yanlis hesaplar, ve
          girilmemis daire dagitimin DISINDA kalir. Ikisi de burada
          gorunur. */}
      {payOzet && (
        <p
          role="status"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
        >
          {t("daireArsaPayiOzet", {
            toplam: sayiBicimi(payOzet.toplam, "0"),
            girilmis: String(payOzet.girilmis),
            daire: String(payOzet.daire_sayisi),
          })}
          {payOzet.girilmemis > 0 ? ` ${t("daireArsaPayiEksik", { adet: String(payOzet.girilmemis) })}` : null}
        </p>
      )}

      <div ref={detayRef}>{detail && <UnitDetail unit={detail} />}</div>

      <Modal
        baslik={t("daireArsaPayiBaslik")}
        acik={payAcik}
        onKapat={() => setPayAcik(false)}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setPayAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" onClick={() => void arsaPayiKaydet()}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-3">
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("daireArsaPayiAciklama")}
          </p>
          {payHata && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {payHata}
            </p>
          )}
          {(data?.items ?? [])
            .filter((u) => secili.includes(u.id))
            .map((u) => (
              <AlanSarmal key={u.id} etiket={u.no}>
                {(b) => (
                  <Alan
                    {...b}
                    inputMode="decimal"
                    value={paylar[u.id] ?? ""}
                    onChange={(e) =>
                      setPaylar({ ...paylar, [u.id]: e.target.value })
                    }
                    placeholder="0,0125"
                  />
                )}
              </AlanSarmal>
            ))}
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
