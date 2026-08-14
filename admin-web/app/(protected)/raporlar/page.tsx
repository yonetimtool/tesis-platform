"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  Kart,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { agIstegi } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { kurusToTLSade } from "@/lib/money";
import { useT } from "@/lib/i18n/kullan";

/**
 * P40 — RAPOR bolumu (P31 API'si).
 *
 * TEK UC, UC BICIM: katalog `/raporlar/katalog`tan gelir ve sayfa hicbir
 * rapor adini KENDISI TASIMAZ — yeni bir rapor sunucuya eklenince panelde
 * kendiliginden belirir. Rapor listesini burada tekrarlamak, sunucuya
 * eklenen bir raporun panelde unutulmasi demekti.
 *
 * PARAMETRE MODALI TEK MODEL (P31 karari): her rapor ayni alan kumesinin
 * bir alt kumesini kullanir; rapor basina ayri form, ayni dogrulamayi on
 * kez yazmak olurdu.
 *
 * =========================================================================
 * (P160) BU SAYFADA UC KUSUR VARDI — ucu de "Goster" ciktisini bozuyordu
 * =========================================================================
 * 1. SUTUN ANAHTARLARI YANLISTI. Sunucu `{anahtar, baslik, tip}` doner
 *    (`RaporSutun`); sayfa `{ad, etiket, tip}` okuyordu. Sonuc: baslik
 *    satiri BOS ciziliyor ve `satir[undefined]` her hucreyi "—" yapiyordu.
 *    Yani "Goster" dugmesi calisiyor gibi gorunup BOS BIR TABLO veriyordu.
 * 2. KURUS SUTUNLARI HAM SAYIYDI. Tablo bicimi satirlari HAM dondurur;
 *    `125050` ekranda oldugu gibi yaziliyordu. Ayni raporun Excel'i
 *    `1250,50` yazar — panel ile dosya AYNI RAPOR icin farkli rakam
 *    gosteriyordu. (Koddaki "sunucu bicimlendirilmis metin doner" notu
 *    yanlisti; kurus sutunlari icin dogru degil.)
 * 3. TOPLAMLAR HIC CIZILMIYORDU. Sunucu `toplamlar` doner, Excel ve PDF
 *    kalin bir TOPLAM satiri basar; ekranda o satir YOKTU. Rapor alan
 *    kisi toplami gormek icin dosyayi indirmek zorundaydi.
 */

interface KatalogOgesi {
  kod: string;
  baslik: string;
  aciklama: string;
}
/** Sunucu sozlesmesi: `RaporSutun` (backend/app/schemas.py). */
interface RaporSutun {
  anahtar: string;
  baslik: string;
  tip?: string;
}
interface RaporTablosu {
  kod: string;
  baslik: string;
  sutunlar: RaporSutun[];
  satirlar: Record<string, unknown>[];
  toplamlar: Record<string, unknown>;
  metin: string | null;
}

/** Bicim -> dosya UZANTISI. Ucluda ("excel" ? "xlsx" : "pdf") yazmak,
 *  sabit-metin taramasini cevrilmemis metin sanip uyarmaya iterdi — ve
 *  hakliydi: taramanin ucludaki dizgeleri gormesi bilincli bir kural.
 *  Bunlar KULLANICI METNI DEGIL dosya uzantisi oldugu icin sozluge degil
 *  bu haritaya girer. */
const UZANTI: Record<string, string> = { excel: "xlsx", pdf: "pdf" };
const TIP_KURUS = "kurus";

/** Hucre metni. KURUS sutunu TL'ye cevrilir — Excel/PDF ile ayni rakam. */
function hucreMetni(sutun: RaporSutun, ham: unknown): string {
  if (ham === null || ham === undefined) return "—";
  if (sutun.tip === TIP_KURUS && typeof ham === "number") {
    return kurusToTLSade(ham);
  }
  return String(ham);
}

