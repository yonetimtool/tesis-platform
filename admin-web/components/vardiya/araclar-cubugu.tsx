"use client";

/**
 * (P241 §2) ARACLAR + EXCEL + YAYINLA.
 *
 * =========================================================================
 * NEDEN AYRI BILESEN
 * =========================================================================
 * Vardiya sayfasi zaten 1000 satir. Bu uc arac BIRBIRINDEN BAGIMSIZ
 * dialoglar aciyor ve sayfanin durumundan yalnizca "hangi donem
 * goruntuleniyor" bilgisini istiyor; ayni dosyaya yigmak, sayfanin
 * okunabilirligini artirmadan uzatirdi.
 *
 * =========================================================================
 * YAYINLA DUGMESINDE SAYI VAR
 * =========================================================================
 * Istek: "kac degisiklik yayinlanacak, dugmede sayi gorunsun". Sayi
 * SUNUCUDAN gelir (`/yayin-ozeti`): taslak + degismis satirlar. Istemci
 * saymaya kalksaydi, baskasinin ekledigi satirlari gormezdi.
 */
import { useRef, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, Modal, Rozet } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

const IKINCIL = "ikincil" as const;
const BIRINCIL = "birincil" as const;
const KUCUK = "kucuk" as const;
/** JSX ucluda sabit dize yasak (`sabit-metin` kilidi). */
const VIRGUL = ", ";

type YayinOzet = { bekleyen: number; taslak: number; degisen: number };
type KopyaSonuc = {
  eklenen: number;
  atlanan: number;
  sebepler: string[];
};
type IceSatir = {
  satir_no: number;
  durum: string;
  mesaj: string | null;
  kisi_ad: string | null;
};
type IceSonuc = {
  uygulandi: boolean;
  basarili: number;
  hatali: number;
  satirlar: IceSatir[];
  parti_id?: string | null;
};

/** `YYYY-MM-DD` -> o haftanin PAZARTESISI. */
function pazartesi(gun: string): string {
  const d = new Date(`${gun}T00:00:00`);
  const fark = (d.getDay() + 6) % 7;
  d.setDate(d.getDate() - fark);
  return d.toISOString().slice(0, 10);
}

