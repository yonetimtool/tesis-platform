"use client";

import { useState } from "react";
import useSWR from "swr";

import {
  Kart,
  CokSatir,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Secim,
  useOnay,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { useSorguSecimi } from "@/lib/sorgu-secimi";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P154 / Asama 8) ICE AKTARIM — dort tur, TEK akis.
 *
 * Brief: "sablon indirme → yukleme → kolon esleme → dogrulama → ONIZLEME
 * → islem icinde aktarim → hata raporu → GERI ALMA."
 *
 * KOLON ESLEME BURADA YAPILIR: sunucu ALANLARI bildirir
 * (`GET /ice-aktarim/turler`), kullanici kendi basliklarini onlara esler,
 * satirlar BIZIM alan kodlarimizla gonderilir. XLSX ayristirma sunucuda
 * YAPILMIYOR (bir saldiri yuzeyidir) — dosyayi zaten istemci aciyor.
 *
 * NEDEN CSV/YAPISTIRMA, NEDEN XLSX AYRISTIRICI DEGIL: panele bir xlsx
 * kitapligi eklemek, kullanicinin dosyasini tarayicida acan yeni bir kod
 * yolu demekti. Yapistirma alani ayni isi kitapliksiz yapar ve
 * kullanicilar Excel'den kopyalamaya zaten alisik. Gercek dosya
 * yuklemesi gerekirse tek degisecek yer `satirlariCoz`dur.
 */

interface Alan {
  kod: string;
  zorunlu: boolean;
  ornek: string;
}
interface Tur {
  kod: string;
  aciklama_kodu: string;
  alanlar: Alan[];
}
interface Hata {
  satir_no: number;
  alan: string | null;
  hata: string;
}
interface Sonuc {
  satir_sayisi: number;
  olusan: number;
  atlanan: number;
  /** (P193 §6) Var olan kayda YENI BILGI yazildi (daire arsa payi/m²). */
  guncellenen?: number;
  hatali: number;
  hatalar: Hata[];
  /** (P193 §1) Sorunlu satir var ve "atla" denmedi -> HICBIR SEY yazilmadi. */
  uygulanmadi: boolean;
  davet_gonderildi: number;
  davet_basarisiz: number;
  davet_hatalari: Hata[];
  aktarim_id: string | null;
}
interface Kosum {
  id: string;
  tur: string;
  dosya_adi: string | null;
  satir_sayisi: number;
  olusan: number;
  atlanan: number;
  hatali: number;
  durum: string;
  created_at: string;
  geri_alma_at: string | null;
}

// Bilinmeyen tur icin yedek etiket. Modul duzeyinde adlandirildi:
// `t(... ?? "iceAktarimTur")` yazmak, `sabit-metin` taramasinda ucludaki
// dizgeyi (cevrilmemis metin adayi) hakli olarak isaretletiyordu — oysa
// bu bir CEVIRI ANAHTARI, gorunen metin degil. (6.3'teki ayni ders.)
const _YEDEK_TUR_ETIKET: SozlukAnahtari = "iceAktarimTur";

type TurKodu = "daire" | "kisi" | "acilis_bakiye" | "arac";
const TUR_KODLARI: readonly TurKodu[] = [
  "daire", "kisi", "acilis_bakiye", "arac",
];

const TUR_ETIKET: Record<string, SozlukAnahtari> = {
  daire: "iceAktarimTurDaire",
  kisi: "iceAktarimTurKisi",
  acilis_bakiye: "iceAktarimTurAcilis",
  arac: "iceAktarimTurArac",
};

/** Yapistirilan metni satirlara + hucrelere ayirir (sekme ya da noktali virgul). */
function hucreler(satir: string): string[] {
  return satir.includes("\t") ? satir.split("\t") : satir.split(";");
}

