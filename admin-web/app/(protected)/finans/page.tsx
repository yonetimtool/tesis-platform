"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

// (P245) OZET SERIDI IKONLARI.
const IKON_FATURA = "M8 3h8a2 2 0 0 1 2 2v16l-3-2-3 2-3-2-3 2V5a2 2 0 0 1 2-2ZM9 8h6M9 12h6";
const IKON_PARA = "M12 3v18M16 7.5C16 6 14.2 5 12 5S8 6 8 7.5 9.8 10 12 10s4 1 4 2.5S14.2 15 12 15s-4-1-4-2.5";
const IKON_BORC = "M12 9v4m0 4h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z";
const IKON_KASA = "M3 6h18v12H3zM3 10h18M7 14h4";
const IKON_DOSYA = "M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8zM14 3v5h5";

function FinansIkonu({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

import { Alan, AlanSarmal, BosDurum, Dugme, FiltreCubugu, HataDurumu, Kart, Modal, Secim, Tablo, TabloBasligi, Td, Th, type Kolon, type TabloDurumu, VeriTablosu,
  OzetKarti,
  OzetSeridi,
  SayfaBasligi,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend, genIdempotencyKey } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { BagimlilikUyarisi } from "@/components/BagimlilikUyarisi";
import { kurusToTL, tlToKurus } from "@/lib/money";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

/**
 * P40 — FINANS bolumu (P29 API'si).
 *
 * NEDEN OZET + KASA + HAREKET AYNI SAYFADA: bunlar tek bir soruyu
 * yanitlar — "para nerede ve bugun ne oldu". Ayri sayfalara bolmek,
 * kullaniciyi ayni sorunun parcalari arasinda gezdirirdi.
 *
 * BAKIYE SAKLANMAZ, DEFTERDEN TURETILIR (P29 karari): bu sayfa da bakiyeyi
 * hicbir yerde kendisi hesaplamaz — `/finans/kasa-bakiyeleri` ne diyorsa
 * onu cizer. Istemcide toplam almak, iki yerde iki farkli rakam demekti.
 */

interface KasaBakiye {
  kasa_id: string;
  kod: string;
  ad: string;
  bakiye_kurus: number;
  /** (P192 §2.2) Onay bekleyen cikis — bakiyeye DAHIL DEGIL. */
  bekleyen_cikis_kurus: number;
  banka_mi: boolean;
}
interface Hareket {
  id: string;
  tip: string;
  yon: string;
  tutar_kurus: number;
  tarih: string;
  kasa_ad: string | null;
  user_ad: string | null;
  belge_no: string | null;
  aciklama: string | null;
}
interface Ozet {
  borclandirilan_ay_kurus: number;
  tahsil_edilen_ay_kurus: number;
  acik_borc_kurus: number;
  kasa_toplam_kurus: number;
  icra_acik_dosya: number;
}

const TIPLER = ["tahsilat", "gider", "gelir", "virman", "iade", "acilis"] as const;
/** Suzgec degeri: alti tipten biri ya da "" (hepsi). */
type TipSecimi = "" | (typeof TIPLER)[number];

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const YON_GIRIS = "giris" as const;

export default function FinansPage() {
  const t = useT();
  const toast = useToast();
  // (P160) SAYFALAMA `VeriTablosu` durumuna gecti.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  // (P154 / Asama 7.1) Menuden gelen `?tip=gelir` gibi baglantilar
  // burada karsilanir; okunmasaydi menu satiri dogru adrese gider ama
  // sayfa tum hareketleri gosterirdi.
  const [tip, setTip] = useSorguSecimi<TipSecimi>("tip", TIPLER, "");

  const suzgec = tip ? `&tip=${encodeURIComponent(tip)}` : "";
  const { data: ozet, error: ozetErr } = useSWR<Ozet>(
    "/api/panel/finans-ozet",
    jsonFetcher,
  );
  const {
    data: kasalar,
    error: kasaErr,
    mutate: kasalariTazele,
  } = useSWR<{
    items: KasaBakiye[];
    genel_toplam_kurus: number;
    bekleyen_cikis_toplam_kurus: number;
  }>(
    "/api/panel/kasa-bakiyeleri",
    jsonFetcher,
  );
  const {
    data: hareketler,
    error: harErr,
    isLoading: harYukleniyor,
    mutate: hareketleriTazele,
  } = useSWR<{ items: Hareket[]; meta: { total: number } }>(
    `/api/panel/finans-hareketler?limit=${tabloDurumu.boy}&offset=${offset}${suzgec}`,
    jsonFetcher,
  );

  // --- yeni hareket ---
  const [yTip, setYTip] = useState<string>("gider");
  const [yTutar, setYTutar] = useState("");
  const [yKasa, setYKasa] = useState("");
  const [yTarih, setYTarih] = useState("");
  const [yAciklama, setYAciklama] = useState("");
  const [yHata, setYHata] = useState<string | null>(null);
  const [ymesgul, setYMesgul] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  // (P64) CIFT KAYIT KORUMASI. Dugmenin `ymesgul` kilidi yalniz HIZLI CIFT
  // TIKLAMAYI onler; korunmayan sey ZAMAN ASIMI SONRASI TEKRARDI — istek
  // sunucuya ulasip yanit donmezse kullanici "kaydedilmedi" sanip tekrar
  // basar ve kasada IKI hareket olusurdu. Anahtar FORM DOLDURMA ANINDA
  // uretilir ve BASARIYA KADAR sabit kalir: tekrar denemeler ayni anahtarla
  // gider, sunucu ikinci kaydi acmaz. Basarinin ardindan yenilenir ki
  // SONRAKI (mesru) hareket ayri bir islem sayilsin.
  const [yAnahtar, setYAnahtar] = useState(() => genIdempotencyKey());

  async function hareketEkle(): Promise<void> {
    setYHata(null);
    const kurus = tlToKurus(yTutar);
    if (!kurus || kurus <= 0) {
      setYHata(t("finansTutarGerekli"));
      return;
    }
    setYMesgul(true);
    try {
      // Toplu uc TEK KAYIT icin de kullanilir: iki ayri uc, ayni
      // dogrulamayi iki kez yazmak olurdu (P29 karari).
      await apiSend("/api/panel/finans-hareketler", "POST", {
        hareketler: [
          {
            tip: yTip,
            tutar_kurus: kurus,
            kasa_id: yKasa || null,
            tarih: yTarih || undefined,
            aciklama: yAciklama || null,
          },
        ],
      }, { "Idempotency-Key": yAnahtar });
      setYAnahtar(genIdempotencyKey());
      setYTutar("");
      setYAciklama("");
      toast.success(t("finansHareketEklendi"));
      await hareketleriTazele();
    } catch (e) {
      setYHata(e instanceof Error ? e.message : String(e));
    } finally {
      setYMesgul(false);
    }
  }

  const kolonlar: Kolon<Hareket>[] = useMemo(
    () => [
      {
        id: "tarih",
        baslik: t("finansTarih"),
        gizlenebilir: false,
        hucre: (h) => <span className="whitespace-nowrap">{formatDateTime(h.tarih)}</span>,
      },
      { id: "tip", baslik: t("finansTip"), hucre: (h) => t(`finansTip_${h.tip}` as never) },
      { id: "kasa", baslik: t("finansKasa"), hucre: (h) => h.kasa_ad ?? "—" },
      {
        id: "kisi",
        baslik: t("finansKisi"),
        darEkrandaGizle: true,
        hucre: (h) => h.user_ad ?? "—",
      },
      {
        id: "aciklama",
        baslik: t("finansAciklama"),
        darEkrandaGizle: true,
        hucre: (h) => h.aciklama ?? h.belge_no ?? "—",
      },
      {
        id: "tutar",
        baslik: t("finansTutar"),
        sayisal: true,
        gizlenebilir: false,
        // YON RENGI: tutar her zaman POZITIFTIR (P29); giris/cikis ayrimi
        // ISARETLE anlatilir, renk yalnizca pekistirir. Renk TEK BASINA
        // tasiyici olsaydi renk koru kullanici ayrimi kaybederdi.
        hucre: (h) => (
          <span
            className="tabular-nums"
            style={{
              color:
                h.yon === YON_GIRIS ? "var(--yz-success-ink)" : "var(--yz-danger-ink)",
            }}
          >
            {h.yon === YON_GIRIS ? "+" : "−"}
            {kurusToTL(h.tutar_kurus)}
          </span>
        ),
      },
    ],
    [t],
  );

  return (
    <div>
      <SayfaBasligi
        baslik={t("finansBaslik")}
        aciklama={t("finansAlt")}
        eylem={
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden
              // acildiginda onceki denemenin mesaji ekranda duruyordu ve
              // kullanici hic denemeden hata gormus oluyordu.
              setYHata(null);
              setModalAcik(true);
            }}
          >
            {t("finansYeniHareket")}
          </Dugme>
        }
      />

      {/* ------------------------------- ozet ------------------------------ */}
      {/* (P245) YEREL `OzetKart` -> PAYLASILAN `OzetSeridi`/`OzetKarti`.
          -----------------------------------------------------------------
          Sayfa kendi kart bilesenini tasiyordu: etiket + sayi, ikon yok,
          durum rengi yok. Ayni ekranda (referans ui2 "Finans") kartlar
          ikonlu ve anlam tasiyor. Ikinci bir kart tanimi, bosluk ve
          tipografinin iki yerde ayrismasi demekti; P244 boyunca
          kapatilan tam o sinif.
          DEGERLER DEGISMEDI: ayni uctan, ayni alanlar. */}
      {ozetErr && <HataDurumu mesaj={t("finansOzetHata")} />}
      {ozet ? (
        <OzetSeridi>
          <OzetKarti
            etiket={t("finansOzetBorclandirilan")}
            deger={kurusToTL(ozet.borclandirilan_ay_kurus)}
            durum="notr"
            ikon={<FinansIkonu yol={IKON_FATURA} />}
          />
          <OzetKarti
            etiket={t("finansOzetTahsil")}
            deger={kurusToTL(ozet.tahsil_edilen_ay_kurus)}
            durum="olumlu"
            ikon={<FinansIkonu yol={IKON_PARA} />}
          />
          <OzetKarti
            etiket={t("finansOzetAcikBorc")}
            deger={kurusToTL(ozet.acik_borc_kurus)}
            durum={ozet.acik_borc_kurus > 0 ? "uyari" : "olumlu"}
            ikon={<FinansIkonu yol={IKON_BORC} />}
            href="/finans/borclular"
          />
          <OzetKarti
            etiket={t("finansOzetKasa")}
            deger={kurusToTL(ozet.kasa_toplam_kurus)}
            durum="bilgi"
            ikon={<FinansIkonu yol={IKON_KASA} />}
          />
          <OzetKarti
            etiket={t("finansOzetIcra")}
            deger={String(ozet.icra_acik_dosya)}
            durum={ozet.icra_acik_dosya > 0 ? "kritik" : "olumlu"}
            ikon={<FinansIkonu yol={IKON_DOSYA} />}
            href="/icra"
          />
        </OzetSeridi>
      ) : null}

      {/* (P154 / Asama 7.4) Kasa yoksa tahsilat AKISI TAMAMLANAMAZ:
          `POST /finans/tahsilat` govdesinde `kasa_id` zorunlu (envanter
          §0.4). Bugun kullanici bunu ancak formu doldurup takilinca
          anliyor. */}
      <BagimlilikUyarisi
        kod="kasa"
        eksik={(kasalar?.items.length ?? 1) === 0}
      />

      {/* ------------------------------ kasalar ----------------------------
          `VeriTablosu`ya TASINMADI ve bu bilincli: bu tablonun bir TOPLAM
          SATIRI var; genel toplam sunucudan gelir ve satirlarla birlikte
          gorunmelidir. Genel tablo bileseni altbilgi satiri tasimiyor,
          onun icin oraya bir kavram eklemek yerine bu ozel tablo kendi
          ilkelleriyle kaldi. */}
      <Kart>
        <h2 className="mb-3" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("finansKasalar")}
        </h2>
        {kasaErr && <HataDurumu mesaj={t("finansKasaHata")} onTekrar={() => void kasalariTazele()} />}
        {kasalar && kasalar.items.length === 0 && !kasaErr ? (
          <BosDurum baslik={t("finansKasaYok")} aciklama={t("finansKasaYokAlt")} />
        ) : null}
        {kasalar && kasalar.items.length > 0 ? (
          <div className="overflow-x-auto">
            <Tablo>
              <TabloBasligi zeminsiz>
                <Th sik>{t("finansKasaKod")}</Th>
                <Th sik>{t("finansKasaAd")}</Th>
                <Th sik hizala="end">{t("finansBakiye")}</Th>
                {/* (P192 §2.2) BEKLEYEN AYRI SUTUN: onay bekleyen gider
                    bakiyeye dahil DEGIL. Onceden bakiyeye karisiyordu ve
                    yonetici elinde olmayan parayi yokmus gibi goruyordu.
                    Tek rakam yerine "bakiye X, bekleyen Y". */}
                <Th sik hizala="end">{t("finansKasaBekleyen")}</Th>
              </TabloBasligi>
              <tbody>
                {kasalar.items.map((k) => (
                  <tr key={k.kasa_id} style={{ borderTop: "1px solid var(--yz-border)" }}>
                    <Td sik className="font-mono text-xs">{k.kod}</Td>
                    <Td sik>{k.ad}</Td>
                    <Td sik hizala="end" sayi>{kurusToTL(k.bakiye_kurus)}</Td>
                    <Td sik hizala="end" sayi>
                      <span
                        title={t("finansKasaBekleyenIpucu")}
                        style={{ color: "var(--yz-text-2)" }}
                      >
                        {k.bekleyen_cikis_kurus > 0
                          ? kurusToTL(k.bekleyen_cikis_kurus)
                          : "—"}
                      </span>
                    </Td>
                  </tr>
                ))}
                <tr
                  className="font-semibold"
                  style={{ borderTop: "2px solid var(--yz-border-strong)" }}
                >
                  <Td sik colSpan={2}>{t("finansGenelToplam")}</Td>
                  <Td sik hizala="end" sayi>
                    {kurusToTL(kasalar.genel_toplam_kurus)}
                  </Td>
                  <Td sik hizala="end" sayi>
                    <span style={{ color: "var(--yz-text-2)" }}>
                      {kasalar.bekleyen_cikis_toplam_kurus > 0
                        ? kurusToTL(kasalar.bekleyen_cikis_toplam_kurus)
                        : "—"}
                    </span>
                  </Td>
                </tr>
              </tbody>
            </Tablo>
          </div>
        ) : null}
      </Kart>

      {/* --------------------------- yeni hareket -------------------------- */}
      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("finansYeniHareket")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={ymesgul}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
          tur="birincil"
          className="mt-3"
          disabled={ymesgul}
          yukleniyor={ymesgul}
          onClick={() => void hareketEkle()}
        >
          {t("finansEkle")}
        </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          {yHata && (
          <p
            role="alert"
            className="mb-3"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
          >
            {yHata}
          </p>
        )}
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <AlanSarmal etiket={t("finansTip")}>
            {(b) => (
              <Secim {...b} value={yTip} onChange={(e) => setYTip(e.target.value)}>
                {TIPLER.map((x) => (
                  <option key={x} value={x}>
                    {t(`finansTip_${x}` as never)}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansTutar")}>
            {(b) => (
              <Alan
                {...b}
                inputMode="decimal"
                value={yTutar}
                onChange={(e) => setYTutar(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansKasa")}>
            {(b) => (
              <Secim {...b} value={yKasa} onChange={(e) => setYKasa(e.target.value)}>
                <option value="">—</option>
                {(kasalar?.items ?? []).map((k) => (
                  <option key={k.kasa_id} value={k.kasa_id}>
                    {k.ad}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansTarih")}>
            {(b) => (
              <Alan {...b} type="date" value={yTarih} onChange={(e) => setYTarih(e.target.value)} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansAciklama")}>
            {(b) => (
              <Alan {...b} value={yAciklama} onChange={(e) => setYAciklama(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
        </div>
      </Modal>

      {/* ----------------------------- hareketler -------------------------- */}
      <div className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("finansHareketler")}
        </h2>
        {/* HATA SESSIZ KALMAZ: uc dustugunde "kayit yok" gostermek,
            kullaniciya kasanin bos oldugunu soylemek olurdu. Karar artik
            `VeriTablosu`nun icinde (`hata` ozelligi). */}
        {/* (P244 §9c) SUZGEC TABLONUN DISINDA: `araclar` yuvasinda
            kalsaydi liste hata alinca suzgec de kaybolurdu — oysa
            tabloyu hata durumuna sokan sey cogu zaman SUZGECIN KENDISI
            olur ve kullanicinin ilk refleksi onu degistirmektir. */}
        <FiltreCubugu
          aktifSayi={tip ? 1 : 0}
          onTemizle={() => {
            setTip("" as TipSecimi);
            setTabloDurumu({ ...tabloDurumu, sayfa: 1 });
          }}
        >
          {/* (P63) Suzgecin HICBIR etiketi yoktu: ekran okuyucu yalnizca
              "acilir liste" der ve kullanici neyi suzdugunu bilmez. */}
          <Secim
            aria-label={t("finansTipSuzgeci")}
            value={tip}
            onChange={(e) => {
              setTip(e.target.value as TipSecimi);
              setTabloDurumu({ ...tabloDurumu, sayfa: 1 });
            }}
            className="w-auto"
          >
            <option value="">{t("finansHepsi")}</option>
            {TIPLER.map((x) => (
              <option key={x} value={x}>
                {t(`finansTip_${x}` as never)}
              </option>
            ))}
          </Secim>
        </FiltreCubugu>

        <VeriTablosu<Hareket>
          kolonlar={kolonlar}
          satirlar={hareketler?.items ?? []}
          satirId={(h) => h.id}
          hata={harErr ? t("finansHareketHata") : null}
          onTekrar={() => void hareketleriTazele()}
          yukleniyor={harYukleniyor && !hareketler}
          bosBaslik={t("finansHareketYok")}
          bosAciklama={t("finansHareketYokAlt")}
          sunucuTarafli
          toplam={hareketler?.meta?.total ?? 0}
          durum={tabloDurumu}
          onDurumDegisti={setTabloDurumu}
        />
      </div>
    </div>
  );
}

/**
 * OZET KARTI — SAYAC ANIMASYONU YOK, bilincli karar.
 *
 * `Kpi` bileseni sayiyi sifirdan hedefe SAYARAK gosterir; panoda bu hos
 * duruyor. Ama burada gosterilen sey PARADIR: animasyon suresince ekranda
 * GERCEK OLMAYAN bir bakiye yazar. Bir finans ekraninda yarim saniye
 * yanlis rakam gostermek, hos bir gecisin kazandiracagi seyden pahalidir.
 * Kart yine ayni metal dilini kullanir (kabartilmis yuzey, gumus kenar),
 * yalnizca sayi hemen dogru degerdedir.
 */

