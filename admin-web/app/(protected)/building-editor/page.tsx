"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";
import { daireTipiKisa, daireTipiRengi } from "@/lib/daire-tipi-rengi";

import {
  Modal,
  Kart,
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  useOnay,
  Secim,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { aralikCoz } from "@/lib/aralik";
import { jsonFetcher } from "@/lib/fetcher";
import type { Block, BlockList, Unit, UnitList } from "@/lib/types";
import { tamsayiCoz } from "@/lib/sayi";
import { useT } from "@/lib/i18n/kullan";

// Bloksuz kova (implicit tek blok) icin sentinel — gercek blok etiketi
// alfanumerik ve >=1 karakter, bu deger asla cakismaz.
const BLOCKLESS = "__bloksuz__";

// (P56) `intOrNull` KALDIRILDI: gecersiz girdi de `null` donuyordu ve
// `null` "alani temizle" demek — kullanici kat/sira degerini yanlis
// yazdiginda alan SESSIZCE siliniyordu. `tamsayiCoz` ucunu ayirir.

interface BlockFormState {
  open: boolean;
  editingId: string | null;
  ad: string;
  err: string | null;
  saving: boolean;
}
const EMPTY_BLOCK: BlockFormState = {
  open: false, editingId: null, ad: "", err: null, saving: false,
};

interface UnitFormState {
  open: boolean;
  editingId: string | null;
  blok: string | null; // null → bloksuz
  no: string;
  kat: string;
  sira: string;
  err: string | null;
  saving: boolean;
}
const EMPTY_UNIT: UnitFormState = {
  open: false, editingId: null, blok: null, no: "", kat: "", sira: "", err: null, saving: false,
};

/** Sunucudaki `_BLOK_PATTERN` ile AYNI — ayrisirsa test duser. */
const BLOK_KALIBI = /^[A-Za-z0-9]+$/;

export default function BuildingEditorPage() {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const blocks = useSWR<BlockList>("/api/blocks", jsonFetcher);
  const units = useSWR<UnitList>("/api/units?limit=200&offset=0", jsonFetcher);

  const [openBlock, setOpenBlock] = useState<string | null>(null); // null=liste; BLOCKLESS/label=detay
  const [pendingFloors, setPendingFloors] = useState<number[]>([]);
  const [blockForm, setBlockForm] = useState<BlockFormState>(EMPTY_BLOCK);
  const [unitForm, setUnitForm] = useState<UnitFormState>(EMPTY_UNIT);

  const blockItems = useMemo(() => blocks.data?.items ?? [], [blocks.data]);
  const unitItems = useMemo(() => units.data?.items ?? [], [units.data]);

  const labels = useMemo(() => {
    const s = new Set<string>();
    for (const b of blockItems) s.add(b.ad);
    for (const u of unitItems) if (u.blok) s.add(u.blok);
    return [...s].sort();
  }, [blockItems, unitItems]);

  const blocklessUnits = useMemo(() => unitItems.filter((u) => !u.blok), [unitItems]);
  const blockByLabel = (label: string): Block | undefined => blockItems.find((b) => b.ad === label);

  // Bloklu ve bloksuz (blok=null) AYNI akista: kutucuk listesi + bir "Bloksuz"
  // kovasi (mod anahtari yok). Detay: openBlock null degil.
  const drilledIn = openBlock !== null;
  const isBlockless = openBlock === BLOCKLESS;

  /**
   * (P154 / Asama 5) SURUKLE-BIRAK SONRASI YERLESIMI KAYDET.
   *
   * TEK ISTEK (`PATCH /units/siralama`): her daire icin ayri PATCH
   * atmak, yirmi dairelik bir katta yirmi istek ve ARADA KESILME riski
   * demekti — yarim uygulanmis bir siralama, kullanicinin gordugu
   * duzenle veritabanindakini ayirirdi.
   */
  async function siralamayiKaydet(
    satirlar: { id: string; kat: number; sira: number }[],
  ) {
    if (satirlar.length === 0) return;
    try {
      await apiSend("/api/units/siralama", "PATCH", { satirlar });
      refresh();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }
  // ==================================================================
  // (P163 §4) YAPISAL ARACLAR — "Daireler" listesinden BURAYA TASINDI.
  //
  // Brief: "Toplu daire olustur · Kat sil · Numara ile sec bunlar BINA
  // DUZENLEME ekranina tasinacak; yapisal islemler tek yerde toplanmali.
  // Daireler listesi liste/filtre/CRUD ekrani olarak kalsin."
  //
  // GEREKCE: bir daireyi duzenlemek ile BINANIN YAPISINI degistirmek
  // ayri islerdir. Toplu olusturma ve kat silme, bir listeyi suzerken
  // yanlislikla basilabilecek eylemler degil; binanin semasina bakarken
  // yapilan eylemlerdir. Zaten "+ Kat" ve daire "+" dugmeleri burada.
  //
  // UCLAR DEGISMEDI: `POST /units/bulk`, `POST /units/kat-sil`,
  // `PATCH /units/toplu`. Tasinan sey ARAYUZ.
  // ==================================================================
  const [topluAcik, setTopluAcik] = useState(false);
  const [oBlok, setOBlok] = useState("");
  const [oKat, setOKat] = useState("3");
  const [oDaire, setODaire] = useState("4");
  const [oBaslangicNo, setOBaslangicNo] = useState("1");
  const [oBaslangicKat, setOBaslangicKat] = useState("1");
  const [oTip, setOTip] = useState("");
  const [oHata, setOHata] = useState<string | null>(null);

  const [katSilAcik, setKatSilAcik] = useState(false);
  const [katSilBlok, setKatSilBlok] = useState("");
  const [katSilKat, setKatSilKat] = useState("");
  const [katSilHata, setKatSilHata] = useState<string | null>(null);

  const [tipAcik, setTipAcik] = useState(false);
  const [aralikIfade, setAralikIfade] = useState("");
  const [secili, setSecili] = useState<string[]>([]);
  const [topluTip, setTopluTip] = useState("");
  const [topluAktif, setTopluAktif] = useState("");
  const [tipHata, setTipHata] = useState<string | null>(null);

  const { data: tipler } = useSWR<{ items: { id: string; ad: string }[] }>(
    "/api/tanimlar/unit-tipleri?limit=100",
    jsonFetcher,
  );

  async function topluOlustur(): Promise<void> {
    setOHata(null);
    // (P162 §4.1) BLOK ADI SUNUCUDA `^[A-Za-z0-9]+$`. Istek ATILMADAN
    // once sebebi soylenir; yoksa kullanici anlamsiz bir 422 alirdi.
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
    if (Object.values(sayilar).some((v) => v.tur !== "sayi")) {
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
      setTopluAcik(false);
      refresh();
      toast.success(t("daireTopluOlusturuldu"));
    } catch (e) {
      setOHata(alanliHataMetni(e, t("ortakHataOlustu")));
    }
  }

  async function katSil(): Promise<void> {
    setKatSilHata(null);
    const kat = tamsayiCoz(katSilKat);
    if (kat.tur !== "sayi" || !katSilBlok) {
      setKatSilHata(t("daireKatSilAlanlar"));
      return;
    }
    const ok = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("daireKatSilOnay", { kat: kat.deger, blok: katSilBlok }),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      await apiSend("/api/units/kat-sil", "POST", {
        blok: katSilBlok,
        kat: kat.deger,
        cascade: true,
      });
      setKatSilAcik(false);
      refresh();
      toast.success(t("daireKatSilindi"));
    } catch (e) {
      setKatSilHata(alanliHataMetni(e, t("ortakHataOlustu")));
    }
  }

  function araligiUygula(): void {
    setTipHata(null);
    const sonuc = aralikCoz(
      aralikIfade,
      (units.data?.items ?? []).map((u) => ({ id: u.id, no: u.no })),
    );
    setSecili(sonuc.idler);
    if (sonuc.bulunamayan.length > 0) {
      // SESSIZCE DUSMEZ: "12 daire sectim" deyip 9'unu islemek en kotu
      // sonuctur.
      setTipHata(t("daireAralikBulunamayan", { parca: sonuc.bulunamayan.join(", ") }));
    }
  }

  async function topluTipUygula(): Promise<void> {
    setTipHata(null);
    if (secili.length === 0) return;
    // EN AZ BIR ALAN: bos istek "yaptim" deyip hicbir sey yapmamakti.
    if (topluAktif === "" && topluTip === "") return;
    const govde: Record<string, unknown> = { unit_ids: secili };
    if (topluAktif !== "") govde.aktif = topluAktif === "1";
    if (topluTip !== "") govde.unit_tip_id = topluTip;
    try {
      await apiSend("/api/units/toplu", "PATCH", govde);
      setTipAcik(false);
      setSecili([]);
      refresh();
      toast.success(t("daireTopluGuncellendi"));
    } catch (e) {
      setTipHata(alanliHataMetni(e, t("ortakHataOlustu")));
    }
  }


  function refresh() {
    void blocks.mutate();
    void units.mutate();
  }

  function openTile(label: string) {
    setOpenBlock(label);
    setPendingFloors([]);
  }
  function closeDetail() {
    setOpenBlock(null);
    setPendingFloors([]);
  }

  // --- block CRUD ----------------------------------------------------------
  async function saveBlock(e: React.FormEvent) {
    e.preventDefault();
    setBlockForm((f) => ({ ...f, saving: true, err: null }));
    const body = { ad: blockForm.ad.trim() };
    try {
      if (blockForm.editingId) await apiSend(`/api/blocks/${blockForm.editingId}`, "PATCH", body);
      else await apiSend("/api/blocks", "POST", body);
      setBlockForm(EMPTY_BLOCK);
      refresh();
      toast.success(blockForm.editingId ? t("binaBlokGuncellendi") : t("binaBlokOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setBlockForm((f) => ({
        ...f,
        saving: false,
        err: /zaten kayitli|conflict/i.test(m) ? t("binaBlokZatenKayitli") : m,
      }));
    }
  }

  async function removeBlock(b: Block) {
    const count = unitItems.filter((u) => u.blok === b.ad).length;
    let cascade = false;
    if (count === 0) {
      if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("binaBlokBasitSilOnay", { blok: b.ad }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    } else {
      // Yikici: daireleri + bagli kayitlari siler. Sert onay: blok adini yaz.
      const typed = window.prompt(
        t("binaBlokSilOnay", { blok: b.ad, sayi: count }),
      );
      if (typed == null) return; // iptal
      if (typed.trim() !== b.ad) {
        toast.error(t("binaBlokAdEslesmedi"));
        return;
      }
      cascade = true;
    }
    try {
      await apiSend(`/api/blocks/${b.id}${cascade ? "?cascade=true" : ""}`, "DELETE");
      if (openBlock === b.ad) closeDetail();
      refresh();
      toast.success(
        cascade
          ? t("blokVeDaireSilindi", { ad: b.ad, n: count })
          : t("blokSilindi"),
      );
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("blokSilinemedi"));
    }
  }

  // --- unit CRUD -----------------------------------------------------------
  async function saveUnit(e: React.FormEvent) {
    e.preventDefault();
    const kat = tamsayiCoz(unitForm.kat);
    const sira = tamsayiCoz(unitForm.sira);
    if (kat.tur === "gecersiz" || sira.tur === "gecersiz") {
      setUnitForm((f) => ({ ...f, err: t("daireKatSiraGecersiz") }));
      return;
    }
    setUnitForm((f) => ({ ...f, saving: true, err: null }));
    const body = {
      no: unitForm.no.trim(),
      blok: unitForm.blok,
      kat: kat.tur === "sayi" ? kat.deger : null,
      sira: sira.tur === "sayi" ? sira.deger : null,
      aktif: true,
    };
    try {
      if (unitForm.editingId) await apiSend(`/api/units/${unitForm.editingId}`, "PATCH", body);
      else await apiSend("/api/units", "POST", body);
      setUnitForm(EMPTY_UNIT);
      refresh();
      toast.success(unitForm.editingId ? t("daireGuncellendi") : t("daireOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setUnitForm((f) => ({
        ...f,
        saving: false,
        err: /zaten kayitli|conflict|no /i.test(m) ? t("daireNoZatenKayitli") : m,
      }));
    }
  }

  async function removeUnit(u: Unit) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("ortakSilOnay", { ad: u.no }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/units/${u.id}`, "DELETE");
      refresh();
      toast.success(t("daireSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  function openNewBlock() {
    setBlockForm({ ...EMPTY_BLOCK, open: true });
  }
  function openEditBlock(b: Block) {
    setBlockForm({
      open: true, editingId: b.id, ad: b.ad,
      err: null, saving: false,
    });
  }
  function openNewUnit(blok: string | null, kat?: number) {
    // Sira onerisi: bu blok+kattaki en yuksek sira + 1.
    const bucket = blok ? unitItems.filter((u) => u.blok === blok) : blocklessUnits;
    const onKat = bucket.filter((u) => (u.kat ?? null) === (kat ?? null));
    const maxSira = onKat.reduce((m, u) => Math.max(m, u.sira ?? 0), 0);
    setUnitForm({
      ...EMPTY_UNIT, open: true, blok,
      kat: kat != null ? String(kat) : "",
      sira: String(maxSira + 1),
    });
  }
  function openEditUnit(u: Unit) {
    setUnitForm({
      open: true, editingId: u.id, blok: u.blok ?? null, no: u.no,
      kat: u.kat != null ? String(u.kat) : "",
      sira: u.sira != null ? String(u.sira) : "",
      err: null, saving: false,
    });
  }

  function addFloor() {
    const bucket = isBlockless
      ? blocklessUnits
      : unitItems.filter((u) => u.blok === openBlock);
    const kats = new Set<number>(pendingFloors);
    for (const u of bucket) if (u.kat != null) kats.add(u.kat);
    const next = kats.size ? Math.max(...kats) + 1 : 1;
    setPendingFloors((p) => [...new Set([...p, next])]);
  }

  const loadError = blocks.error || units.error;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("kabukBinaDuzenleme")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("binaAciklama")}
          </p>
        </div>
        {/* (P163 §4) YAPISAL ARAC SERIDI — hepsi MODAL acar (P162 kurali).
            Bu ucu "Daireler" listesinin ustunden BURAYA tasindi: binanin
            YAPISINI degistiren islemler, bir liste suzulurken yanlislikla
            basilacak yerde durmamali. */}
        <div className="flex flex-wrap items-center gap-2">
          <Dugme
            boy="kucuk"
            onClick={() => {
              setOHata(null);
              setTopluAcik(true);
            }}
          >
            {t("daireTopluOlustur")}
          </Dugme>
          <Dugme
            boy="kucuk"
            onClick={() => {
              setKatSilHata(null);
              setKatSilAcik(true);
            }}
          >
            {t("daireKatSil")}
          </Dugme>
          <Dugme
            boy="kucuk"
            onClick={() => {
              setTipHata(null);
              setTipAcik(true);
            }}
          >
            {t("binaTopluTip")}
          </Dugme>
          {drilledIn ? (
            <Dugme boy="kucuk" onClick={closeDetail}>{t("binaBloklaraDon")}</Dugme>
          ) : null}
        </div>
      </div>

      {/* --- TOPLU DAIRE OLUSTUR --- */}
      <Modal
        acik={topluAcik}
        onKapat={() => setTopluAcik(false)}
        baslik={t("daireTopluOlustur")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setTopluAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" onClick={() => void topluOlustur()}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <AlanSarmal etiket={t("binaBlokEtiketi")} ipucu={t("binaBlokIpucu")} zorunlu>
              {(b) => (
                <Alan {...b} value={oBlok} onChange={(e) => setOBlok(e.target.value)} />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("daireKatSayisi")} zorunlu>
              {(b) => (
                <Alan {...b} inputMode="numeric" value={oKat} onChange={(e) => setOKat(e.target.value)} />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("daireKatBasi")} zorunlu>
              {(b) => (
                <Alan {...b} inputMode="numeric" value={oDaire} onChange={(e) => setODaire(e.target.value)} />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("daireBaslangicNo")} zorunlu>
              {(b) => (
                <Alan {...b} inputMode="numeric" value={oBaslangicNo} onChange={(e) => setOBaslangicNo(e.target.value)} />
              )}
            </AlanSarmal>
            {/* BASLANGIC KATI NEGATIF OLABILIR: bodrum ve zemin gercek
                katlardir (-2, -1, 0). `inputMode="numeric"` eksi isaretini
                engellemez; `type="number"` da kullanilmadi cunku bazi
                tarayicilarda tekerlek ile deger degistiriyor. */}
            <AlanSarmal etiket={t("daireBaslangicKat")} ipucu={t("daireBaslangicKatIpucu")}>
              {(b) => (
                <Alan {...b} value={oBaslangicKat} onChange={(e) => setOBaslangicKat(e.target.value)} />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("tanimAlanTip")}>
              {(b) => (
                <Secim {...b} value={oTip} onChange={(e) => setOTip(e.target.value)}>
                  <option value="">{t("ortakSeciniz")}</option>
                  {(tipler?.items ?? []).map((x) => (
                    <option key={x.id} value={x.id}>{x.ad}</option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
          </div>
          <HataDurumu mesaj={oHata} />
        </div>
      </Modal>

      {/* --- KAT SIL --- */}
      <Modal
        acik={katSilAcik}
        onKapat={() => setKatSilAcik(false)}
        baslik={t("daireKatSil")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setKatSilAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="tehlike" onClick={() => void katSil()}>
              {t("ortakSil")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <AlanSarmal etiket={t("binaBlokEtiketi")} zorunlu>
              {(b) => (
                <Secim {...b} value={katSilBlok} onChange={(e) => setKatSilBlok(e.target.value)}>
                  <option value="">{t("ortakSeciniz")}</option>
                  {(blocks.data?.items ?? []).map((x) => (
                    <option key={x.id} value={x.ad}>{x.ad}</option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("binaKat")} zorunlu>
              {(b) => (
                <Alan {...b} value={katSilKat} onChange={(e) => setKatSilKat(e.target.value)} />
              )}
            </AlanSarmal>
          </div>
          <HataDurumu mesaj={katSilHata} />
        </div>
      </Modal>

      {/* --- DAIRE TIPI TOPLU DEGISTIR (numara ile sec) --- */}
      <Modal
        acik={tipAcik}
        onKapat={() => setTipAcik(false)}
        baslik={t("binaTopluTip")}
        genislikSinifi="max-w-xl"
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setTipAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={secili.length === 0} onClick={() => void topluTipUygula()}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="flex flex-wrap items-end gap-2">
            <div className="grow">
              <AlanSarmal etiket={t("daireAralikSec")} ipucu={t("daireAralikIpucu")}>
                {(b) => (
                  <Alan {...b} value={aralikIfade} onChange={(e) => setAralikIfade(e.target.value)} placeholder="3,5,7-12" />
                )}
              </AlanSarmal>
            </div>
            <Dugme onClick={araligiUygula}>{t("daireAralikUygula")}</Dugme>
          </div>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("daireSeciliSayisi", { sayi: secili.length })}
          </p>
          <div className="grid gap-4 sm:grid-cols-2">
            <AlanSarmal etiket={t("tanimAlanTip")}>
              {(b) => (
                <Secim {...b} value={topluTip} onChange={(e) => setTopluTip(e.target.value)}>
                  <option value="">{t("daireDegistirme")}</option>
                  {(tipler?.items ?? []).map((x) => (
                    <option key={x.id} value={x.id}>{x.ad}</option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("ortakDurum")}>
              {(b) => (
                <Secim {...b} value={topluAktif} onChange={(e) => setTopluAktif(e.target.value)}>
                  <option value="">{t("daireDegistirme")}</option>
                  <option value="1">{t("ortakAktif")}</option>
                  <option value="0">{t("ortakPasif")}</option>
                </Secim>
              )}
            </AlanSarmal>
          </div>
          <HataDurumu mesaj={tipHata} />
        </div>
      </Modal>

      {/* (P163 §3) YETKI NOTU KALDIRILDI — YANLISTI.
          Metin "bu duzenleyici yalnizca platform adminine aciktir; site
          yoneticileri ayni duzenlemeyi mobilden yapar" diyordu. Olculdu
          ve yanlis: `lib/yuzey.ts` -> `/building-editor: ["admin",
          "yonetici"]`, backend -> `_LAYOUT_EDITOR = admin + yonetici`.
          Yani yonetici bu ekranda ZATEN duzenleme yapabiliyordu; not onu
          yapamayacagina inandiriyordu. */}

      {loadError && <HataDurumu mesaj={t("binaVerilerYuklenemedi")} />}

      {/* YUKLENIYOR: veri gelene kadar ekran BOS gorunuyordu ve kullanici
          "hic blok yok" saniyordu (tur 44 yavas-ag surusu). */}
      {(blocks.isLoading || units.isLoading) && (
        <p role="status" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("ortakYukleniyor")}
        </p>
      )}

      {/* Blok ekle/duzenle formu */}
      <Modal
        acik={blockForm.open}
        onKapat={() => setBlockForm(EMPTY_BLOCK)}
        baslik={blockForm.editingId ? t("binaBlokDuzenle") : t("binaBlokYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setBlockForm(EMPTY_BLOCK)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme type="submit" form="block" tur="birincil" disabled={blockForm.saving}>
              {blockForm.saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="block" onSubmit={saveBlock} className="space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:max-w-xs">
            <AlanSarmal etiket={t("binaBlokEtiketi")} ipucu={t("binaBlokIpucu")}>
  {(b) => (
    <Alan {...b} value={blockForm.ad}
                onChange={(e) => setBlockForm({ ...blockForm, ad: e.target.value })}
                pattern="[A-Za-z0-9]+"
                maxLength={8}
                title={t("blokGecersiz")}
                placeholder="A"
                required />
  )}
</AlanSarmal>
          </div>
          <HataDurumu mesaj={blockForm.err} />
        </form>
      </Modal>

      {/* Daire ekle/duzenle formu */}
      <Modal
        acik={unitForm.open}
        onKapat={() => setUnitForm(EMPTY_UNIT)}
        baslik={unitForm.editingId ? t("daireDuzenle") : t("daireYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setUnitForm(EMPTY_UNIT)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme type="submit" form="unit" tur="birincil" disabled={unitForm.saving}>
              {unitForm.saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="unit" onSubmit={saveUnit} className="space-y-4">
          {/* HANGI BLOK: eskiden basligin yanindaydi. `Modal.baslik` ekran
              okuyucu icin STRING; bilgi kaybolmasin diye govdenin basina
              alindi. */}
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {unitForm.blok
              ? t("daireBlokEki", { ad: unitForm.blok })
              : t("daireBloksuzEki")}
          </p>
          <div className="grid grid-cols-3 gap-4">
            <AlanSarmal etiket={t("binaDaireNo")} ipucu={t("binaDaireNoIpucu")}>
  {(b) => (
    <Alan {...b} value={unitForm.no}
                onChange={(e) => setUnitForm({ ...unitForm, no: e.target.value })}
                pattern="[A-Za-z0-9-]+"
                maxLength={50}
                title={t("binaDaireNoGecersiz")}
                placeholder="A-12"
                required />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("binaKat")} ipucu={t("binaZeminIpucu")}>
  {(b) => (
    <Alan {...b} inputMode="numeric"
                value={unitForm.kat}
                onChange={(e) => setUnitForm({ ...unitForm, kat: e.target.value })}
                placeholder="1" />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("binaSira")} ipucu={t("binaKattakiKonum")}>
  {(b) => (
    <Alan {...b} inputMode="numeric"
                value={unitForm.sira}
                onChange={(e) => setUnitForm({ ...unitForm, sira: e.target.value })}
                placeholder="1" />
  )}
</AlanSarmal>
          </div>
          <HataDurumu mesaj={unitForm.err} />
        </form>
      </Modal>

      {/* Icerik: kutucuk listesi veya blok detayi */}
      {drilledIn ? (
        <BlockDetail
          label={isBlockless ? BLOCKLESS : (openBlock as string)}
          units={isBlockless ? blocklessUnits : unitItems.filter((u) => u.blok === openBlock)}
          pendingFloors={pendingFloors}
          onSirala={(satirlar) => void siralamayiKaydet(satirlar)}
          yuklemeHatasi={Boolean(loadError)}
          onAddFloor={addFloor}
          onAddUnit={(kat) => openNewUnit(isBlockless ? null : (openBlock as string), kat)}
          onEditUnit={openEditUnit}
          onRemoveUnit={removeUnit}
        />
      ) : (
        <BlockTiles
          labels={labels}
          unitCountFor={(l) => unitItems.filter((u) => u.blok === l).length}
          registeredFor={(l) => blockByLabel(l) != null}
          blocklessCount={blocklessUnits.length}
          onOpen={openTile}
          onOpenBlockless={() => openTile(BLOCKLESS)}
          onEditBlock={(l) => { const b = blockByLabel(l); if (b) openEditBlock(b); }}
          onRemoveBlock={(l) => { const b = blockByLabel(l); if (b) removeBlock(b); }}
          onAddBlock={openNewBlock}
        />
      )}
      {diyalog}
    </div>
  );
}

// ---------------------------------------------------------------------------

function BlockTiles({
  labels, unitCountFor, registeredFor, blocklessCount,
  onOpen, onOpenBlockless, onEditBlock, onRemoveBlock, onAddBlock,
}: {
  labels: string[];
  unitCountFor: (label: string) => number;
  registeredFor: (label: string) => boolean;
  blocklessCount: number;
  onOpen: (label: string) => void;
  onOpenBlockless: () => void;
  onEditBlock: (label: string) => void;
  onRemoveBlock: (label: string) => void;
  onAddBlock: () => void;
}) {
  const t = useT();
  return (
    <div className="flex flex-wrap gap-3">
      {labels.map((label) => (
        <div
          key={label}
          className="relative flex h-32 w-40 flex-col rounded-xl border border-indigo-200 bg-indigo-50 p-3"
        >
          <button className="flex flex-1 flex-col items-center justify-center" onClick={() => onOpen(label)}>
            <span className="text-lg font-semibold text-indigo-900">
              {t("blokEtiketi", { ad: label })}
            </span>
            <span className="text-xs text-metin-body">
              {t("daireSayisiN", { n: unitCountFor(label) })}
            </span>
            {!registeredFor(label) && (
              <span className="mt-1 text-[10px] text-amber-600">{t("binaKayitsiz")}</span>
            )}
          </button>
          {registeredFor(label) && (
            <div className="flex justify-center gap-2">
              <button className="text-xs text-metin-body hover:underline" onClick={() => onEditBlock(label)}>
                {t("ortakDuzenle")}
              </button>
              <button className="text-xs text-red-700 hover:underline" onClick={() => onRemoveBlock(label)}>{t("ortakSil")}</button>
            </div>
          )}
        </div>
      ))}

      {/* t("daireBlokAtanmamis") kova: YALNIZ mevcut bloksuz daireler varken gorunur
          (goruntuleme + tasima/silme icin). Yeni daire buradan EKLENEMEZ —
          her yeni daire bir bloga baglanir (canli-site kurali). */}
      {blocklessCount > 0 && (
        <button
          onClick={onOpenBlockless}
          className="flex h-32 w-40 flex-col items-center justify-center rounded-xl border kart-kenar bg-yuzey-bg"
        >
          <span className="text-lg font-semibold text-metin-body">{t("daireBlokAtanmamis")}</span>
          <span className="text-xs text-metin-body">
            {t("daireSayisiN", { n: blocklessCount })}
          </span>
        </button>
      )}

      <button
        onClick={onAddBlock}
        className="flex h-32 w-40 flex-col items-center justify-center rounded-xl border border-dashed border-slate-300 bg-white text-metin-muted hover:bg-yuzey-bg"
      >
        <span className="text-3xl leading-none">+</span>
        <span className="text-sm">{t("binaBlokEkle")}</span>
      </button>
    </div>
  );
}

function BlockDetail({
  label, units, pendingFloors, yuklemeHatasi,
  onAddFloor, onAddUnit, onEditUnit, onRemoveUnit, onSirala,
}: {
  label: string;
  units: Unit[];
  /** (P61) Liste `data?.items ?? []`den turer: yukleme dustugunde de BOS
   *  gorunur. Bu bayrak olmadan "Kat yok" iddiasi hatayla CELISIRDI. */
  yuklemeHatasi: boolean;
  pendingFloors: number[];
  onAddFloor: () => void;
  onAddUnit: (kat?: number) => void;
  onEditUnit: (u: Unit) => void;
  onRemoveUnit: (u: Unit) => void;
  /** (P154 / Asama 5) Yeni yerlesim — TEK istekte kaydedilir. */
  onSirala: (satirlar: { id: string; kat: number; sira: number }[]) => void;
}) {
  const t = useT();
  const blockless = label === BLOCKLESS;
  // Suruklenen daire. Sayfa duzeyinde DEGIL blok detayinda: surukleme
  // yalniz ayni blogun katlari arasinda anlamli (daireyi baska bloga
  // tasimak `no` degistirmeyi gerektirir, o AYRI bir is).
  const [suruklenen, setSuruklenen] = useState<Unit | null>(null);

  const floorSet = new Set<number>(pendingFloors);
  for (const u of units) if (u.kat != null) floorSet.add(u.kat);
  const floors = [...floorSet].sort((a, b) => b - a); // ust kat yukarida
  const katsiz = units.filter((u) => u.kat == null);

  const bySira = (a: Unit, b: Unit) => (a.sira ?? 1e9) - (b.sira ?? 1e9) || a.no.localeCompare(b.no);

  /**
   * `tasinan`i `hedefKat`in `hedefIndeks`ine koyar ve ETKILENEN
   * KATLARIN TAMAMINI 1..n yeniden numaralandirir.
   *
   * NEDEN TUM KAT: yalnizca iki daireyi takas etmek, arada bosluk ya da
   * cift `sira` birakabilirdi (veri zaten bosluklu gelebiliyor —
   * `sira` NULL olabilir). Yeniden numaralandirma, gorulen duzen ile
   * saklanan duzeni AYNI kilar.
   */
  function yerlesimHesapla(
    tasinan: Unit, hedefKat: number, hedefIndeks: number,
  ): { id: string; kat: number; sira: number }[] {
    const kaynakKat = tasinan.kat;
    const katUnits = (k: number) =>
      units.filter((u) => u.kat === k && u.id !== tasinan.id).sort(bySira);

    const hedef = katUnits(hedefKat);
    hedef.splice(Math.max(0, Math.min(hedefIndeks, hedef.length)), 0, tasinan);

    const sonuc = hedef.map((u, i) => ({ id: u.id, kat: hedefKat, sira: i + 1 }));
    if (kaynakKat != null && kaynakKat !== hedefKat) {
      sonuc.push(
        ...katUnits(kaynakKat).map((u, i) => ({
          id: u.id, kat: kaynakKat, sira: i + 1,
        })),
      );
    }
    return sonuc;
  }

  /** Klavye esdegeri — bkz. `DaireKutusu` icindeki gerekce. */
  function klavyeTasi(u: Unit, yon: "sol" | "sag" | "yukari" | "asagi") {
    if (u.kat == null) return;
    const ayni = units.filter((x) => x.kat === u.kat).sort(bySira);
    const i = ayni.findIndex((x) => x.id === u.id);
    if (yon === "sol" || yon === "sag") {
      const yeni = yon === "sol" ? i - 1 : i + 1;
      if (yeni < 0 || yeni >= ayni.length) return;
      onSirala(yerlesimHesapla(u, u.kat, yeni));
      return;
    }
    // Kat listesi USTTEN ALTA sirali (buyuk kat once): "yukari" kat NO'sunu
    // ARTIRIR. Ekranda gordugu yonle veri ayni yone gitmeli.
    const hedefKat = yon === "yukari" ? u.kat + 1 : u.kat - 1;
    if (!floorSet.has(hedefKat)) return;
    onSirala(yerlesimHesapla(u, hedefKat, Number.MAX_SAFE_INTEGER));
  }

  return (
    <Kart className="space-y-3">
      <div className="flex items-center justify-between">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{blockless ? t("binaBloksuzDaireler") : `Blok ${label}`}</h2>
        {/* Bloksuz kovaya yeni daire EKLENMEZ (her daire bir bloga baglanir). */}
        {!blockless && (
          <Dugme boy="kucuk" onClick={onAddFloor}>{t("binaKatEkleKisa")}</Dugme>
        )}
      </div>

      {blockless && (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-700">
          {t("binaBloksuzNot")}
        </p>
      )}

      {/* (P61) `!loadError` SART: kat listesi `data?.items ?? []`den
          turer, yani istek dustugunde de BOS gorunur ve sayfa "Kat yok"
          derdi — hemen ustundeki "Veriler yuklenemedi" kutusuyla
          celiserek. */}
      {!yuklemeHatasi && !blockless && floors.length === 0 && katsiz.length === 0 && (
        <p className="py-6 text-center text-sm text-metin-muted">
          {t("binaKatYok")}
        </p>
      )}

      {floors.map((kat) => (
        <FloorRow
          key={kat}
          katLabel={`Kat ${kat}`}
          units={units.filter((u) => u.kat === kat).sort(bySira)}
          canAdd={!blockless}
          onAddUnit={() => onAddUnit(kat)}
          onEditUnit={onEditUnit}
          onRemoveUnit={onRemoveUnit}
          suruklenen={suruklenen}
          setSuruklenen={setSuruklenen}
          onBirak={(indeks) => {
            if (suruklenen) onSirala(yerlesimHesapla(suruklenen, kat, indeks));
            setSuruklenen(null);
          }}
          onKlavye={klavyeTasi}
        />
      ))}

      {/* KATSIZ SATIRDA SURUKLEME YOK: kat bilinmeden siralama anlamsizdir
          ve `PATCH /units/siralama` `kat` zorunlu ister. Kullanici once
          daireye bir kat verir. */}
      {katsiz.length > 0 && (
        <FloorRow
          katLabel="Kat yok"
          units={[...katsiz].sort(bySira)}
          canAdd={!blockless}
          onAddUnit={() => onAddUnit()}
          onEditUnit={onEditUnit}
          onRemoveUnit={onRemoveUnit}
        />
      )}
    </Kart>
  );
}

function FloorRow({
  katLabel, units, canAdd, onAddUnit, onEditUnit, onRemoveUnit,
  suruklenen, setSuruklenen, onBirak, onKlavye,
}: {
  katLabel: string;
  units: Unit[];
  canAdd: boolean;
  onAddUnit: () => void;
  onEditUnit: (u: Unit) => void;
  onRemoveUnit: (u: Unit) => void;
  suruklenen?: Unit | null;
  setSuruklenen?: (u: Unit | null) => void;
  /** Hedef indekse birakildi. Verilmezse SURUKLEME KAPALI (katsiz satir). */
  onBirak?: (indeks: number) => void;
  onKlavye?: (u: Unit, yon: "sol" | "sag" | "yukari" | "asagi") => void;
}) {
  const t = useT();
  const surukleAcik = Boolean(onBirak);
  return (
    <div
      className="flex items-start gap-3 border-t border-yuzey-divider pt-3"
      onDragOver={surukleAcik ? (e) => e.preventDefault() : undefined}
      // Satirin BOSLUGUNA birakmak SONA ekler: kullanici bir daireyi
      // katin sonuna tasimak istediginde son kutuya nisan almak zorunda
      // kalmamali.
      onDrop={surukleAcik ? () => onBirak?.(units.length) : undefined}
    >
      <span className="w-16 shrink-0 pt-3 text-xs font-medium text-metin-muted">{katLabel}</span>
      <div className="flex flex-wrap gap-2">
        {units.map((u, indeks) => (
          <div
            key={u.id}
            draggable={surukleAcik}
            onDragStart={() => setSuruklenen?.(u)}
            onDragEnd={() => setSuruklenen?.(null)}
            onDragOver={surukleAcik ? (e) => e.preventDefault() : undefined}
            onDrop={
              surukleAcik
                ? (e) => {
                    e.stopPropagation();
                    onBirak?.(indeks);
                  }
                : undefined
            }
            // (P154 / Asama 5) KLAVYE ESDEGERI — SURUKLE-BIRAK TEK YOL
            // DEGIL.
            //
            // Fare suruklemesi klavyeyle ERISILEMEZ ve brief'in kendi
            // sarti "klavye navigasyonu" diyor. Alt+Ok, ayni isi yapar:
            // sol/sag kat icinde, yukari/asagi kat degistirir. `Alt`
            // secildi cunku ciplak ok tuslari sayfayi kaydirir ve
            // odaklanmis bir kutuda kaydirmayi yutmak, klavye
            // kullanicisini sayfada hapsederdi.
            tabIndex={surukleAcik ? 0 : undefined}
            onKeyDown={
              surukleAcik
                ? (e) => {
                    if (!e.altKey) return;
                    const yon = {
                      ArrowLeft: "sol", ArrowRight: "sag",
                      ArrowUp: "yukari", ArrowDown: "asagi",
                    }[e.key] as "sol" | "sag" | "yukari" | "asagi" | undefined;
                    if (!yon) return;
                    e.preventDefault();
                    onKlavye?.(u, yon);
                  }
                : undefined
            }
            aria-label={
              surukleAcik
                ? t("binaDaireTasiEtiket", { no: u.no, kat: katLabel })
                : undefined
            }
            // (P122) TIP RENGI YALNIZ AKTIF dairede: pasif daire her tipte
            // ayni soluk grivi tasimali, yoksa "pasif" durumu renk
            // gurultusunde kaybolur.
            style={u.aktif ? { backgroundColor: daireTipiRengi(u.unit_tip_ad) } : undefined}
            // Gorsel kisaltma ekran okuyucuya TAM adi vermeli.
            title={[u.no, u.unit_tip_ad, u.sira != null ? `#${u.sira}` : null]
              .filter(Boolean)
              .join(" · ")}
            className={`odak-ic group relative flex h-16 w-20 flex-col items-center justify-center rounded-lg border text-white ${
              u.aktif ? "border-black/20" : "border-slate-400 bg-slate-400"
            } ${suruklenen?.id === u.id ? "opacity-50" : ""} ${
              surukleAcik ? "cursor-move" : ""
            }`}
          >
            <span className="text-sm font-semibold">{u.no}</span>
            {/* (P122) TIP, SIRADAN ONCELIKLIDIR. Hucre 64 px yuksektir;
                ucuncu bir satir tasar. Tip atanmissa kullanici icin degerli
                olan odur ("12 · 2+1"); sira yalnizca yerlesim ayrintisidir
                ve tip yokken gosterilir. */}
            {/* (Duzeltme) TIP HER ZAMAN GORUNUR: atanmamissa "-".
                Eskiden tip yokken hucre sessizce `#sira` gosteriyordu ve
                kullanici "tip mi yok, sira mi?" diye ayirt edemiyordu.
                Sira bilgisi KAYBOLMADI - ipucuna (title) tasindi. */}
            {u.aktif ? (
              <span
                data-testid="daire-tip-etiketi"
                className="max-w-[72px] truncate text-[10px] font-semibold opacity-95"
              >
                {u.unit_tip_ad ? daireTipiKisa(u.unit_tip_ad) : "—"}
              </span>
            ) : null}
            <div className="absolute inset-x-0 bottom-0 hidden justify-center gap-2 rounded-b-lg bg-black/40 py-0.5 text-[10px] group-hover:flex">
              <button className="hover:underline" onClick={() => onEditUnit(u)}>{t("binaDuzenleKucuk")}</button>
              <button className="hover:underline" onClick={() => onRemoveUnit(u)}>{t("ortakSil")}</button>
            </div>
          </div>
        ))}
        {canAdd && (
          <button
            onClick={onAddUnit}
            className="flex h-16 w-20 items-center justify-center rounded-lg border border-dashed border-slate-300 bg-yuzey-bg text-2xl text-metin-muted hover:bg-slate-100"
          >
            +
          </button>
        )}
      </div>
    </div>
  );
}