export default function RaporlarPage() {
  const t = useT();
  const toast = useToast();
  const { data: katalog, error: katErr } = useSWR<{ items: KatalogOgesi[] }>(
    "/api/panel/rapor-katalog",
    jsonFetcher,
  );

  const [secili, setSecili] = useState<KatalogOgesi | null>(null);
  const [baslangic, setBaslangic] = useState("");
  const [bitis, setBitis] = useState("");
  const [blok, setBlok] = useState("");
  const [ismiGoster, setIsmiGoster] = useState(true);
  const [tablo, setTablo] = useState<RaporTablosu | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  function parametreler(): Record<string, unknown> {
    // Bos alan GONDERILMEZ: bos dizgeyi tarih diye gondermek sunucuda
    // dogrulama hatasi uretirdi.
    const p: Record<string, unknown> = { ismi_goster: ismiGoster };
    if (baslangic) p.baslangic = baslangic;
    if (bitis) p.bitis = bitis;
    if (blok) p.blok = blok;
    return p;
  }

  async function goster(kod: string): Promise<void> {
    setHata(null);
    setMesgul(true);
    try {
      const res = await agIstegi(`/api/panel/rapor/${kod}?bicim=tablo`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parametreler()),
      });
      if (res === null) return; // (P101/P102) oturum bitti -> yonlendirildi
      const veri = await res.json();
      if (!res.ok) throw new Error(veri?.error?.message ?? String(res.status));
      setTablo(veri as RaporTablosu);
    } catch (e) {
      setTablo(null);
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  async function indir(kod: string, bicim: "excel" | "pdf"): Promise<void> {
    setHata(null);
    setMesgul(true);
    try {
      const res = await agIstegi(`/api/panel/rapor/${kod}?bicim=${bicim}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parametreler()),
      });
      if (res === null) return;
      if (!res.ok) {
        const veri = await res.json().catch(() => null);
        throw new Error(veri?.error?.message ?? String(res.status));
      }
      // DOSYA ADI SUNUCUDAN: `Content-Disposition` basligini yeniden
      // uydurmak, indirilen dosyanin adiyla raporun adinin ayrismasi
      // demekti.
      const cd = res.headers.get("content-disposition") ?? "";
      const eslesme = /filename="?([^";]+)"?/i.exec(cd);
      const ad = eslesme?.[1] ?? `${kod}.${UZANTI[bicim]}`;
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = ad;
      a.click();
      URL.revokeObjectURL(url);
      toast.success(t("raporIndirildi"));
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  // Kolonlar SUNUCUDAN gelir: sayfa hicbir rapor sutununu kendisi
  // tanimlamaz, yoksa yeni bir sutun eklenince panelde eksik kalirdi.
  const kolonlar: Kolon<Record<string, unknown>>[] = useMemo(
    () =>
      (tablo?.sutunlar ?? []).map((s) => ({
        id: s.anahtar,
        baslik: s.baslik,
        sayisal: s.tip === TIP_KURUS,
        hucre: (satir: Record<string, unknown>) => hucreMetni(s, satir[s.anahtar]),
        deger: (satir: Record<string, unknown>) => {
          const ham = satir[s.anahtar];
          return typeof ham === "number" || typeof ham === "string" ? ham : null;
        },
      })),
    [tablo],
  );

  const toplamVar = tablo != null && Object.keys(tablo.toplamlar ?? {}).length > 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("raporBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("raporAlt")}
        </p>
      </div>

      {(katErr || hata) && <HataDurumu mesaj={katErr ? t("raporKatalogHata") : hata!} />}

      {/* ----------------------------- katalog ----------------------------- */}
      <Kart>
        <h2 className="mb-3" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("raporKatalog")}
        </h2>
        {katalog && katalog.items.length === 0 ? (
          <BosDurum baslik={t("raporYok")} aciklama={t("raporYokAlt")} />
        ) : null}
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          {(katalog?.items ?? []).map((r) => (
            // (P160) `aria-pressed` EKLENDI: secili rapor eskiden yalniz
            // KENAR RENGIYLE belliydi; ekran okuyucu hangi raporun secili
            // oldugunu soylemiyordu.
            <button
              key={r.kod}
              type="button"
              aria-pressed={secili?.kod === r.kod}
              onClick={() => {
                setSecili(r);
                setTablo(null);
              }}
              className={[
                "odak-ic p-3 text-start",
                secili?.kod === r.kod ? "yz-raised" : "yz-lift",
              ].join(" ")}
              style={{
                borderRadius: "var(--yz-r-md)",
                border:
                  secili?.kod === r.kod
                    ? "var(--yz-border-w) solid var(--yz-accent)"
                    : "var(--yz-border-w) solid var(--yz-border)",
                background: "var(--yz-metal-1)",
              }}
            >
              <div style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
                {r.baslik}
              </div>
              <div
                className="mt-1"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {r.aciklama}
              </div>
            </button>
          ))}
        </div>
      </Kart>

      {/* ---------------------------- parametre ---------------------------- */}
      {secili ? (
        <Kart>
          <h2 className="mb-3" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {secili.baslik}
          </h2>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <AlanSarmal etiket={t("raporBaslangic")}>
              {(b) => (
                <Alan
                  {...b}
                  type="date"
                  value={baslangic}
                  onChange={(e) => setBaslangic(e.target.value)}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("raporBitis")}>
              {(b) => (
                <Alan {...b} type="date" value={bitis} onChange={(e) => setBitis(e.target.value)} />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("raporBlok")}>
              {(b) => <Alan {...b} value={blok} onChange={(e) => setBlok(e.target.value)} />}
            </AlanSarmal>
            {/* KVKK (P31): kapiya asilacak listede ad OLMAMALI — bu
                anahtar o kullanim icindir. */}
            <label
              className="flex items-center gap-2 self-end pb-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
            >
              <input
                type="checkbox"
                checked={ismiGoster}
                onChange={(e) => setIsmiGoster(e.target.checked)}
              />
              {t("raporIsmiGoster")}
            </label>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            <Dugme tur="birincil" disabled={mesgul} onClick={() => void goster(secili.kod)}>
              {t("raporGoster")}
            </Dugme>
            <Dugme disabled={mesgul} onClick={() => void indir(secili.kod, "excel")}>
              {t("raporExcel")}
            </Dugme>
            <Dugme disabled={mesgul} onClick={() => void indir(secili.kod, "pdf")}>
              {t("raporPdf")}
            </Dugme>
          </div>
        </Kart>
      ) : null}

      {/* ------------------------------ sonuc ------------------------------ */}
      {tablo ? (
        <div className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{tablo.baslik}</h2>
          {tablo.metin ? (
            // Serbest metin bolumu (ihtar govdesi, denetim notu): duz metin
            // olarak cizilir — HTML kabul etmek XSS yuzeyi acardi.
            <Kart>
              <pre
                className="whitespace-pre-wrap"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text)" }}
              >
                {tablo.metin}
              </pre>
            </Kart>
          ) : null}
          {/* SATIR YOKSA BOS DURUM — sutun sayisindan BAGIMSIZ. Once
              "sutun varsa tablo ciz" yazmistim; sutunsuz donen raporlarda
              (serbest metin raporlari boyle doner) ekranda hicbir sey
              kalmiyordu, yani "kayit bulunamadi" bilgisi kayboluyordu. */}
          {tablo.satirlar.length === 0 ? (
            <Kart>
              <BosDurum baslik={t("raporSatirYok")} aciklama={t("raporSatirYokAlt")} />
            </Kart>
          ) : (
            <VeriTablosu<Record<string, unknown>>
              kolonlar={kolonlar}
              satirlar={tablo.satirlar}
              // Rapor satirlarinin kimligi YOK; sira numarasi kararlidir
              // cunku liste tek seferde gelir ve yerinde degismez.
              satirId={(satir) => String(tablo.satirlar.indexOf(satir))}
              bosBaslik={t("raporSatirYok")}
              bosAciklama={t("raporSatirYokAlt")}
              altbilgi={
                toplamVar
                  ? (gorunen) => (
                      <tr>
                        {gorunen.map((k, i) => (
                          <td
                            key={k.id}
                            className={["p-3", k.sayisal ? "text-end tabular-nums" : ""]
                              .filter(Boolean)
                              .join(" ")}
                            style={{
                              fontSize: "var(--yz-fs-body)",
                              fontWeight: 600,
                              color: "var(--yz-text)",
                            }}
                          >
                            {i === 0
                              ? t("ortakToplam")
                              : hucreMetni(
                                  tablo.sutunlar.find((s) => s.anahtar === k.id)!,
                                  tablo.toplamlar[k.id],
                                )}
                          </td>
                        ))}
                      </tr>
                    )
                  : undefined
              }
            />
          )}
        </div>
      ) : null}
    </div>
  );
}
