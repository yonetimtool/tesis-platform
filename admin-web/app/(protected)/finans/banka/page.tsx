"use client";

/**
 * (P191 §4) BANKA ENTEGRASYONU — ekstre yukle, eslestir, eslesmeyenleri ata.
 *
 * =========================================================================
 * DOSYA PANELDE AYRISTIRILIR
 * =========================================================================
 * CSV/XLSX ayristirma sunucuda BIR SALDIRI YUZEYIDIR (zip bombasi, XXE,
 * formul enjeksiyonu) ve panel dosyayi zaten onizleme gostermek icin
 * okumak zorunda — P28/P29'da verilen karar aynen suruyor. Sunucuya
 * YAPILANDIRILMIS satirlar gider ve sunucu her satiri yeniden dogrular.
 *
 * MT940 ISTISNADIR: duz metindir (zip yok, XML yok) ve bankadan panelin
 * okuyamayacagi uzantilarla (`.sta`, `.940`) iner — o dosya ham metin
 * olarak sunucuya gonderilir.
 *
 * =========================================================================
 * SUTUN ESLEMESI NEDEN VAR
 * =========================================================================
 * Her bankanin ekstre basligi farklidir ("Tarih"/"Islem Tarihi"/"Date").
 * Basliklar SEZILIR ama karar kullaniciya birakilir: yanlis sezilen bir
 * sutun, tutari tarih sanan sessiz bir ice aktarma demekti.
 */
import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  AlanSarmal,
  Dugme,
  HataDurumu,
  Rozet,
  Secim,
  VeriTablosu,
  type Kolon,
  type RozetDurumu,
} from "@/components/ui";
import { Kart } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { kurusToTL } from "@/lib/money";
import type { UserListResponse } from "@/lib/types";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const UC_LISTE = "/api/banka/hareketler";
const UC_ICE_AKTAR = "/api/banka/ice-aktar";
const UC_ESLESTIR = "/api/banka/eslestir";
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
const TUR_TEHLIKE = "tehlike" as const;
const BOS = "" as const;

type Eslesme = {
  id: string;
  user_id: string | null;
  assessment_id: string | null;
  tutar_kurus: number;
  confidence_score: number;
  match_type: string;
  durum: string;
  receipt_id: string | null;
};

type Hareket = {
  id: string;
  islem_tarihi: string;
  tutar_kurus: number;
  yon: string;
  aciklama: string | null;
  karsi_ad: string | null;
  karsi_iban_maskeli: string | null;
  durum: string;
  not_metni: string | null;
  eslesmeler: Eslesme[];
};

type Liste = { meta: { total: number }; items: Hareket[] };

/** Sekmeler = hareket durumlari. Varsayilan ESLESMEYENLER: yoneticinin
 *  burada yapacagi is odur; "hepsi" listesi onu aramaya zorlardi. */
const SEKMELER: [string, SozlukAnahtari][] = [
  ["manuel_inceleme", "bankaDurumManuel"],
  ["yeni", "bankaDurumYeni"],
  ["eslesti", "bankaDurumEslesti"],
  ["ilgisiz_gelir", "bankaDurumIlgisiz"],
  ["masraf", "bankaDurumMasraf"],
];

/** Sunucu durum kodu -> cevrilmis etiket. HAM ENUM ciziLMEZ (depo kurali
 *  `ham-enum`): kullanici `manuel_inceleme` degil "Eslesmeyenler" gorur. */
const DURUM_ETIKET: Record<string, SozlukAnahtari> = {
  yeni: "bankaDurumYeni",
  eslesti: "bankaDurumEslesti",
  manuel_inceleme: "bankaDurumManuel",
  ilgisiz_gelir: "bankaDurumIlgisiz",
  masraf: "bankaDurumMasraf",
  ters_kayit: "bankaDurumTersKayit",
};

const DURUM_ROZET: Record<string, RozetDurumu> = {
  yeni: "notr",
  eslesti: "olumlu",
  manuel_inceleme: "uyari",
  ilgisiz_gelir: "notr",
  masraf: "uyari",
  ters_kayit: "kritik",
};

