"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  btnGhost,
  btnPrimary,
  inputCls,
  panelCls,
  panelMotion,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";
import { sayiBicimi, sayiCoz } from "@/lib/sayi";

/**
 * (P111) SAYAC OKUMA SIHIRBAZI — dort adim, TEK istek.
 *
 * SUNUCUNUN SOZLESMESI BELIRLEYICI: `SayacBorcIstek` docstring'i
 * "ilk uc adim ISTEMCIDE toplanir, sunucuya TEK istek gelir" der ve
 * gerekcesini de yazar — ara adimlarda sunucu durumu tutmak, yarim
 * kalmis sihirbazlari temizlemek zorunda birakirdi. Bu sayfa o
 * sozlesmenin istemci tarafidir: adimlar arasinda HICBIR ag istegi
 * yazmaz; yalniz LISTELERI okur (kalemler, ana sayaclar, daire
 * sayaclari) ve son adimda `POST /borclandirma/sayac` atar.
 *
 * NEDEN AYRI SAYFA (Tanimlar sekmesi degil): Tanimlar bir KAYIT
 * DEFTERIDIR (kur, birak); bu ise donemsel bir IS AKISIDIR ve her ay
 * tekrarlanir. Sekme icine gomulmus dort adimli bir akis, defterin
 * "yeni kayit" duzenini de bozardi.
 */

type Kayit = Record<string, unknown>;

/**
 * Sunucunun dagitim kurali (`sayac_tuketim_dagitimi`) ile AYNI hesap —
 * yalniz ONIZLEME icin. Tek kaynak sunucudur; burada hesaplanan tutar
 * hicbir zaman gonderilmez, sadece kullaniciya gosterilir.
 *
 * UC KURAL, SUNUCUDAN BIREBIR:
 *   * Fark (ana − daireler toplami) ORTAK tuketimdir (kacak, ortak alan,
 *     olcum farki).
 *   * NEGATIF fark SIFIRLANIR — dairelere negatif borc yazmak alacak
 *     uretirdi.
 *   * `ortak_alan_yuzde` verilmisse farkin YALNIZ o yuzdesi dagitilir.
 *     Bunu atlayip her zaman ana sayaci esas almak, yuzde kullanan
 *     sitelerde onizlemeyi OLDUGUNDAN BUYUK gosterirdi.
 */
function onizlemeTutar(
  anaTuketim: number,
  bolumToplam: number,
  birimFiyatKurus: number,
  ortakAlanYuzde: number | null,
): number {
  const hamFark = Math.max(anaTuketim - bolumToplam, 0);
  const fark = ortakAlanYuzde === null ? hamFark : (hamFark * ortakAlanYuzde) / 100;
  return Math.round((bolumToplam + fark) * birimFiyatKurus);
}

const DONEM_BICIMI = /^\d{4}-\d{2}$/;

