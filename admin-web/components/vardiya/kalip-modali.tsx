"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Modal,
  Rozet,
  Secim,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P207 §1) KALIP UYGULA — ay olceginde toplu planlama.
 *
 * =========================================================================
 * UC KARAR, TEK PENCERE
 * =========================================================================
 * 1. HANGI KALIP (gunu kac vardiyaya boluyoruz) — kayitli kaliptan sec
 *    ya da burada tanimla,
 * 2. HANGI DILIME KIM (dilim basina personel),
 * 3. ROTASYON var mi (haftalik kaydirma).
 *
 * =========================================================================
 * ONIZLEME ZORUNLU BIR ADIM DEGIL, AMA VARSAYILAN
 * =========================================================================
 * "Uygula" dogrudan yazmaz: once `kuru=true` ile kac vardiya olusacagi
 * gosterilir. Otuz gunluk bir plani gormeden yazmak, yanlisi ancak
 * cizelgede fark etmek demekti — ve geri alma olsa bile o an
 * yoneticinin kafasinda "acaba baska ne degisti" sorusu kalirdi.
 *
 * =========================================================================
 * CAKISMA SESSIZ DEGIL (P205 kurali)
 * =========================================================================
 * Sunucu `uygulandi=false` + cakisan satirlari doner; pencere hangi
 * gun/dilim/kisi oldugunu YAZAR ve iki secenek sunar: cakisanlar haric
 * uygula ya da vazgec.
 */

/** Rotasyon degerleri — JSX ucluda sabit metin olarak yazilamaz
 *  (`sabit-metin` taramasi onlari cevrilmemis metin adayi sayar). */
const ROTASYON_HAFTALIK = "haftalik" as const;
const ROTASYON_YOK = "yok" as const;

type Dilim = { ad: string; baslangic: string; bitis: string };
type Kalip = { id: string; ad: string; dilimler: Dilim[]; aktif: boolean };
type Personel = { id: string; ad: string; role: string };
type Satir = {
  tarih: string;
  dilim: string;
  baslangic: string;
  bitis: string;
  user_id: string;
  ad: string | null;
  durum: string;
};
type Sonuc = {
  uygulandi: boolean;
  parti_id: string | null;
  eklenecek: number;
  eklenen: number;
  cakisan: number;
  zaten_var: number;
  satirlar: Satir[];
  uyarilar: string[];
};

/** Yeni kalip tanimlarken varsayilan: iki vardiya (12+12). Sahada en
 *  yaygin kalip bu; bos bir tabloyla baslamak her kullaniciya ayni iki
 *  satiri yazdirirdi. */
const VARSAYILAN_DILIMLER: Dilim[] = [
  { ad: "", baslangic: "08:00", bitis: "20:00" },
  { ad: "", baslangic: "20:00", bitis: "08:00" },
];

