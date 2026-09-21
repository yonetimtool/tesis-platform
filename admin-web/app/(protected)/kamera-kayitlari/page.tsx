"use client";

// (P213 §6) GEÇMİŞ KAYIT İZLEME — NVR/DVR.
//
// ===========================================================================
// KAYITLAR BİZDE DEĞİL, SİTENİN CİHAZINDA
// ===========================================================================
// Kaydı kendimiz tutma seçeneği ölçüldü ve reddedildi: 2 Mbit/s'lik tek
// kamera ~21 GB/gün, 8 kameralı bir sitede 30 gün ~5 TB. Site zaten
// yerinde kayıt tutan bir NVR'a para vermiş durumda
// (docs/P213-06-gecmis-kayit-analiz.md §1.D).
//
// ===========================================================================
// NEDEN AYRI SAYFA (kameralar sayfasının içinde değil)
// ===========================================================================
// Erişim kümesi FARKLI: kamera YÖNETİMİ yönetici işidir, geçmiş kayıt
// İZLEME yönetici + güvenlik amiri işidir. Amire kamera formunu
// göstermek, hiçbirini yapamayacağı alanlar çizmek olurdu.
//
// ===========================================================================
// "ARAMA DESTEKLENMİYOR" ≠ "KAYIT YOK"
// ===========================================================================
// `şablon` sağlayıcısı oynatabilir ama arayamaz. İkisini aynı şekilde
// göstermek — boş şerit — kaydı olan bir günü boş gibi gösterip
// kullanıcıyı vazgeçirirdi. Sunucu bunu `arama_destekli` bayrağıyla
// ayırıyor; sayfa da ayrı bir mesajla.
import { useMemo, useState } from "react";
import useSWR from "swr";

// (P245) OZET SERIDI IKONLARI.
const IKON_KAMERA = "M23 7l-7 5 7 5V7zM1 5h15a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H1z";
const IKON_OYNAT = "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM10 8.5l5 3.5-5 3.5z";

