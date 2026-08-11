"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, btnDanger, panelCls, panelMotion } from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { useToast } from "@/components/Toast";
import { UnitDetail } from "@/components/UnitDetail";
import { BagimlilikUyarisi } from "@/components/BagimlilikUyarisi";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { aralikCoz } from "@/lib/aralik";
import { Modal, ModalEylemler } from "@/components/Modal";
import { sayiBicimi, sayiCoz, tamsayiCoz } from "@/lib/sayi";
import type { Unit, UnitList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

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

export default function UnitsPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
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
      setOHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
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
    if (!window.confirm(t("daireKatSilOnay", { kat: kat.deger, blok }))) return;
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
    `/api/units?limit=${LIMIT}&offset=${offset}${blokQs}`,
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
    if (!window.confirm(t("ortakSilOnay", { ad: u.no }))) return;
    try {
      await apiSend(`/api/units/${u.id}`, "DELETE");
      if (detail?.id === u.id) setDetail(null);
      mutate();
      toast.success(t("daireSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukDaireler")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("daireYeni")}</button>
        }
      />

      <BagimlilikUyarisi
        kod="blok"
        eksik={(bloklar?.items?.length ?? 1) === 0}
      />

      <div className="flex items-end gap-2">
        <div className="w-full sm:w-48">
          <Field label={t("daireBlokFiltresi")}>
            <input
              className={inputCls}
              value={blok}
              onChange={(e) => {
                setBlok(e.target.value);
                setOffset(0);
              }}
              placeholder="A"
            />
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("daireDuzenle") : t("daireYeni")}</h2>
          <div className="grid grid-cols-3 gap-4">
            <Field label={t("binaDaireNo")} hint={t("daireNoIpucu")}>
              <input
                className={inputCls}
                value={form.no}
                onChange={(e) => setForm({ ...form, no: e.target.value })}
                placeholder="A-12"
                pattern="[A-Za-z0-9-]+"
                title={t("daireNoGecersiz")}
                required
              />
            </Field>
            <Field label={t("ortakBlok")} hint={t("blokIpucu")}>
              <input
                className={inputCls}
                value={form.blok}
                onChange={(e) => setForm({ ...form, blok: e.target.value })}
                pattern="[A-Za-z0-9]+"
                maxLength={8}
                title={t("blokGecersiz")}
                placeholder="A"
                required
              />
            </Field>
            <Field label={t("daireMetrekareOpsiyonel")}>
              <input
                className={inputCls}
                inputMode="decimal"
                value={form.metrekare}
                onChange={(e) => setForm({ ...form, metrekare: e.target.value })}
              />
            </Field>
            <Field label={t("daireKatOpsiyonel")} hint={t("katIpucu")}>
              <input
                className={inputCls}
                inputMode="numeric"
                value={form.kat}
                onChange={(e) => setForm({ ...form, kat: e.target.value })}
                placeholder="1"
              />
            </Field>
            <Field label={t("siraOpsiyonel")} hint={t("siraIpucu")}>
              <input
                className={inputCls}
                inputMode="numeric"
                value={form.sira}
                onChange={(e) => setForm({ ...form, sira: e.target.value })}
                placeholder="2"
              />
            </Field>
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />
            {t("ortakAktif")}
          </label>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              {t("ortakIptal")}
            </button>
          </div>
        </motion.form>
      )}

      {/* (P154 / Asama 5) TOPLU ISLEM SERIDI. Aralik ifadesi EKRANDAKI
          listeye uygulanir; blok suzgeci acikken "7-12" o blogun
          daireleridir (bkz. `lib/aralik.ts`). */}
      <section className="flex flex-wrap items-end gap-2">
        <div className="w-full sm:w-56">
          <Field label={t("daireAralikSec")} hint={t("daireAralikIpucu")}>
            <input
              className={inputCls}
              value={aralikIfade}
              onChange={(e) => setAralikIfade(e.target.value)}
              placeholder="3,5,7-12"
            />
          </Field>
        </div>
        <button type="button" className={btnGhost} onClick={araligiUygula}>
          {t("daireAralikUygula")}
        </button>
        <button type="button" className={btnGhost} onClick={() => setOAcik(true)}>
          {t("daireTopluOlustur")}
        </button>
        <button
          type="button"
          className={btnPrimary}
          disabled={secili.length === 0}
          onClick={() => setTopluAcik(true)}
        >
          {t("daireTopluDegistir", { adet: secili.length })}
        </button>
        <div className="w-full sm:w-32">
          <Field label={t("daireKatSil")}>
            <input
              className={inputCls}
              value={katSilKat}
              onChange={(e) => setKatSilKat(e.target.value)}
              placeholder="1"
            />
          </Field>
        </div>
        <button
          type="button"
          className={btnDanger}
          disabled={!blok}
          onClick={() => void katSil()}
        >
          {t("daireKatSil")}
        </button>
      </section>
      <ErrorBox message={topluHata} />

      <TabloKart>
        <Tablo>
          <TabloBasligi>
            <Th>
              {/* Basliktaki kutu GORUNEN sayfayi secer — tum kayitlari
                  degil. "Hepsini sec" deyip 20 kayit isleyip 500 kaydin
                  islendigini sanmak en kotu sonuctur. */}
              <input
                type="checkbox"
                aria-label={t("daireHepsiniSec")}
                checked={
                  (data?.items ?? []).length > 0 &&
                  secili.length === (data?.items ?? []).length
                }
                onChange={(e) =>
                  setSecili(e.target.checked ? (data?.items ?? []).map((u) => u.id) : [])
                }
              />
            </Th>
            <Th>{t("daireNoKisa")}</Th>
            <Th>{t("ortakBlok")}</Th>
            {/* (Duzeltme) DAIRE TIPI (P26) listede HIC gosterilmiyordu.
                `unit_tip_ad` API'den ZATEN geliyordu - sayfa okumuyordu.
                Blok'un yaninda: ikisi de dairenin "nerede/ne" bilgisi. */}
            <Th>{t("tanimAlanTip")}</Th>
            <Th>{t("daireKatSira")}</Th>
            <Th>m²</Th>
            <Th>{t("ortakDurum")}</Th>
            <Th />
          </TabloBasligi>
            <tbody>
              {(data?.items ?? []).map((u) => (
                <Tr key={u.id}>
                  <Td>
                    <input
                      type="checkbox"
                      aria-label={t("daireSatirSec", { no: u.no })}
                      checked={secili.includes(u.id)}
                      onChange={(e) =>
                        setSecili((s) =>
                          e.target.checked
                            ? [...s, u.id]
                            : s.filter((x) => x !== u.id),
                        )
                      }
                    />
                  </Td>
                  <Td>{u.no}</Td>
                  <Td className="text-metin-body">{u.blok ?? t("daireBlokAtanmamis")}</Td>
                  {/* Tip ATANMAMISSA "-": bos hucre "veri gelmedi mi?"
                      sorusunu uretir, tire "atanmamis" der. */}
                  <Td className="text-metin-body">{u.unit_tip_ad ?? "—"}</Td>
                  <Td sayi className="text-metin-body">
                    {u.kat != null || u.sira != null ? `${u.kat ?? "—"} / ${u.sira ?? "—"}` : "—"}
                  </Td>
                  <Td sayi className="text-metin-body">{sayiBicimi(u.metrekare)}</Td>
                  <Td>
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        u.aktif ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-metin-body"
                      }`}
                    >
                      {u.aktif ? t("ortakAktif") : t("ortakPasif")}
                    </span>
                  </Td>
                  <Td hizala="end">
                    <div className="flex justify-end gap-2">
                      <button
                        className={btnGhost}
                        onClick={() => setDetail(detail?.id === u.id ? null : u)}
                      >
                        {detail?.id === u.id ? t("ortakKapat") : t("daireDetayAidat")}
                      </button>
                      <button className={btnGhost} onClick={() => openEdit(u)}>
                        {t("ortakDuzenle")}
                      </button>
                      <button className={btnDanger} onClick={() => remove(u)}>
                        {t("ortakSil")}
                      </button>
                    </div>
                  </Td>
                </Tr>
              ))}
              {data && data.items.length === 0 && (
                <BosSatir sutun={7}>
                  <EmptyState title={t("daireYok")} description={t("daireYokAlt")} />
                </BosSatir>
              )}
            </tbody>
        </Tablo>
      </TabloKart>

      {detail && <UnitDetail unit={detail} />}

      <Modal
        baslik={t("daireTopluOlustur")}
        acik={oAcik}
        kapat={() => setOAcik(false)}
        kirli={oBlok !== ""}
      >
        <div className="space-y-3">
          <ErrorBox message={oHata} />
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label={t("ortakBlok")}>
              <input className={inputCls} value={oBlok}
                     onChange={(e) => setOBlok(e.target.value)} />
            </Field>
            <Field label={t("daireKatSayisi")}>
              <input className={inputCls} value={oKat}
                     onChange={(e) => setOKat(e.target.value)} />
            </Field>
            <Field label={t("daireKatBasi")}>
              <input className={inputCls} value={oDaire}
                     onChange={(e) => setODaire(e.target.value)} />
            </Field>
            <Field label={t("daireBaslangicNo")}>
              <input className={inputCls} value={oBaslangicNo}
                     onChange={(e) => setOBaslangicNo(e.target.value)} />
            </Field>
            {/* (P154 / Asama 5) BASLANGIC KATI: bodrum ve zemin gercek
                katlardir. "Zemin" ayri bir DEGER degil 0'dir — metin bir
                kat numarasi siralanamaz. */}
            <Field label={t("daireBaslangicKat")} hint={t("daireBaslangicKatIpucu")}>
              <input className={inputCls} value={oBaslangicKat}
                     onChange={(e) => setOBaslangicKat(e.target.value)} />
            </Field>
            <Field label={t("tanimAlanTip")}>
              <select className={inputCls} value={oTip}
                      onChange={(e) => setOTip(e.target.value)}>
                <option value="">—</option>
                {(tipler?.items ?? []).map((x) => (
                  <option key={x.id} value={x.id}>{x.ad}</option>
                ))}
              </select>
            </Field>
          </div>
          <ModalEylemler
            iptal={() => setOAcik(false)}
            kaydet={() => void topluOlustur()}
          />
        </div>
      </Modal>

      <Modal
        baslik={t("daireTopluBaslik")}
        acik={topluAcik}
        kapat={() => setTopluAcik(false)}
      >
        <div className="space-y-3">
          <p className="text-sm text-metin-muted">
            {t("daireTopluSecili", { adet: secili.length })}
          </p>
          <Field label={t("ortakDurum")}>
            <select
              className={inputCls}
              value={topluAktif}
              onChange={(e) => setTopluAktif(e.target.value)}
            >
              <option value="">{t("daireTopluDegistirme")}</option>
              <option value="1">{t("ortakAktif")}</option>
              <option value="0">{t("ortakPasif")}</option>
            </select>
          </Field>
          {/* (P154 / Asama 5) DAIRE TIPI DEGISTIRME — brief: "Web'de daire
              tipi degistirme eklensin". Tekil PATCH zaten vardi ama
              arayuzde hicbir yerde acik degildi. */}
          <Field label={t("tanimAlanTip")}>
            <select
              className={inputCls}
              value={topluTip}
              onChange={(e) => setTopluTip(e.target.value)}
            >
              <option value="">{t("daireTopluDegistirme")}</option>
              {(tipler?.items ?? []).map((x) => (
                <option key={x.id} value={x.id}>{x.ad}</option>
              ))}
            </select>
          </Field>
          <ModalEylemler
            iptal={() => setTopluAcik(false)}
            kaydet={() => void topluGuncelle()}
          />
        </div>
      </Modal>

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