/**
 * Baslik metninden alan sezgisi — KARAR KULLANICININ, bu yalniz on dolgu.
 *
 * DESENLER AKSANSIZ: baslik once `sadeBaslik` ile aksansiz buyuk harfe
 * indirgenir. Aksanli desen yazmak, ayni sutunu aksanli ve aksansiz yazan
 * iki bankada farkli davranmak demekti (ve Turkce buyuk-kucuk harf tuzagi
 * da cabasi: buyuk I-noktali harfin kucugu duz `i` DEGILDIR).
 */
const SEZGI: Record<string, RegExp> = {
  tarih: /TARIH|DATE|VALOR/,
  tutar: /TUTAR|AMOUNT|BORC|ALACAK|MIKTAR/,
  aciklama: /ACIKLAMA|DESCRIPTION|DESC|DETAY/,
  karsi_ad: /GONDEREN|AD SOYAD|UNVAN|KARSI|SENDER|NAME/,
  karsi_iban: /IBAN/,
  referans: /REFERANS|REFERENCE|DEKONT|ISLEM NO/,
};

/** Aksansiz + BUYUK + tek bosluk. Once buyut sonra aksani at (Turkce). */
function sadeBaslik(metin: string): string {
  return metin
    .toLocaleUpperCase("tr")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\u011e/g, "G")
    .replace(/\u015e/g, "S")
    .replace(/\s+/g, " ")
    .trim();
}

/** Kasa listesinden ekstre icin gereken alanlar. */
interface Kasa {
  id: string;
  ad: string;
  banka_mi: boolean;
}

function hucreler(satir: string): string[] {
  // Ayirici sezgisi: `;` (Excel TR), sekme, sonra `,`.
  const sayac = (c: string) => satir.split(c).length;
  const ayirici = sayac(";") > 1 ? ";" : sayac("\t") > 1 ? "\t" : ",";
  return satir.split(ayirici).map((h) => h.trim().replace(/^"|"$/g, ""));
}