export default function SayacOkumaPage() {
  const t = useT();
  const toast = useToast();

  const [adim, setAdim] = useState(0);
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);

  // --- adim 1 ---
  const [kalemId, setKalemId] = useState("");
  // --- adim 2 ---
  const [anaId, setAnaId] = useState("");
  const [donem, setDonem] = useState("");
  const [anaTuketim, setAnaTuketim] = useState("");
  const [birimFiyat, setBirimFiyat] = useState("");
  // --- adim 3 ---
  const [tuketimler, setTuketimler] = useState<Record<string, string>>({});
  // --- adim 4 ---
  const [sonOdeme, setSonOdeme] = useState("");
  const [aciklama, setAciklama] = useState("");

  const { data: kalemVerisi } = useSWR<{ items: Kayit[] }>(
    "/api/tanimlar/gelir-gider-tanimlari?limit=200",
    jsonFetcher,
  );
  const { data: anaVerisi } = useSWR<{ items: Kayit[] }>(
    "/api/tanimlar/sayaclar-ana?limit=200",
    jsonFetcher,
  );
  // Daire sayaclari YALNIZ ana sayac secilince cekilir: secim yokken
  // butun sitenin sayaclarini indirmek anlamsiz bir istek olurdu.
  const { data: bolumVerisi, isLoading: bolumYukleniyor } = useSWR<{
    items: Kayit[];
  }>(
    anaId ? `/api/tanimlar/sayaclar-bolum?ana_sayac_id=${anaId}&limit=200` : null,
    jsonFetcher,
  );

  const kalemler = kalemVerisi?.items ?? [];
  const anaSayaclar = anaVerisi?.items ?? [];
  const bolumler = bolumVerisi?.items ?? [];

  const anaSayiSayisal = sayiCoz(anaTuketim);
  const anaDeger = anaSayiSayisal.tur === "sayi" ? anaSayiSayisal.deger : 0;
  const birimKurus = tlToKurus(birimFiyat) ?? 0;
  const bolumToplam = bolumler.reduce((top, b) => {
    const s = sayiCoz(tuketimler[String(b.id)] ?? "");
    return top + (s.tur === "sayi" ? s.deger : 0);
  }, 0);
  const fark = anaDeger - bolumToplam;
  // Secili ana sayacin ortak alan yuzdesi — onizleme sunucunun kuralini
  // AYNEN uygulasin diye okunur (null = farkin TAMAMI dagitilir).
  const seciliAna = anaSayaclar.find((s) => String(s.id) === anaId);
  const ortakYuzde =
    typeof seciliAna?.ortak_alan_yuzde === "number"
      ? seciliAna.ortak_alan_yuzde
      : null;

  /** Adim gecisi: ILERI derken o adimin kurallari uygulanir. Butun
   *  dogrulamayi son adima birakmak, kullaniciyi uc adim geri
   *  gondermek demekti. */
  function ileri() {
    if (adim === 0 && !kalemId) return setHata(t("sayacKalemSec"));
    if (adim === 1) {
      if (!anaId) return setHata(t("sayacAnaSayacSec"));
      if (!DONEM_BICIMI.test(donem.trim())) {
        return setHata(t("sayacDonemGecersiz"));
      }
      if (anaSayiSayisal.tur !== "sayi") {
        return setHata(t("sayacAnaTuketimGecersiz"));
      }
      if (tlToKurus(birimFiyat) === null || birimKurus < 1) {
        return setHata(t("sayacBirimFiyatGecersiz"));
      }
    }
    if (adim === 2) {
      for (const b of bolumler) {
        const s = sayiCoz(tuketimler[String(b.id)] ?? "");
        if (s.tur !== "sayi") {
          return setHata(
            t("sayacTuketimGecersiz", {
              daire: String(b.unit_no ?? b.id),
            }),
          );
        }
      }
    }
    setHata(null);
    setAdim(adim + 1);
  }

  async function borclandir() {
    const govde: Record<string, unknown> = {
      donem: donem.trim(),
      gelir_gider_tanim_id: kalemId,
      ana_sayac_id: anaId,
      ana_tuketim: anaDeger,
      birim_fiyat_kurus: birimKurus,
      bolum_tuketimleri: Object.fromEntries(
        bolumler.map((b) => {
          const s = sayiCoz(tuketimler[String(b.id)] ?? "");
          return [String(b.id), s.tur === "sayi" ? s.deger : 0];
        }),
      ),
      // BOS = "yok": "" gondermek sunucunun tarih dogrulamasina takilirdi.
      son_odeme_tarihi: sonOdeme.trim() === "" ? null : sonOdeme.trim(),
      aciklama: aciklama.trim() === "" ? null : aciklama.trim(),
    };
    setGonderiyor(true);
    try {
      const sonuc = (await apiSend("/api/borclandirma/sayac", "POST", govde)) as {
        atlanan?: number;
      };
      toast.success(
        t("sayacSonuc", { atlanan: String(sonuc?.atlanan ?? 0) }),
      );
      setHata(null);
      // Sihirbaz BASA DONER: ayni donemi yanlislikla iki kez
      // borclandirmak, ekranda hazir duran formla bir tiklama uzakta olurdu.
      setAdim(0);
      setTuketimler({});
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setGonderiyor(false);
    }
  }

  const adimBasliklari = [
    t("sayacAdimKalem"),
    t("sayacAdimAnaSayac"),
    t("sayacAdimTuketim"),
    t("sayacAdimOzet"),
  ];

  return (
    <div className="space-y-4">
      <PageHeader title={t("kabukSayacOkuma")} />
      <p className="text-sm opacity-70">{t("sayacSihirbazNotu")}</p>

      <div className="flex flex-wrap gap-2">
        {adimBasliklari.map((baslik, i) => (
          <span
            key={baslik}
            className={
              i === adim
                ? "rounded-lg bg-brand-tealInk px-3 py-1.5 text-sm text-white"
                : "rounded-lg border border-slate-300 px-3 py-1.5 text-sm opacity-70"
            }
          >
            {baslik}
          </span>
        ))}
      </div>

      <motion.div {...panelMotion} className={panelCls}>
        <ErrorBox message={hata} />

        {adim === 0 ? (
          <Field label={t("sayacAlanKalem")}>
            <select
              aria-label={t("sayacAlanKalem")}
              className={inputCls}
              value={kalemId}
              onChange={(e) => setKalemId(e.target.value)}
            >
              <option value="">—</option>
              {kalemler.map((k) => (
                <option key={String(k.id)} value={String(k.id)}>
                  {String(k.ad ?? k.id)}
                </option>
              ))}
            </select>
          </Field>
        ) : null}

        {adim === 1 ? (
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label={t("sayacAlanAnaSayac")}>
              <select
                aria-label={t("sayacAlanAnaSayac")}
                className={inputCls}
                value={anaId}
                onChange={(e) => setAnaId(e.target.value)}
              >
                <option value="">—</option>
                {anaSayaclar.map((s) => (
                  <option key={String(s.id)} value={String(s.id)}>
                    {String(s.ad ?? s.id)}
                  </option>
                ))}
              </select>
            </Field>
            <Field label={t("ortakDonem")}>
              <input
                aria-label={t("ortakDonem")}
                className={inputCls}
                placeholder="2026-08"
                value={donem}
                onChange={(e) => setDonem(e.target.value)}
              />
            </Field>
            <Field label={t("sayacAlanAnaTuketim")}>
              <input
                aria-label={t("sayacAlanAnaTuketim")}
                className={inputCls}
                inputMode="decimal"
                value={anaTuketim}
                onChange={(e) => setAnaTuketim(e.target.value)}
              />
            </Field>
            <Field label={t("sayacAlanBirimFiyat")}>
              <input
                aria-label={t("sayacAlanBirimFiyat")}
                className={inputCls}
                inputMode="decimal"
                value={birimFiyat}
                onChange={(e) => setBirimFiyat(e.target.value)}
              />
            </Field>
          </div>
        ) : null}

        {adim === 2 ? (
          bolumYukleniyor ? (
            <p>{t("ortakYukleniyor")}</p>
          ) : bolumler.length === 0 ? (
            // BOS LISTE SESSIZ GECILMEZ: bos bir 3. adimdan "ileri" demek,
            // hicbir daireyi borclandirmayan bir istek atmak olurdu.
            <EmptyState title={t("sayacBolumYok")} />
          ) : (
            <div className="space-y-2">
              {bolumler.map((b) => (
                <Field key={String(b.id)} label={String(b.unit_no ?? b.id)}>
                  <input
                    aria-label={String(b.unit_no ?? b.id)}
                    className={inputCls}
                    inputMode="decimal"
                    value={tuketimler[String(b.id)] ?? ""}
                    onChange={(e) =>
                      setTuketimler({
                        ...tuketimler,
                        [String(b.id)]: e.target.value,
                      })
                    }
                  />
                </Field>
              ))}
            </div>
          )
        ) : null}

        {adim === 3 ? (
          <div className="space-y-3">
            <dl className="grid gap-2 sm:grid-cols-2">
              <div>
                <dt className="text-sm opacity-70">{t("sayacAlanAnaTuketim")}</dt>
                <dd>{sayiBicimi(anaDeger)}</dd>
              </div>
              <div>
                <dt className="text-sm opacity-70">{t("sayacToplamTuketim")}</dt>
                <dd>{sayiBicimi(bolumToplam)}</dd>
              </div>
              <div>
                <dt className="text-sm opacity-70">{t("sayacOrtakAlanFarki")}</dt>
                <dd>{sayiBicimi(fark)}</dd>
              </div>
              <div>
                <dt className="text-sm opacity-70">{t("sayacTahminiTutar")}</dt>
                <dd>
                  {kurusToTL(
                    onizlemeTutar(anaDeger, bolumToplam, birimKurus, ortakYuzde),
                  )}
                </dd>
              </div>
            </dl>
            {/* Fark NEGATIFSE ortak alan payi hesaplanamaz — sunucu da
                boyle davranir; kullanici bunu GONDERMEDEN once gormeli. */}
            {fark < 0 ? <ErrorBox message={t("sayacFarkUyarisi")} /> : null}
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label={t("sayacAlanSonOdeme")}>
                <input
                  aria-label={t("sayacAlanSonOdeme")}
                  className={inputCls}
                  type="date"
                  value={sonOdeme}
                  onChange={(e) => setSonOdeme(e.target.value)}
                />
              </Field>
              <Field label={t("ortakAciklamaOpsiyonel")}>
                <input
                  aria-label={t("ortakAciklamaOpsiyonel")}
                  className={inputCls}
                  value={aciklama}
                  onChange={(e) => setAciklama(e.target.value)}
                />
              </Field>
            </div>
          </div>
        ) : null}

        <div className="mt-4 flex gap-2">
          {adim > 0 ? (
            <button
              type="button"
              className={btnGhost}
              onClick={() => {
                setHata(null);
                setAdim(adim - 1);
              }}
            >
              {t("sayacGeri")}
            </button>
          ) : null}
          {adim < 3 ? (
            <button type="button" className={btnPrimary} onClick={ileri}>
              {t("sayacIleri")}
            </button>
          ) : (
            <button
              type="button"
              className={btnPrimary}
              disabled={gonderiyor || bolumler.length === 0}
              onClick={() => void borclandir()}
            >
              {gonderiyor ? t("sayacBorclandiriliyor") : t("sayacBorclandir")}
            </button>
          )}
        </div>
      </motion.div>
    </div>
  );
}