export function KalipModali({
  acik,
  gunler,
  personel,
  onKapat,
  onUygulandi,
}: {
  acik: boolean;
  gunler: string[];
  personel: Personel[];
  onKapat: () => void;
  onUygulandi: (partiId: string | null) => void;
}) {
  const t = useT();
  const toast = useToast();
  const { data: kaliplar, mutate: kaliplariTazele } = useSWR<{ items: Kalip[] }>(
    acik ? "/api/vardiya-plani/kaliplar" : null,
    jsonFetcher,
  );

  const [kalipId, setKalipId] = useState("");
  const [yeniAd, setYeniAd] = useState("");
  const [dilimler, setDilimler] = useState<Dilim[]>(VARSAYILAN_DILIMLER);
  const [atamalar, setAtamalar] = useState<Record<number, string[]>>({});
  const [rotasyon, setRotasyon] = useState<"yok" | "haftalik">("yok");
  const [sonuc, setSonuc] = useState<Sonuc | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  const secili = (kaliplar?.items ?? []).find((k) => k.id === kalipId);
  const etkinDilimler = secili ? secili.dilimler : dilimler;

  const atanan = useMemo(
    () => Object.values(atamalar).flat().length,
    [atamalar],
  );

  function govde(ek: Record<string, unknown>) {
    return {
      ...(kalipId
        ? { kalip_id: kalipId }
        : {
            dilimler: dilimler.map((d, i) => ({
              // AD BOSSA SIRA NUMARASI: adsiz dilim, sonuc listesinde
              // hangi vardiya oldugunu okunamaz yapardi.
              ad: d.ad.trim() || t("vardiyaDilimVarsayilanAd", { n: i + 1 }),
              baslangic: d.baslangic,
              bitis: d.bitis,
            })),
          }),
      gunler,
      atamalar,
      rotasyon,
      ...ek,
    };
  }

  async function calistir(ek: Record<string, unknown>) {
    setBekliyor(true);
    setHata(null);
    try {
      const y = (await apiSend(
        "/api/vardiya-plani/kalip-uygula",
        "POST",
        govde(ek),
      )) as Sonuc;
      setSonuc(y);
      if (y.uygulandi) {
        toast.success(t("vardiyaKalipUygulandi", { n: y.eklenen }));
        onUygulandi(y.parti_id);
      }
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  async function kalipKaydet() {
    setBekliyor(true);
    setHata(null);
    try {
      await apiSend("/api/vardiya-plani/kaliplar", "POST", {
        ad: yeniAd.trim(),
        dilimler: dilimler.map((d, i) => ({
          ad: d.ad.trim() || t("vardiyaDilimVarsayilanAd", { n: i + 1 }),
          baslangic: d.baslangic,
          bitis: d.bitis,
        })),
      });
      toast.success(t("vardiyaKalipKaydedildi"));
      setYeniAd("");
      await kaliplariTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  const cakisanlar = (sonuc?.satirlar ?? []).filter((s) => s.durum === "cakisma");

  return (
    <Modal
      acik={acik}
      onKapat={onKapat}
      baslik={t("vardiyaKalipUygula")}
      genislikSinifi="max-w-2xl"
      eylemler={
        <>
          <Dugme type="button" tur="ikincil" onClick={onKapat}>
            {t("ortakIptal")}
          </Dugme>
          {/* ONIZLEME ONCE: yazmadan once kac vardiya olusacagi gorunur. */}
          <Dugme
            type="button"
            tur="ikincil"
            disabled={bekliyor || atanan === 0}
            data-test="kalip-onizle"
            onClick={() => void calistir({ kuru: true })}
          >
            {t("vardiyaOnizle")}
          </Dugme>
          <Dugme
            type="button"
            disabled={bekliyor || atanan === 0}
            data-test="kalip-uygula"
            onClick={() => void calistir({})}
          >
            {t("ortakUygula")}
          </Dugme>
        </>
      }
    >
      <div className="space-y-3">
        <HataDurumu mesaj={hata} />

        <p
          data-test="kalip-gun-sayisi"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
        >
          {t("vardiyaSeciliGun", { n: gunler.length })}
        </p>

        <AlanSarmal etiket={t("vardiyaKalip")}>
          {(b) => (
            <Secim
              {...b}
              value={kalipId}
              data-test="kalip-sec"
              onChange={(e) => setKalipId(e.target.value)}
            >
              <option value="">{t("vardiyaKalipYeni")}</option>
              {(kaliplar?.items ?? []).map((k) => (
                <option key={k.id} value={k.id}>
                  {k.ad}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>

        {/* KALIP SECILIYSE dilimler SALT OKUNUR gosterilir: kayitli bir
            kalibi pencere icinde degistirmek, adi ayni kalan baska bir
            kalip uygulamak olurdu. */}
        {secili ? (
          <ul data-test="kalip-dilimler-hazir" className="space-y-1">
            {secili.dilimler.map((d, i) => (
              <li
                key={`${d.ad}-${i}`}
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
              >
                {d.ad} · {d.baslangic.slice(0, 5)}–{d.bitis.slice(0, 5)}
              </li>
            ))}
          </ul>
        ) : (
          <div className="space-y-2" data-test="kalip-dilimler">
            {dilimler.map((d, i) => (
              <div key={i} className="flex flex-wrap items-end gap-2">
                <AlanSarmal etiket={t("vardiyaDilimAd")}>
                  {(b) => (
                    <Alan
                      {...b}
                      value={d.ad}
                      data-test={`kalip-dilim-ad-${i}`}
                      onChange={(e) =>
                        setDilimler((ds) =>
                          ds.map((x, j) =>
                            j === i ? { ...x, ad: e.target.value } : x,
                          ),
                        )
                      }
                    />
                  )}
                </AlanSarmal>
                <AlanSarmal etiket={t("vardiyaBaslangicSaati")}>
                  {(b) => (
                    <Alan
                      {...b}
                      type="time"
                      value={d.baslangic}
                      data-test={`kalip-dilim-bas-${i}`}
                      onChange={(e) =>
                        setDilimler((ds) =>
                          ds.map((x, j) =>
                            j === i ? { ...x, baslangic: e.target.value } : x,
                          ),
                        )
                      }
                    />
                  )}
                </AlanSarmal>
                <AlanSarmal etiket={t("vardiyaBitisSaati")}>
                  {(b) => (
                    <Alan
                      {...b}
                      type="time"
                      value={d.bitis}
                      data-test={`kalip-dilim-son-${i}`}
                      onChange={(e) =>
                        setDilimler((ds) =>
                          ds.map((x, j) =>
                            j === i ? { ...x, bitis: e.target.value } : x,
                          ),
                        )
                      }
                    />
                  )}
                </AlanSarmal>
                {dilimler.length > 1 && (
                  <Dugme
                    type="button"
                    boy="kucuk"
                    tur="ikincil"
                    data-test={`kalip-dilim-sil-${i}`}
                    onClick={() =>
                      setDilimler((ds) => ds.filter((_, j) => j !== i))
                    }
                  >
                    {t("ortakSil")}
                  </Dugme>
                )}
              </div>
            ))}
            <div className="flex flex-wrap items-end gap-2">
              <Dugme
                type="button"
                boy="kucuk"
                tur="ikincil"
                disabled={dilimler.length >= 6}
                data-test="kalip-dilim-ekle"
                onClick={() =>
                  setDilimler((ds) => [
                    ...ds,
                    { ad: "", baslangic: "08:00", bitis: "16:00" },
                  ])
                }
              >
                {t("vardiyaDilimEkle")}
              </Dugme>
              {/* KALIBI KAYDETMEK OPSIYONEL: bir kerelik plan icin kalici
                  tanim uretmek, tanim listesini sisirirdi. */}
              <AlanSarmal etiket={t("vardiyaKalipAdiKaydet")}>
                {(b) => (
                  <Alan
                    {...b}
                    value={yeniAd}
                    data-test="kalip-yeni-ad"
                    onChange={(e) => setYeniAd(e.target.value)}
                  />
                )}
              </AlanSarmal>
              <Dugme
                type="button"
                boy="kucuk"
                tur="ikincil"
                disabled={bekliyor || yeniAd.trim() === ""}
                data-test="kalip-kaydet"
                onClick={() => void kalipKaydet()}
              >
                {t("ortakKaydet")}
              </Dugme>
            </div>
          </div>
        )}

        {/* DILIM BASINA PERSONEL. */}
        <div className="space-y-2" data-test="kalip-atamalar">
          {etkinDilimler.map((d, i) => (
            <AlanSarmal
              key={`atama-${i}`}
              etiket={t("vardiyaDilimPersonel", {
                dilim: d.ad || String(i + 1),
              })}
            >
              {(b) => (
                <Secim
                  {...b}
                  multiple
                  value={atamalar[i] ?? []}
                  data-test={`kalip-atama-${i}`}
                  onChange={(e) =>
                    setAtamalar((a) => ({
                      ...a,
                      [i]: Array.from(e.target.selectedOptions).map(
                        (o) => o.value,
                      ),
                    }))
                  }
                >
                  {personel.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.ad}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
          ))}
        </div>

        <AlanSarmal etiket={t("vardiyaRotasyon")}>
          {(b) => (
            <Secim
              {...b}
              value={rotasyon}
              data-test="kalip-rotasyon"
              onChange={(e) =>
                setRotasyon(
                  e.target.value === ROTASYON_HAFTALIK
                    ? ROTASYON_HAFTALIK
                    : ROTASYON_YOK,
                )
              }
            >
              <option value="yok">{t("vardiyaRotasyonYok")}</option>
              <option value="haftalik">{t("vardiyaRotasyonHaftalik")}</option>
            </Secim>
          )}
        </AlanSarmal>
        <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
          {t("vardiyaRotasyonNotu")}
        </p>

        {/* SONUC / ONIZLEME. */}
        {sonuc && (
          <div data-test="kalip-sonuc" className="space-y-1">
            <Rozet durum={sonuc.uygulandi ? "olumlu" : "bilgi"}>
              {sonuc.uygulandi
                ? t("vardiyaKalipEklendi", { n: sonuc.eklenen })
                : t("vardiyaKalipOnizleme", { n: sonuc.eklenecek })}
            </Rozet>
            {sonuc.zaten_var > 0 && (
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("vardiyaKalipZatenVar", { n: sonuc.zaten_var })}
              </p>
            )}
            {cakisanlar.length > 0 && (
              <div data-test="kalip-cakisma">
                <Rozet durum="uyari">
                  {t("vardiyaCakisanGunler", { n: cakisanlar.length })}
                </Rozet>
                <ul className="mt-1">
                  {cakisanlar.slice(0, 10).map((s, i) => (
                    <li
                      key={`${s.tarih}-${s.dilim}-${i}`}
                      className="tabular-nums"
                      style={{
                        fontSize: "var(--yz-fs-xs)",
                        color: "var(--yz-text-2)",
                      }}
                    >
                      {s.tarih} · {s.dilim} · {s.ad}
                    </li>
                  ))}
                </ul>
                <Dugme
                  type="button"
                  boy="kucuk"
                  disabled={bekliyor}
                  data-test="kalip-cakisan-haric"
                  onClick={() => void calistir({ cakisanlari_atla: true })}
                >
                  {t("vardiyaCakisanHaric")}
                </Dugme>
              </div>
            )}
          </div>
        )}
      </div>
    </Modal>
  );
}
