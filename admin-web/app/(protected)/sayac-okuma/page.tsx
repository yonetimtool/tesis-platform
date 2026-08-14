"use client";

import { useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  IskeletMetin,
  Kart,
  Secim,
} from "@/components/ui";
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
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const ADIM = "step" as const;

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
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kabukSayacOkuma")}
      </h1>
      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("sayacSihirbazNotu")}
      </p>

      {/* ADIM SERIDI. (P160) Aktif adim eskiden YALNIZ RENKLE belliydi:
          ekran okuyucu dort etiketi ust uste okuyor, hangisinde
          olundugunu SOYLEMIYORDU. `aria-current="step"` o bilgiyi
          tasir; sira numarasi da `<ol>` ile yapisal hale geldi. */}
      <ol className="flex flex-wrap gap-2">
        {adimBasliklari.map((baslik, i) => (
          <li
            key={baslik}
            aria-current={i === adim ? ADIM : undefined}
            className={i === adim ? "yz-raised" : ""}
            style={{
              borderRadius: "var(--yz-r-md)",
              padding: "0.375rem 0.75rem",
              fontSize: "var(--yz-fs-sm)",
              border: i === adim ? "none" : "1px solid var(--yz-border)",
              color: i === adim ? "var(--yz-text)" : "var(--yz-text-3)",
              fontWeight: i === adim ? 600 : 400,
            }}
          >
            {baslik}
          </li>
        ))}
      </ol>

      <Kart>
        {hata && (
          <p
            role="alert"
            className="mb-3"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
          >
            {hata}
          </p>
        )}

        {adim === 0 ? (
          <AlanSarmal etiket={t("sayacAlanKalem")}>
            {(b) => (
              <Secim {...b} value={kalemId} onChange={(e) => setKalemId(e.target.value)}>
                <option value="">—</option>
                {kalemler.map((k) => (
                  <option key={String(k.id)} value={String(k.id)}>
                    {String(k.ad ?? k.id)}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        ) : null}

        {adim === 1 ? (
          <div className="grid gap-3 sm:grid-cols-2">
            <AlanSarmal etiket={t("sayacAlanAnaSayac")}>
              {(b) => (
                <Secim {...b} value={anaId} onChange={(e) => setAnaId(e.target.value)}>
                  <option value="">—</option>
                  {anaSayaclar.map((s) => (
                    <option key={String(s.id)} value={String(s.id)}>
                      {String(s.ad ?? s.id)}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("ortakDonem")}>
              {(b) => (
                <Alan
                  {...b}
                  placeholder="2026-08"
                  value={donem}
                  onChange={(e) => setDonem(e.target.value)}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("sayacAlanAnaTuketim")}>
              {(b) => (
                <Alan
                  {...b}
                  inputMode="decimal"
                  value={anaTuketim}
                  onChange={(e) => setAnaTuketim(e.target.value)}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("sayacAlanBirimFiyat")}>
              {(b) => (
                <Alan
                  {...b}
                  inputMode="decimal"
                  value={birimFiyat}
                  onChange={(e) => setBirimFiyat(e.target.value)}
                />
              )}
            </AlanSarmal>
          </div>
        ) : null}

        {adim === 2 ? (
          bolumYukleniyor ? (
            <IskeletMetin satir={4} />
          ) : bolumler.length === 0 ? (
            // BOS LISTE SESSIZ GECILMEZ: bos bir 3. adimdan "ileri" demek,
            // hicbir daireyi borclandirmayan bir istek atmak olurdu.
            <BosDurum baslik={t("sayacBolumYok")} />
          ) : (
            <div className="space-y-2">
              {bolumler.map((b) => (
                <AlanSarmal key={String(b.id)} etiket={String(b.unit_no ?? b.id)}>
                  {(alan) => (
                    <Alan
                      {...alan}
                      inputMode="decimal"
                      value={tuketimler[String(b.id)] ?? ""}
                      onChange={(e) =>
                        setTuketimler({
                          ...tuketimler,
                          [String(b.id)]: e.target.value,
                        })
                      }
                    />
                  )}
                </AlanSarmal>
              ))}
            </div>
          )
        ) : null}

        {adim === 3 ? (
          <div className="space-y-3">
            <dl className="grid gap-2 sm:grid-cols-2">
              <OzetSatir etiket={t("sayacAlanAnaTuketim")} deger={sayiBicimi(anaDeger)} />
              <OzetSatir etiket={t("sayacToplamTuketim")} deger={sayiBicimi(bolumToplam)} />
              <OzetSatir etiket={t("sayacOrtakAlanFarki")} deger={sayiBicimi(fark)} />
              <OzetSatir
                etiket={t("sayacTahminiTutar")}
                deger={kurusToTL(
                  onizlemeTutar(anaDeger, bolumToplam, birimKurus, ortakYuzde),
                )}
              />
            </dl>
            {/* Fark NEGATIFSE ortak alan payi hesaplanamaz — sunucu da
                boyle davranir; kullanici bunu GONDERMEDEN once gormeli. */}
            {fark < 0 ? (
              <p
                role="alert"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
              >
                {t("sayacFarkUyarisi")}
              </p>
            ) : null}
            <div className="grid gap-3 sm:grid-cols-2">
              <AlanSarmal etiket={t("sayacAlanSonOdeme")}>
                {(b) => (
                  <Alan
                    {...b}
                    type="date"
                    value={sonOdeme}
                    onChange={(e) => setSonOdeme(e.target.value)}
                  />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("ortakAciklamaOpsiyonel")}>
                {(b) => (
                  <Alan {...b} value={aciklama} onChange={(e) => setAciklama(e.target.value)} />
                )}
              </AlanSarmal>
            </div>
          </div>
        ) : null}

        <div className="mt-4 flex gap-2">
          {adim > 0 ? (
            <Dugme
              tur="sessiz"
              onClick={() => {
                setHata(null);
                setAdim(adim - 1);
              }}
            >
              {t("sayacGeri")}
            </Dugme>
          ) : null}
          {adim < 3 ? (
            <Dugme tur="birincil" onClick={ileri}>
              {t("sayacIleri")}
            </Dugme>
          ) : (
            <Dugme
              tur="birincil"
              disabled={gonderiyor || bolumler.length === 0}
              yukleniyor={gonderiyor}
              onClick={() => void borclandir()}
            >
              {gonderiyor ? t("sayacBorclandiriliyor") : t("sayacBorclandir")}
            </Dugme>
          )}
        </div>
      </Kart>
    </div>
  );
}

/** Ozet adiminin tek satiri — dort kez tekrarlanan bicimi tek yerde tutar. */
function OzetSatir({ etiket, deger }: { etiket: string; deger: string }) {
  return (
    <div>
      <dt style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{etiket}</dt>
      <dd style={{ color: "var(--yz-text)" }}>{deger}</dd>
    </div>
  );
}