export default function BankaSayfasi() {
  const t = useT();
  const toast = useToast();
  const [sekme, setSekme] = useState<string>(SEKMELER[0][0]);
  const [satirlar, setSatirlar] = useState<string[][]>([]);
  const [mt940, setMt940] = useState<string | null>(null);
  const [esleme, setEsleme] = useState<Record<string, string>>({});
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);
  const [secilenKisi, setSecilenKisi] = useState<Record<string, string>>({});
  // (P193 §3 / rehber eksik 9) EKSTRENIN AIT OLDUGU BANKA HESABI.
  //
  // Uc `kasa_id`yi P192'den beri kabul ediyor; panel HIC gondermiyordu,
  // yani iki banka hesabi olan bir tesiste ikinci hesabin ekstresi
  // SESSIZCE varsayilan hesaba yaziliyor ve iki bakiye birden yanlis
  // cikiyordu. Bos birakmak hâlâ mumkun (tek hesapli tesisin fazladan bir
  // secim yapmasi gereksizdir) ama artik BILINCLI bir tercih.
  const [kasaId, setKasaId] = useState<string>(BOS);

  const { data, error, isLoading, mutate } = useSWR<Liste>(
    `${UC_LISTE}?durum=${sekme}&limit=100`,
    jsonFetcher,
  );
  // Elle eslestirme icin kisi listesi — YALNIZ sakinler: borc daireye
  // yazilir ve daireye bagli olmayan birine odeme atamak anlamsizdir.
  const { data: kisiler } = useSWR<UserListResponse>(
    "/api/users?limit=200&role=resident",
    jsonFetcher,
  );
  // Yalniz BANKA kasalari: nakit kasaya ekstre yazmak anlamsiz olurdu.
  const { data: kasalar } = useSWR<{ items: Kasa[] }>(
    "/api/panel/kasalar?limit=100",
    jsonFetcher,
  );
  const bankaKasalari = (kasalar?.items ?? []).filter((k) => k.banka_mi);

  const basliklar = satirlar[0] ?? [];

  /** Bilinmeyen durum HAM gosterilir: sessizce "bilinmiyor" yazmak yeni bir
   *  sunucu durumunu gorunmez kilardi. */
  function durumAdi(durum: string): string {
    const anahtar = DURUM_ETIKET[durum];
    return anahtar ? t(anahtar) : durum;
  }

  async function dosyaSec(dosya: File | null) {
    if (!dosya) return;
    setHata(null);
    setMt940(null);
    setSatirlar([]);
    try {
      const metin = /\.xlsx$/i.test(dosya.name) ? null : await dosya.text();
      if (metin && metin.includes(":61:")) {
        // MT940: sunucuda ayristirilir (duz metin, guvenli).
        setMt940(metin);
        toast.success(t("bankaMt940Algilandi"));
        return;
      }
      const ham = /\.xlsx$/i.test(dosya.name)
        ? await (await import("@/lib/xlsx-oku")).xlsxSatirlari(dosya)
        : (metin ?? "").split(/\r?\n/).map((r) => hucreler(r.trimEnd()));
      const dolu = ham.filter((r) => r.some((h) => h.trim()));
      if (!dolu.length) {
        setHata(t("bankaDosyaBos"));
        return;
      }
      setSatirlar(dolu);
      // Basliklari SEZ, karari kullaniciya birak.
      const on: Record<string, string> = {};
      dolu[0].forEach((baslik, i) => {
        for (const [alan, desen] of Object.entries(SEZGI)) {
          if (!on[alan] && desen.test(sadeBaslik(baslik))) on[alan] = String(i);
        }
      });
      setEsleme(on);
    } catch {
      setHata(t("bankaDosyaOkunamadi"));
    }
  }

  async function iceAktar() {
    setBekliyor(true);
    setHata(null);
    try {
      let govde: Record<string, unknown>;
      // Secilmemisse ALAN HIC GONDERILMEZ: `null` gondermek "varsayilani
      // kullan" ile "hesap yok" arasindaki farki silerdi.
      const hedef = kasaId === BOS ? {} : { kasa_id: kasaId };
      if (mt940) {
        govde = { kaynak: "ekstre", mt940, ...hedef };
      } else {
        if (esleme.tarih === undefined || esleme.tutar === undefined) {
          setHata(t("bankaZorunluSutun"));
          return;
        }
        const al = (satir: string[], alan: string) =>
          esleme[alan] === undefined ? undefined : satir[Number(esleme[alan])];
        govde = {
          kaynak: "ekstre",
          ...hedef,
          satirlar: satirlar.slice(1).map((satir) => ({
            tarih: al(satir, "tarih") ?? "",
            tutar: al(satir, "tutar") ?? "",
            aciklama: al(satir, "aciklama") ?? "",
            karsi_ad: al(satir, "karsi_ad") ?? null,
            karsi_iban: al(satir, "karsi_iban") ?? null,
            referans: al(satir, "referans") ?? null,
          })),
        };
      }
      const d = (await apiSend(UC_ICE_AKTAR, "POST", govde)) as {
        eklenen?: number;
        yinelenen?: number;
      };
      toast.success(
        t("bankaIceAktarSonuc", {
          eklenen: String(d.eklenen ?? 0),
          yinelenen: String(d.yinelenen ?? 0),
        }),
      );
      setSatirlar([]);
      setMt940(null);
      await mutate();
    } catch (err) {
      setHata(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setBekliyor(false);
    }
  }

  async function eslestir() {
    setBekliyor(true);
    try {
      const d = (await apiSend(UC_ESLESTIR, "POST", {})) as {
        incelenen?: number;
        otomatik?: number;
        manuel?: number;
      };
      toast.success(
        t("bankaEslestirSonuc", {
          incelenen: String(d.incelenen ?? 0),
          otomatik: String(d.otomatik ?? 0),
          manuel: String(d.manuel ?? 0),
        }),
      );
      await mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setBekliyor(false);
    }
  }

  async function eylem(yol: string, govde: unknown, basari: SozlukAnahtari) {
    setBekliyor(true);
    try {
      await apiSend(yol, "POST", govde);
      toast.success(t(basari));
      await mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setBekliyor(false);
    }
  }

  const kolonlar = useMemo<Kolon<Hareket>[]>(
    () => [
      {
        id: "tarih",
        baslik: t("bankaTarih"),
        kartRolu: "ozet",
        hucre: (h) => formatDateTime(h.islem_tarihi),
      },
      {
        id: "tutar",
        baslik: t("bankaTutar"),
        kartRolu: "baslik",
        sayisal: true,
        hucre: (h) => kurusToTL(h.tutar_kurus),
      },
      {
        id: "gonderen",
        baslik: t("bankaGonderen"),
        hucre: (h) => (
          <span>
            {h.karsi_ad ?? "—"}
            {h.karsi_iban_maskeli ? (
              <span
                className="ms-2 font-mono"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {h.karsi_iban_maskeli}
              </span>
            ) : null}
          </span>
        ),
      },
      {
        id: "aciklama",
        baslik: t("bankaSutunAciklama"),
        darEkrandaGizle: true,
        hucre: (h) => (
          <span className="block max-w-xs truncate">{h.aciklama ?? "—"}</span>
        ),
      },
      {
        id: "durum",
        baslik: t("bankaDurum"),
        kartRolu: "rozet",
        hucre: (h) => (
          <span className="inline-flex items-center gap-2">
            <Rozet durum={DURUM_ROZET[h.durum] ?? "notr"}>{durumAdi(h.durum)}</Rozet>
            {h.eslesmeler.length ? (
              <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("bankaGuven")}: {h.eslesmeler[0].confidence_score}
              </span>
            ) : null}
          </span>
        ),
      },
      {
        id: "islem",
        baslik: t("bankaIslem"),
        kartRolu: "eylem",
        hucre: (h) => (
          <div className="flex flex-wrap items-center gap-2">
            {h.durum === "eslesti" ? (
              <>
                {h.eslesmeler[0]?.receipt_id ? (
                  <a
                    href={`/api/banka/makbuz/${h.eslesmeler[0].receipt_id}`}
                    target="_blank"
                    rel="noreferrer"
                    style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }}
                  >
                    {t("bankaMakbuz")}
                  </a>
                ) : null}
                <Dugme
                  boy="kucuk"
                  tur={TUR_TEHLIKE}
                  disabled={bekliyor}
                  onClick={() =>
                    void eylem(
                      `${UC_LISTE}/${h.id}/geri-al`,
                      { not_metni: null },
                      "ortakKaydedildi",
                    )
                  }
                >
                  {t("bankaGeriAl")}
                </Dugme>
              </>
            ) : (
              <>
                {h.yon === "giris" ? (
                  <>
                    <Secim
                      value={secilenKisi[h.id] ?? BOS}
                      aria-label={t("bankaKisiSec")}
                      onChange={(e) =>
                        setSecilenKisi({ ...secilenKisi, [h.id]: e.target.value })
                      }
                    >
                      <option value={BOS}>{t("bankaKisiSec")}</option>
                      {(kisiler?.items ?? []).map((k) => (
                        <option key={k.id} value={k.id}>
                          {k.ad}
                        </option>
                      ))}
                    </Secim>
                    <Dugme
                      boy="kucuk"
                      tur={TUR_BIRINCIL}
                      disabled={bekliyor || !secilenKisi[h.id]}
                      onClick={() =>
                        void eylem(
                          `${UC_LISTE}/${h.id}/manuel-eslestir`,
                          { user_id: secilenKisi[h.id] },
                          "ortakKaydedildi",
                        )
                      }
                    >
                      {t("bankaManuelEslestir")}
                    </Dugme>
                  </>
                ) : null}
                <Dugme
                  boy="kucuk"
                  tur={TUR_IKINCIL}
                  disabled={bekliyor}
                  onClick={() =>
                    void eylem(
                      `${UC_LISTE}/${h.id}/isaretle`,
                      { durum: "ilgisiz_gelir" },
                      "ortakKaydedildi",
                    )
                  }
                >
                  {t("bankaIlgisizIsaretle")}
                </Dugme>
                <Dugme
                  boy="kucuk"
                  tur={TUR_IKINCIL}
                  disabled={bekliyor}
                  onClick={() =>
                    void eylem(
                      `${UC_LISTE}/${h.id}/isaretle`,
                      { durum: "masraf" },
                      "ortakKaydedildi",
                    )
                  }
                >
                  {t("bankaMasrafIsaretle")}
                </Dugme>
              </>
            )}
          </div>
        ),
      },
    ],
    // `eylem`/`secilenKisi` her cizimde degisir; bagimliliklari elle tutuyoruz.
    [t, bekliyor, kisiler, secilenKisi], // eslint-disable-line react-hooks/exhaustive-deps
  );

  return (
    <div className="space-y-5">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("bankaBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("bankaAciklama")}
        </p>
      </div>

      <Kart>
        <div className="space-y-4">
          <h2 style={{ fontSize: "var(--yz-fs-h2)", color: "var(--yz-text)" }}>
            {t("bankaEkstreYukle")}
          </h2>
          <input
            type="file"
            accept=".csv,.txt,.xlsx,.sta,.940"
            aria-label={t("bankaDosyaSec")}
            data-test="banka-dosya"
            onChange={(e) => void dosyaSec(e.target.files?.[0] ?? null)}
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
          />
          {/* HESAP SECIMI DOSYADAN ONCE: hangi hesaba yazilacagi
              kararlastirilmadan yuklenen bir ekstre, yanlis bakiye
              uretir ve geri almak icin satir satir iptal gerekir. */}
          {bankaKasalari.length > 0 ? (
            <AlanSarmal etiket={t("bankaHedefHesap")} ipucu={t("bankaHedefHesapIpucu")}>
              {(b) => (
                <Secim
                  {...b}
                  value={kasaId}
                  data-test="banka-kasa"
                  onChange={(e) => setKasaId(e.target.value)}
                >
                  <option value={BOS}>{t("bankaHedefHesapVarsayilan")}</option>
                  {bankaKasalari.map((k) => (
                    <option key={k.id} value={k.id}>
                      {k.ad}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
          ) : null}
          {hata ? <HataDurumu mesaj={hata} /> : null}

          {satirlar.length > 0 ? (
            <>
              <h3 style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                {t("bankaSutunEsleme")}
              </h3>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                {(
                  [
                    ["tarih", "bankaSutunTarih"],
                    ["tutar", "bankaSutunTutar"],
                    ["aciklama", "bankaSutunAciklama"],
                    ["karsi_ad", "bankaSutunKarsiAd"],
                    ["karsi_iban", "bankaSutunIban"],
                    ["referans", "bankaSutunReferans"],
                  ] as [string, SozlukAnahtari][]
                ).map(([alan, etiket]) => (
                  <AlanSarmal key={alan} etiket={t(etiket)}>
                    {(b) => (
                      <Secim
                        {...b}
                        value={esleme[alan] ?? BOS}
                        onChange={(e) =>
                          setEsleme({ ...esleme, [alan]: e.target.value })
                        }
                      >
                        <option value={BOS}>{t("bankaSutunYok")}</option>
                        {basliklar.map((baslik, i) => (
                          <option key={`${baslik}-${i}`} value={String(i)}>
                            {baslik || `#${i + 1}`}
                          </option>
                        ))}
                      </Secim>
                    )}
                  </AlanSarmal>
                ))}
              </div>
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("bankaOnizleme")}
              </p>
              <div className="overflow-x-auto">
                <pre style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {satirlar
                    .slice(1, 6)
                    .map((r) => r.join(" | "))
                    .join("\n")}
                </pre>
              </div>
            </>
          ) : null}

          <div className="flex flex-wrap gap-2">
            <Dugme
              tur={TUR_BIRINCIL}
              disabled={bekliyor || (!mt940 && satirlar.length === 0)}
              onClick={() => void iceAktar()}
              data-test="banka-ice-aktar"
            >
              {t("bankaIceAktar")}
            </Dugme>
            <Dugme
              tur={TUR_IKINCIL}
              disabled={bekliyor}
              onClick={() => void eslestir()}
              data-test="banka-eslestir"
            >
              {t("bankaEslestirCalistir")}
            </Dugme>
          </div>
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("bankaMasrafNotu")}
          </p>
        </div>
      </Kart>

      <div className="flex flex-wrap gap-2">
        {SEKMELER.map(([deger, etiket]) => (
          <Dugme
            key={deger}
            boy="kucuk"
            tur={sekme === deger ? TUR_BIRINCIL : TUR_IKINCIL}
            aria-pressed={sekme === deger}
            onClick={() => setSekme(deger)}
          >
            {t(etiket)}
          </Dugme>
        ))}
      </div>

      <VeriTablosu<Hareket>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(h) => h.id}
        hata={error ? t("bankaYuklenemedi") : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("bankaBosBaslik")}
        bosAciklama={t("bankaBosAciklama")}
      />
    </div>
  );
}