function KayitIkonu({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

import { KameraOynatici } from "@/components/KameraOynatici";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Secim,
  OzetKarti,
  OzetSeridi,
  SayfaBasligi,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { Kamera } from "@/lib/types";

type Aralik = { bas: string; bit: string };
type AralikYanit = { arama_destekli: boolean; araliklar: Aralik[] };

// `yyyy-aa-gg` + `ss:dd` -> ISO (UTC). Tarayicinin yerel saat dilimi
// kullanilir: kullanici "14:00" derken KENDI saatini kastediyor.
function isoYap(gun: string, saat: string): string {
  return new Date(`${gun}T${saat}:00`).toISOString();
}

function saatMetni(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
}

function bugun(): string {
  return new Date().toISOString().slice(0, 10);
}

export default function KameraKayitlariPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Kamera[] }>(
    "/api/cameras?limit=100&offset=0",
    jsonFetcher,
  );

  // YALNIZ kaydı AÇIK kameralar listelenir. Kapalı olanı göstermek,
  // seçilince 422 veren bir seçenek sunmak olurdu.
  const kameralar = useMemo(
    () => (data?.items ?? []).filter((k) => k.kayit_aktif),
    [data],
  );

  const [kameraId, setKameraId] = useState("");
  const [gun, setGun] = useState(bugun());
  const [bas, setBas] = useState("08:00");
  const [bit, setBit] = useState("09:00");
  const [aralikYanit, setAralikYanit] = useState<AralikYanit | null>(null);
  const [aramaHatasi, setAramaHatasi] = useState<string | null>(null);
  const [araniyor, setAraniyor] = useState(false);
  const [oynatmaYolu, setOynatmaYolu] = useState<string | null>(null);
  const [hazirlaniyor, setHazirlaniyor] = useState(false);

  const secili = kameralar.find((k) => k.id === kameraId) ?? kameralar[0];

  async function ara() {
    if (!secili) return;
    setAraniyor(true);
    setAramaHatasi(null);
    setAralikYanit(null);
    try {
      const q = new URLSearchParams({
        bas: isoYap(gun, bas),
        bit: isoYap(gun, bit),
      });
      setAralikYanit(
        (await jsonFetcher(
          `/api/cameras/${secili.id}/kayit/araliklar?${q}`,
        )) as AralikYanit,
      );
    } catch (err) {
      // Sunucu TANILI mesaj döner ("cihaza ulaşılamadı", "cihaz
      // beklenmeyen yanıt verdi"). Genel bir cümleye indirgemek,
      // yöneticiyi yanlış yere bakmaya gönderirdi.
      setAramaHatasi(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setAraniyor(false);
    }
  }

  async function oynat(basIso: string, bitIso: string) {
    if (!secili) return;
    setHazirlaniyor(true);
    setAramaHatasi(null);
    setOynatmaYolu(null);
    try {
      const d = (await apiSend(`/api/cameras/${secili.id}/kayit/oynat`, "POST", {
        bas: basIso,
        bit: bitIso,
      })) as { yol: string };
      setOynatmaYolu(`/api${d.yol}`);
    } catch (err) {
      setAramaHatasi(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setHazirlaniyor(false);
    }
  }

  // KAYIT SAYISI DEGIL, KAYIT ALABILEN KAMERA SAYISI: uc aralik sorar,
  // liste dondurmez (bkz. serit yorumu).
  const oynatilabilirSayisi = kameralar.filter((k) => k.oynatilabilir).length;

  if (isLoading) return <IskeletMetin satir={4} />;
  if (error) return <HataDurumu />;

  return (
    <div>
      <SayfaBasligi baslik={t("kamKayitBaslik")} aciklama={t("kamKayitSayfaAlt")} />

      {/* (P245) OZET SERIDI — referansta (ui3) "Kamera Kayitlari"
          ekraninin ustunde de bir serit var.
          -----------------------------------------------------------------
          SAYILAR KAMERA LISTESINDEN: bu ekranin ucu bir ARALIK sorar ve
          kayit listesi DONDURMEZ; "kac kayit var" sorusunu yanitlayan
          bir uc YOK. Uydurmak yerine listenin yanitladigi sey yazildi.
          NVR KAYDI SITEDE KALIR (P213): bulutta bir kayit sayaci
          zaten olamaz. */}
      <OzetSeridi>
        <OzetKarti
          etiket={t("kamKayitOzetKamera")}
          deger={String(kameralar.length)}
          durum="notr"
          ikon={<KayitIkonu yol={IKON_KAMERA} />}
        />
        <OzetKarti
          etiket={t("kamKayitOzetOynatilabilir")}
          deger={String(oynatilabilirSayisi)}
          durum={oynatilabilirSayisi > 0 ? "olumlu" : "uyari"}
          ikon={<KayitIkonu yol={IKON_OYNAT} />}
          altBilgi={t("kamKayitOzetOynatilabilirAlt")}
        />
      </OzetSeridi>

      {kameralar.length === 0 ? (
        <BosDurum baslik={t("kamKayitKameraYok")} aciklama={t("kamKayitKameraYokAlt")} />
      ) : (
        <>
          <Kart>
            <div className="grid gap-3 sm:grid-cols-4">
              <AlanSarmal etiket={t("kamKayitKamera")}>
                {(b) => (
                  <Secim
                    {...b}
                    data-test="kayit-kamera"
                    value={secili?.id ?? ""}
                    onChange={(e) => {
                      setKameraId(e.target.value);
                      setAralikYanit(null);
                      setOynatmaYolu(null);
                    }}
                  >
                    {kameralar.map((k) => (
                      <option key={k.id} value={k.id}>
                        {k.ad}
                      </option>
                    ))}
                  </Secim>
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("kamKayitGun")}>
                {(b) => (
                  <Alan
                    {...b}
                    type="date"
                    data-test="kayit-gun"
                    value={gun}
                    max={bugun()}
                    onChange={(e) => setGun(e.target.value)}
                  />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("kamKayitBaslangic")}>
                {(b) => (
                  <Alan
                    {...b}
                    type="time"
                    data-test="kayit-bas"
                    value={bas}
                    onChange={(e) => setBas(e.target.value)}
                  />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("kamKayitBitis")}>
                {(b) => (
                  <Alan
                    {...b}
                    type="time"
                    data-test="kayit-bit"
                    value={bit}
                    onChange={(e) => setBit(e.target.value)}
                  />
                )}
              </AlanSarmal>
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              <Dugme onClick={ara} disabled={araniyor} data-test="kayit-ara">
                {t("kamKayitAra")}
              </Dugme>
              <Dugme
                tur="ikincil"
                data-test="kayit-oynat"
                disabled={hazirlaniyor}
                onClick={() => oynat(isoYap(gun, bas), isoYap(gun, bit))}
              >
                {t("kamKayitOynat")}
              </Dugme>
            </div>
            {aramaHatasi && (
              <p
                role="alert"
                className="mt-2"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
              >
                {aramaHatasi}
              </p>
            )}
          </Kart>

          {/* ---- ZAMAN ŞERİDİ ---- */}
          {aralikYanit && (
            <Kart>
              {!aralikYanit.arama_destekli ? (
                // "Arayamıyorum" ile "kayıt yok" AYRI şeyler.
                <p
                  data-test="kayit-arama-yok"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
                >
                  {t("kamKayitAramaYok")}
                </p>
              ) : aralikYanit.araliklar.length === 0 ? (
                <p
                  data-test="kayit-bulunamadi"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
                >
                  {t("kamKayitBulunamadi")}
                </p>
              ) : (
                <ul className="grid gap-2" data-test="kayit-araliklar">
                  {aralikYanit.araliklar.map((a) => (
                    <li key={`${a.bas}-${a.bit}`}>
                      <Dugme tur="ikincil" onClick={() => oynat(a.bas, a.bit)}>
                        {saatMetni(a.bas)} – {saatMetni(a.bit)}
                      </Dugme>
                    </li>
                  ))}
                </ul>
              )}
            </Kart>
          )}

          {/* ---- OYNATICI ---- */}
          {hazirlaniyor && <IskeletMetin satir={2} />}
          {oynatmaYolu && (
            <Kart>
              <KameraOynatici url={oynatmaYolu} mp4={false} />
            </Kart>
          )}
        </>
      )}
    </div>
  );
}