export default function IceAktarimPage() {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  // (P154 / Asama 5) `?tur=kisi` ile DOGRUDAN gelinebilir: `/users`
  // ekranindaki "toplu yukle" dugmesi buraya yollar. Kanca 7.1'de
  // yazilmisti; ikinci bir adres-okuma kodu yazilmadi.
  const [turKod, setTurKod] = useSorguSecimi<TurKodu>(
    "tur", TUR_KODLARI, "daire",
  );
  const [ham, setHam] = useState("");
  const [baslikVar, setBaslikVar] = useState(true);
  const [esleme, setEsleme] = useState<Record<number, string>>({});
  const [sonuc, setSonuc] = useState<Sonuc | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);
  /**
   * (P193 §1) SORUNLU SATIRLARI ATLA — VARSAYILAN KAPALI.
   *
   * Eskiden kismi basari varsayilandi ve SESSIZDI: yonetici 50 kisi
   * yukluyor, 10'u atlaniyor, kimse fark etmiyor. Kutu kapali kaldigi
   * surece sunucu hicbir sey yazmaz; atlama artik kullanicinin ACIK
   * kararidir.
   */
  const [sorunlulariAtla, setSorunlulariAtla] = useState(false);

  const { data: turler } = useSWR<Tur[]>("/api/panel/ice-aktarim-turler", jsonFetcher);
  const { data: gecmis, mutate: gecmisTazele } = useSWR<{ items: Kosum[] }>(
    "/api/panel/ice-aktarim?limit=20",
    jsonFetcher,
  );
  const tur = turler?.find((x) => x.kod === turKod);

  const satirlar = ham.split("\n").map((s) => s.trimEnd()).filter((s) => s.trim());
  const basliklar = satirlar.length > 0 ? hucreler(satirlar[0]) : [];
  const veriSatirlari = baslikVar ? satirlar.slice(1) : satirlar;

  function alanSec(kolon: number, alanKod: string) {
    setEsleme((e) => ({ ...e, [kolon]: alanKod }));
  }

  /**
   * (P162 §4.2) DOSYA OKUMA — eksik olan tek halka buydu.
   *
   * Boru hattinin GERISI zaten vardi (kolon esleme, dogrulama, onizleme,
   * hata raporu, kismi basari, geri alma). Sayfa yalnizca YAPISTIRMA
   * kabul ediyordu; kullanici `.xlsx` dosyasini secince hicbir sey
   * olmuyordu — "Excel ice aktarma calismiyor" sikayetinin kaynagi.
   *
   * OKUNAN DOSYA AYNI BORUYA DOKULUR: satirlar sekmeyle birlestirilip
   * `ham` metnine yaziliyor. Boylece esleme/onizleme/aktarim yollarinin
   * TEK bir girdi bicimi var; ikinci bir kod yolu acilmadi.
   */
  async function dosyaSec(dosya: File | null) {
    if (!dosya) return;
    setHata(null);
    setSonuc(null);
    setSorunlulariAtla(false);
    setEsleme({});
    try {
      const satirlar = /\.xlsx$/i.test(dosya.name)
        ? await (await import("@/lib/xlsx-oku")).xlsxSatirlari(dosya)
        : (await dosya.text())
            .split(/\r?\n/)
            .map((r) => hucreler(r.trimEnd()));
      const metin = satirlar
        .filter((r) => r.some((h) => h.trim()))
        .map((r) => r.join("\t"))
        .join("\n");
      if (!metin) {
        setHata(t("iceAktarimDosyaBos"));
        return;
      }
      setHam(metin);
    } catch (e) {
      const ad = e instanceof Error ? e.constructor.name : "";
      // DESTEK YOKSA SESSIZ KALMA: kullaniciyi yapistirma yoluna yolla.
      setHata(ad === "XlsxDesteklenmiyor" ? t("iceAktarimXlsxYok") : t("iceAktarimDosyaOkunamadi"));
    }
  }

  /**
   * SABLON INDIRME (brief). Sunucu XLSX URETMEZ ve uretmemeli; sablon
   * alan listesinden kuruluyor — yani kabul edilen bicim ile indirilen
   * sablon TEK KAYNAKTAN geliyor ve ayrisamaz.
   *
   * CSV (`;`) secildi: Excel bunu dogrudan acar ve bir yazici kitapligi
   * gerektirmez. BOM VAR — BOM'suz UTF-8'de Excel Turkce harfleri bozuk
   * gosterir ve kullanici sablonu "bozuk" sanardi.
   */
  function sablonIndir() {
    if (!tur) return;
    const satirlar = [
      tur.alanlar.map((a) => a.kod).join(";"),
      tur.alanlar.map((a) => a.ornek).join(";"),
    ].join("\r\n");
    const bag = URL.createObjectURL(
      new Blob(["\uFEFF" + satirlar], { type: "text/csv;charset=utf-8" }),
    );
    const a = document.createElement("a");
    a.href = bag;
    a.download = `yonetio-${tur.kod}-sablon.csv`;
    a.click();
    URL.revokeObjectURL(bag);
  }

  /** Eslemeye gore satirlari BIZIM alan kodlarimizla kurar. */
  function govdeSatirlari() {
    return veriSatirlari.map((s, i) => {
      const h = hucreler(s);
      const degerler: Record<string, string> = {};
      for (const [kolonStr, alanKod] of Object.entries(esleme)) {
        if (!alanKod) continue;
        degerler[alanKod] = (h[Number(kolonStr)] ?? "").trim();
      }
      return { satir_no: i + (baslikVar ? 2 : 1), degerler };
    });
  }

  async function calistir(yalnizDogrula: boolean) {
    setHata(null);
    const govde = govdeSatirlari();
    if (govde.length === 0) {
      setHata(t("iceAktarimBosDosya"));
      return;
    }
    const zorunluEksik = (tur?.alanlar ?? [])
      .filter((a) => a.zorunlu)
      .filter((a) => !Object.values(esleme).includes(a.kod));
    if (zorunluEksik.length > 0) {
      // Sunucu da reddederdi ama SATIR SATIR: kullanici yuz hata gorurdu.
      setHata(t("iceAktarimEslemeEksik", { alan: zorunluEksik[0].kod }));
      return;
    }
    setMesgul(true);
    try {
      const r = await apiSend<Sonuc>(
        `/api/panel/ice-aktarim-${turKod}`,
        "POST",
        {
          satirlar: govde,
          yalniz_dogrula: yalnizDogrula,
          dosya_adi: null,
          sorunlulari_atla: sorunlulariAtla,
        },
      );
      setSonuc(r);
      if (!yalnizDogrula) {
        toast.success(t("iceAktarimTamam"));
        await gecmisTazele();
      }
    } catch (e) {
      setSonuc(null);
      setSorunlulariAtla(false);
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  async function geriAl(id: string) {
    if (!(await onayla({ baslik: t("ortakOnayBaslik"), mesaj: t("iceAktarimGeriAlOnay"), onayMetni: t("iceAktarimGeriAl"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/panel/ice-aktarim/${id}/geri-al`, "POST");
      toast.success(t("iceAktarimGeriAlindi"));
      await gecmisTazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("iceAktarimBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("iceAktarimAlt")}
        </p>
      </div>
      <HataDurumu mesaj={hata} />

      {/* --------------------------- 1) TUR + SABLON --------------------- */}
      <Kart className="space-y-3">
        <AlanSarmal etiket={t("iceAktarimTur")}>
  {(b) => (
    <Secim {...b} style={{ maxWidth: 280 }}
            value={turKod}
            onChange={(e) => {
              setTurKod(e.target.value as TurKodu);
              // ESLEME SIFIRLANIR: alanlar degisti, eski esleme artik
              // baska bir turun alanlarina isaret ediyordu.
              setEsleme({});
              setSonuc(null);
              setSorunlulariAtla(false);
            }}
          >
            {(turler ?? []).map((x) => (
              <option key={x.kod} value={x.kod}>
                {t(TUR_ETIKET[x.kod] ?? _YEDEK_TUR_ETIKET)}
              </option>
            ))}</Secim>
  )}
</AlanSarmal>
        {tur && (
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("iceAktarimSablonSatiri")}:{" "}
            <code className="break-all">
              {tur.alanlar.map((a) => a.kod).join(";")}
            </code>
            <br />
            {t("iceAktarimOrnekSatiri")}:{" "}
            <code className="break-all">
              {tur.alanlar.map((a) => a.ornek).join(";")}
            </code>
            <br />
            {/* (P193 §1) ZORUNLU SUTUNLAR ACIKCA YAZILIR: kullanici hangi
                sutunu bos birakamayacagini sablonu doldururken bilmeli,
                yukledikten sonra degil. */}
            {t("iceAktarimZorunluAlanlar")}:{" "}
            <code className="break-all">
              {tur.alanlar.filter((a) => a.zorunlu).map((a) => a.kod).join(";")}
            </code>
          </p>
        )}
        {tur && (
          <Dugme boy="kucuk" onClick={sablonIndir}>
            {t("iceAktarimSablonIndir")}
          </Dugme>
        )}
      </Kart>

      {/* ----------------------------- 2) YUKLEME ------------------------ */}
      <Kart className="space-y-3">
        {/* DOSYA YOLU ONCE: kullanicinin elinde bir dosya var ve once onu
            arar. Yapistirma ALTTA duruyor — kaldirilmadi, cunku kopyala
            yapistir hala en hizli yol ve dosyasi olmayan kullaniciyi
            dosya uretmeye zorlamak gerileme olurdu. */}
        <AlanSarmal etiket={t("iceAktarimDosya")} ipucu={t("iceAktarimDosyaIpucu")}>
          {(b) => (
            <input
              {...b}
              type="file"
              accept=".xlsx,.csv,.txt,text/csv"
              className="block w-full text-sm"
              onChange={(e) => void dosyaSec(e.target.files?.[0] ?? null)}
            />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("iceAktarimVeri")} ipucu={t("iceAktarimVeriIpucu")}>
            {(b) => (
              <CokSatir {...b} rows={4} value={ham}
            onChange={(e) => {
              setHam(e.target.value);
              setSonuc(null);
              setSorunlulariAtla(false);
            }} />
            )}
          </AlanSarmal>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            className="h-4 w-4"
            checked={baslikVar}
            onChange={(e) => setBaslikVar(e.target.checked)}
          />
          {t("iceAktarimBaslikSatiri")}
        </label>
      </Kart>

      {/* --------------------------- 3) KOLON ESLEME --------------------- */}
      {basliklar.length > 0 && tur && (
        <Kart className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("iceAktarimEsleme")}</h2>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {basliklar.map((b, i) => (
              <AlanSarmal
                key={i}
                etiket={baslikVar ? b || `#${i + 1}` : `${t("iceAktarimKolon")} ${i + 1}`}
              >
                {(bag) => (
                  <Secim
                    {...bag}
                    value={esleme[i] ?? ""}
                    onChange={(e) => alanSec(i, e.target.value)}
                  >
                    <option value="">{t("iceAktarimKullanma")}</option>
                    {tur.alanlar.map((a) => (
                      <option key={a.kod} value={a.kod}>
                        {a.kod}
                        {a.zorunlu ? " *" : ""}
                      </option>
                    ))}
                  </Secim>
                )}
              </AlanSarmal>
            ))}
          </div>
          {/* (P193 §1) SORUNLU SATIR VARSA ACIK KARAR ISTENIR.
              Kutu, yalnizca onizlemede sorun GORULDUYSE cizilir: sorunsuz
              bir dosyada kullaniciya cevap veremeyecegi bir soru sormak
              gurultu olurdu. */}
          {sonuc && sonuc.hatali > 0 && (
            <div className="space-y-1">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={sorunlulariAtla}
                  onChange={(e) => setSorunlulariAtla(e.target.checked)}
                />
                {t("iceAktarimSorunlulariAtla")}
              </label>
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("iceAktarimSorunluUyari", { n: sonuc.hatali })}
              </p>
            </div>
          )}
          <div className="flex flex-wrap gap-2">
            {/* ONIZLEME ONCE: hicbir sey yazmadan ayni raporu verir. */}
            <Dugme
              type="button"
              boy="kucuk"
              disabled={mesgul}
              onClick={() => void calistir(true)}
            >
              {t("iceAktarimOnizle")}
            </Dugme>
            <Dugme
              type="button"
              tur="birincil"
              // AKTAR, SORUN VARKEN VE KUTU ISARETLI DEGILKEN KAPALI.
              // Sunucu zaten reddediyor; dugmeyi acik birakmak kullaniciya
              // hicbir sey yapmayan bir dugme bastirmak olurdu.
              disabled={mesgul || (!!sonuc && sonuc.hatali > 0 && !sorunlulariAtla)}
              onClick={() => void calistir(false)}
            >
              {t("iceAktarimUygula")}
            </Dugme>
          </div>
        </Kart>
      )}

      {/* ---------------------------- 4) SONUC --------------------------- */}
      {sonuc && (
        <section className="space-y-2 p-kart" aria-live="polite">
          {/* (P193 §1) SAYILAR ETIKETLI: "okunan/gecerli/sorunlu" tek bir
              cumleye sikistirilinca kullanici hangi sayinin ne oldugunu
              ayirt edemiyordu ve sorunlu satirlari fark etmeden Aktar'a
              basiyordu. */}
          <dl className="flex flex-wrap gap-x-6 gap-y-1 text-sm">
            <span>
              <dt className="inline">{t("iceAktarimOkunan")}: </dt>
              <dd className="inline font-semibold tabular-nums">
                {sonuc.satir_sayisi}
              </dd>
            </span>
            <span>
              <dt className="inline">{t("iceAktarimGecerli")}: </dt>
              <dd className="inline font-semibold tabular-nums">{sonuc.olusan}</dd>
            </span>
            <span>
              <dt className="inline">{t("iceAktarimZatenVar")}: </dt>
              <dd className="inline font-semibold tabular-nums">{sonuc.atlanan}</dd>
            </span>
            {/* (P193 §6) GUNCELLENEN — "atlandi" ile ayni sey degil:
                atlanan satir hicbir sey degistirmez, bu satir var olan
                daireye arsa payi/m² yazar. Sayi sifirken satir
                cizilmez: her aktarim turunde anlamli degil. */}
            {(sonuc.guncellenen ?? 0) > 0 && (
              <span>
                <dt className="inline">{t("iceAktarimGuncellenen")}: </dt>
                <dd className="inline font-semibold tabular-nums">
                  {sonuc.guncellenen}
                </dd>
              </span>
            )}
            <span>
              <dt className="inline">{t("iceAktarimSorunlu")}: </dt>
              <dd
                className="inline font-semibold tabular-nums"
                style={sonuc.hatali > 0 ? { color: "var(--yz-danger)" } : undefined}
              >
                {sonuc.hatali}
              </dd>
            </span>
          </dl>

          {/* AKTARIM DURDUYSA EN USTTE SOYLENIR: kullanici sayilara bakip
              "oldu" sanmamali. */}
          {sonuc.uygulanmadi && (
            <p
              className="font-semibold"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger)" }}
            >
              {t("iceAktarimUygulanmadi")}
            </p>
          )}

          {sonuc.hatalar.length > 0 && (
            <ul className="space-y-1 text-xs" style={{ color: "var(--yz-danger)" }}>
              {sonuc.hatalar.map((h, i) => (
                <li key={i}>
                  {t("iceAktarimSatir", { no: h.satir_no })}
                  {h.alan ? ` · ${h.alan}` : ""} — {h.hata}
                </li>
              ))}
            </ul>
          )}

          {/* DAVET OZETI — "kac kisi eklendi" ile "kac kisiye ULASILDI"
              ayri sorulardir; daveti gitmeyen kisi sisteme hic giremez. */}
          {(sonuc.davet_gonderildi > 0 || sonuc.davet_basarisiz > 0) && (
            <div className="space-y-1">
              <p style={{ fontSize: "var(--yz-fs-sm)" }}>
                {t("iceAktarimDavetOzeti", {
                  gonderilen: sonuc.davet_gonderildi,
                  basarisiz: sonuc.davet_basarisiz,
                })}
              </p>
              {sonuc.davet_basarisiz > 0 && (
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-danger)" }}>
                  {t("iceAktarimDavetUyari")}
                </p>
              )}
            </div>
          )}
        </section>
      )}

      {/* --------------------------- 5) GECMIS + GERI ALMA --------------- */}
      <section className="space-y-2 p-kart">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("iceAktarimGecmis")}</h2>
        {(gecmis?.items ?? []).length === 0 && (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("iceAktarimGecmisYok")}</p>
        )}
        {(gecmis?.items ?? []).map((k) => (
          <div
            key={k.id}
            className="kart-kenar flex flex-wrap items-center justify-between gap-3 rounded-lg border p-2 text-sm"
          >
            <span className="min-w-0">
              {t(TUR_ETIKET[k.tur] ?? _YEDEK_TUR_ETIKET)} ·{" "}
              {formatDateTime(k.created_at)} ·{" "}
              {t("iceAktarimOzetKisa", { olusan: k.olusan, hatali: k.hatali })}
            </span>
            {k.durum === "geri_alindi" ? (
              <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("iceAktarimGeriAlinmis")}
              </span>
            ) : (
              <Dugme
                type="button"
                tur="tehlike" boy="kucuk"
                onClick={() => void geriAl(k.id)}
              >
                {t("iceAktarimGeriAl")}
              </Dugme>
            )}
          </div>
        ))}
      </section>
      {diyalog}
    </div>
  );
}