export function AraclarCubugu({
  baslangic,
  gun,
  onDegisti,
  onSablonlaraGit,
  onKalipAc,
  onParti,
}: {
  baslangic: string;
  gun: number;
  onDegisti: () => void;
  onSablonlaraGit: () => void;
  onKalipAc: () => void;
  /** (E2E 2026-09) Ice aktarimin PARTI kimligi — sayfadaki "geri al". */
  onParti?: (partiId: string | null) => void;
}) {
  const t = useT();
  const toast = useToast();
  const dosyaRef = useRef<HTMLInputElement | null>(null);

  const yayin = useSWR<YayinOzet>(
    `/api/vardiya-plani/yayin-ozeti?baslangic=${baslangic}&gun=${gun}`,
    jsonFetcher,
    { refreshInterval: 30_000 },
  );

  const [araclarAcik, setAraclarAcik] = useState(false);
  const [kopyaAcik, setKopyaAcik] = useState(false);
  const [kaynak, setKaynak] = useState(() => pazartesi(baslangic));
  const [hedef, setHedef] = useState(() => pazartesi(baslangic));
  const [temizle, setTemizle] = useState(false);
  const [iceAcik, setIceAcik] = useState(false);
  const [iceSonuc, setIceSonuc] = useState<IceSonuc | null>(null);
  const [satirlar, setSatirlar] = useState<
    { satir_no: number; degerler: Record<string, string> }[]
  >([]);
  const [bekliyor, setBekliyor] = useState(false);

  function hata(e: unknown) {
    toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
  }

  async function indir(yol: string, ad: string) {
    // DOSYA INDIRME `apiSend` ILE OLMAZ: o JSON bekler. Ham `fetch` +
    // blob; BFF rotasi ikili icerigi aynen gecirir.
    try {
      const r = await fetch(yol);
      if (!r.ok) throw new Error(t("ortakHataOlustu"));
      const blob = await r.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = ad;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      hata(e);
    }
  }

  async function dosyaSecildi(dosya: File) {
    // EXCEL ISTEMCIDE AYRISTIRILIR (`ice_aktarim` ile AYNI desen) ve
    // ayristirici DEPONUN KENDI okuyucusudur (`lib/xlsx-oku`): P154'te
    // "xlsx kitapligi eklemeyelim" karari verilmisti ve ikinci bir
    // ayristirici eklemek o karari sessizce bozardi.
    const { xlsxSatirlari } = await import("@/lib/xlsx-oku");
    let matris: string[][];
    try {
      matris = await xlsxSatirlari(dosya);
    } catch {
      toast.error(t("iceAktarimDosyaOkunamadi"));
      return;
    }
    const basliklar = (matris[0] ?? []).map((h) => h.trim());
    const hazir = matris.slice(1).map((satir, i) => ({
      satir_no: i + 2,
      degerler: Object.fromEntries(
        basliklar.map((h, j) => [h, (satir[j] ?? "").trim()]),
      ),
    }));
    setSatirlar(hazir);
    try {
      const sonuc = (await apiSend("/api/vardiya-plani/ice-aktar", "POST", {
        satirlar: hazir,
        yalniz_dogrula: true,
      })) as IceSonuc;
      setIceSonuc(sonuc);
    } catch (e) {
      hata(e);
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-2" data-test="vardiya-araclar">
      <Dugme
        type="button"
        boy={KUCUK}
        tur={IKINCIL}
        data-test="vardiya-araclar-ac"
        onClick={() => setAraclarAcik(true)}
      >
        {t("vardiyaAraclar")}
      </Dugme>
      <Dugme
        type="button"
        boy={KUCUK}
        tur={IKINCIL}
        data-test="vardiya-excel-ac"
        onClick={() => setIceAcik(true)}
      >
        {t("vardiyaExcel")}
      </Dugme>
      {/* YAYINLA — SAYILI. Bekleyen yoksa da cizilir ama devre disi:
          dugmeyi gizlemek, "yayinlamayi unuttum mu" sorusunu
          yanitlayacak yeri de gizlerdi. */}
      <Dugme
        type="button"
        boy={KUCUK}
        tur={(yayin.data?.bekleyen ?? 0) > 0 ? BIRINCIL : IKINCIL}
        disabled={bekliyor || (yayin.data?.bekleyen ?? 0) === 0}
        data-test="vardiya-yayinla"
        onClick={() => {
          setBekliyor(true);
          void (async () => {
            try {
              const r = (await apiSend(
                `/api/vardiya-plani/yayinla?baslangic=${baslangic}&gun=${gun}`,
                "POST",
                {},
              )) as { yayinlanan: number };
              toast.success(t("vardiyaYayinlandi", { n: r.yayinlanan }));
              await yayin.mutate();
              onDegisti();
            } catch (e) {
              hata(e);
            } finally {
              setBekliyor(false);
            }
          })();
        }}
      >
        {t("vardiyaYayinlaSayili", { n: yayin.data?.bekleyen ?? 0 })}
      </Dugme>
      {(yayin.data?.taslak ?? 0) > 0 && (
        <Rozet durum="uyari">{t("vardiyaTaslak")}</Rozet>
      )}

      {/* ----------------------------- ARACLAR ------------------------- */}
      <Modal
        acik={araclarAcik}
        baslik={t("vardiyaAraclar")}
        onKapat={() => setAraclarAcik(false)}
      >
        <div className="space-y-2">
          <Dugme
            type="button"
            tur={IKINCIL}
            data-test="vardiya-arac-kopyala"
            onClick={() => {
              setAraclarAcik(false);
              setKopyaAcik(true);
            }}
          >
            {t("vardiyaHaftadanKopyala")}
          </Dugme>
          <Dugme
            type="button"
            tur={IKINCIL}
            data-test="vardiya-arac-kalip"
            onClick={() => {
              setAraclarAcik(false);
              onKalipAc();
            }}
          >
            {t("vardiyaKalipUygula")}
          </Dugme>
          <Dugme
            type="button"
            tur={IKINCIL}
            data-test="vardiya-arac-sablonlar"
            onClick={() => {
              setAraclarAcik(false);
              onSablonlaraGit();
            }}
          >
            {t("vardiyaSablonlari")}
          </Dugme>
        </div>
      </Modal>

      {/* ------------------------ HAFTADAN KOPYALA --------------------- */}
      <Modal
        acik={kopyaAcik}
        baslik={t("vardiyaHaftadanKopyala")}
        onKapat={() => setKopyaAcik(false)}
      >
        <div className="space-y-3">
          <AlanSarmal etiket={t("vardiyaKaynakHafta")}>
            {(p) => (
              <Alan
                {...p}
                type="date"
                data-test="vardiya-kopya-kaynak"
                value={kaynak}
                onChange={(e) => setKaynak(pazartesi(e.target.value))}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("vardiyaHedefHafta")}>
            {(p) => (
              <Alan
                {...p}
                type="date"
                data-test="vardiya-kopya-hedef"
                value={hedef}
                onChange={(e) => setHedef(pazartesi(e.target.value))}
              />
            )}
          </AlanSarmal>
          <label
            className="flex items-center gap-2"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
          >
            <input
              type="checkbox"
              className="h-4 w-4"
              data-test="vardiya-kopya-temizle"
              checked={temizle}
              onChange={(e) => setTemizle(e.target.checked)}
            />
            {t("vardiyaHedefiTemizle")}
          </label>
          <Dugme
            type="button"
            tur={BIRINCIL}
            disabled={bekliyor}
            data-test="vardiya-kopya-uygula"
            onClick={() => {
              setBekliyor(true);
              void (async () => {
                try {
                  const r = (await apiSend(
                    "/api/vardiya-plani/haftadan-kopyala",
                    "POST",
                    {
                      kaynak_baslangic: kaynak,
                      hedef_baslangic: hedef,
                      hedefi_temizle: temizle,
                    },
                  )) as KopyaSonuc;
                  // SEBEPLER DE GOSTERILIR: "31'i kopyalandi" deyip
                  // gerisini yutmak, eksigi sahada fark ettirirdi.
                  const sebep = r.sebepler
                    .map((x) =>
                      x === "izin" ? t("vardiyaSebepIzin") : t("vardiyaSebepCakisma"),
                    )
                    .join(VIRGUL);
                  toast.success(
                    `${t("vardiyaKopyaSonuc", {
                      eklenen: r.eklenen,
                      atlanan: r.atlanan,
                    })}${sebep ? ` — ${sebep}` : ""}`,
                  );
                  setKopyaAcik(false);
                  onDegisti();
                } catch (e) {
                  hata(e);
                } finally {
                  setBekliyor(false);
                }
              })();
            }}
          >
            {t("vardiyaHaftadanKopyala")}
          </Dugme>
        </div>
      </Modal>

      {/* ------------------------------ EXCEL -------------------------- */}
      <Modal
        acik={iceAcik}
        baslik={t("vardiyaExcel")}
        onKapat={() => {
          setIceAcik(false);
          setIceSonuc(null);
        }}
      >
        <div className="space-y-3">
          <Dugme
            type="button"
            tur={IKINCIL}
            data-test="vardiya-excel-disa"
            onClick={() =>
              void indir(
                `/api/vardiya-plani/disa-aktar?baslangic=${baslangic}&gun=${gun}`,
                `vardiya-${baslangic}.xlsx`,
              )
            }
          >
            {t("vardiyaDisaAktar")}
          </Dugme>
          <Dugme
            type="button"
            tur={IKINCIL}
            data-test="vardiya-excel-sablon"
            onClick={() =>
              void indir("/api/vardiya-plani/ornek-sablon", "vardiya-sablon.xlsx")
            }
          >
            {t("vardiyaOrnekSablon")}
          </Dugme>
          <div>
            <input
              ref={dosyaRef}
              type="file"
              accept=".xlsx"
              className="hidden"
              // GIZLI OLSA DA ADI OLMALI: ekran okuyucu gizli bir
              // girdiyi de duyurabilir ve `erisilebilir-etiket` kilidi
              // (hakli olarak) adsiz denetimi kusur sayiyor.
              aria-label={t("vardiyaIceAktarDosya")}
              data-test="vardiya-excel-dosya"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) void dosyaSecildi(f);
              }}
            />
            <Dugme
              type="button"
              tur={IKINCIL}
              data-test="vardiya-excel-ice"
              onClick={() => dosyaRef.current?.click()}
            >
              {t("vardiyaIceAktarDosya")}
            </Dugme>
          </div>

          {iceSonuc && (
            <div data-test="vardiya-ice-onizleme" className="space-y-2">
              <p
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
              >
                {t("vardiyaIceAktarOnizleme", {
                  basarili: iceSonuc.basarili,
                  hatali: iceSonuc.hatali,
                })}
              </p>
              {/* HATALI SATIRLAR TEK TEK: "bir yerde sorun var" deyip
                  kullaniciyi aramaya gondermek, sessiz atlamanin
                  kibarca yapilmis hali olurdu. */}
              <ul className="max-h-40 overflow-y-auto">
                {iceSonuc.satirlar
                  .filter((s) => s.durum === "hata")
                  .map((s) => (
                    <li
                      key={s.satir_no}
                      data-test={`vardiya-ice-hata-${s.satir_no}`}
                      style={{
                        fontSize: "var(--yz-fs-xs)",
                        color: "var(--yz-danger)",
                      }}
                    >
                      {t("vardiyaSatirNo")} {s.satir_no}: {s.mesaj}
                    </li>
                  ))}
              </ul>
              <Dugme
                type="button"
                tur={BIRINCIL}
                disabled={bekliyor || iceSonuc.basarili === 0}
                data-test="vardiya-ice-uygula"
                onClick={() => {
                  setBekliyor(true);
                  void (async () => {
                    try {
                      const r = (await apiSend(
                        "/api/vardiya-plani/ice-aktar",
                        "POST",
                        { satirlar, yalniz_dogrula: false },
                      )) as IceSonuc;
                      toast.success(
                        t("vardiyaIceAktarBitti", { n: r.basarili }),
                      );
                      onParti?.(r.parti_id ?? null);
                      setIceAcik(false);
                      setIceSonuc(null);
                      onDegisti();
                    } catch (e) {
                      hata(e);
                    } finally {
                      setBekliyor(false);
                    }
                  })();
                }}
              >
                {t("vardiyaIceAktarUygula")}
              </Dugme>
            </div>
          )}
        </div>
      </Modal>
    </div>
  );
}
