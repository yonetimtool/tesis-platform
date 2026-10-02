"use client";

/**
 * (P240 §1) ACIL DURUM CAGRILARI — TAKIP EKRANI.
 *
 * =========================================================================
 * BU EKRAN OLMADAN SISTEM ISE YARAMAZ
 * =========================================================================
 * Istekteki cumle: "Alarm kime ulasti, kim gordu, kim 'gidiyorum' dedi,
 * mudahale suresi, kapanis". Bunlar bir alarmi bir OLAYA cevirir; bunsuz
 * sistem yalnizca "bir sey oldu" der ve hesap sorulamaz.
 *
 * MUDAHALE SURESI SUNUCUDAN GELIR (`mudahale_suresi_sn`): iki damganin
 * farkini istemcide hesaplamak, saati kaymis bir cihazda negatif sure
 * uretirdi.
 *
 * =========================================================================
 * SAKIN BU EKRANI GORMEZ
 * =========================================================================
 * Rol kapisi `ROTA_ROLLERI["/panik"]`de; sunucu da ayni siniri koyuyor.
 * Baska dairelerin acil durumlari kisisel veridir.
 */
import { useState } from "react";
import useSWR from "swr";

// (P245) SUZGEC DEGERLERI — UCLUDE DIZE YAZILMAZ (`sabit-metin`).
const SUZGEC_HEPSI = "" as const;
/** (P251 §1) Yedek liste — yalniz ILK YUKLEMEDE. Asil liste sunucunun
 *  enum'undan gelir (`durumlar`); P245'te elle yazilan liste "yanlis
 *  alarm"i eksik birakmisti. */
const PANIK_DURUMLARI_YEDEK = ["beklemede", "acik", "mudahale", "kapandi", "iptal", "yanlis_alarm"] as const;
/** (P251 §1) Tatbikat suzgeci: varsayilan GERCEK alarmlar. Tatbikatlarin
 *  kendi bolumu (rapor) asagida; listeye karismalari acil durum
 *  sayisini ve gorunurlugunu bulandiriyordu. */
const KAYNAK_GERCEK = "gercek" as const;
const KAYNAK_TATBIKAT = "tatbikat" as const;
const KAYNAK_HEPSI = "hepsi" as const;
type Kaynak = typeof KAYNAK_GERCEK | typeof KAYNAK_TATBIKAT | typeof KAYNAK_HEPSI;
const KAYNAK_SORGU: Record<Kaynak, string> = {
  gercek: "&tatbikat=false",
  tatbikat: "&tatbikat=true",
  hepsi: "",
};

// (P245) OZET SERIDI IKONLARI.
const IKON_ALARM = "M12 9v4m0 4h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z";
const IKON_TAKVIM = "M7 3v4M17 3v4M3 9h18M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z";
const IKON_ONAY = "M20 6 9 17l-5-5";

function PanikIkonu({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

import { Alan, BosDurum, Dugme, HataDurumu, Kart, Modal, Rozet, Tablo, TabloBasligi, Td, Th, Tr,
  OzetKarti,
  OzetSeridi,
  SayfaBasligi,
  FiltreCubugu,
  Secim,
  IskeletMetin,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { PanikDurumPaneli } from "@/components/panik/panik-durum";
import { TatbikatBolumu } from "@/components/panik/tatbikat-bolumu";
import { useRol } from "@/lib/rol-kullan";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { SINIR } from "@/lib/girdi-siniri";

type Alici = {
  user_id: string;
  ad: string;
  rol: string;
  goruldu_at: string | null;
  mudahale_at: string | null;
};
type Alarm = {
  id: string;
  tip: string;
  durum: string;
  olusturan_ad: string | null;
  daire_no: string | null;
  blok: string | null;
  checkpoint_ad: string | null;
  aciklama: string | null;
  created_at: string;
  kapandi_at: string | null;
  kapanis_notu: string | null;
  mudahale_suresi_sn: number | null;
  alicilar: Alici[];
  /** (P249 §1b) Istegin dilinde kategori basligi ve toplu uyari mi. */
  baslik: string;
  toplu: boolean;
  /** (P249 §2) Tatbikat alarmi mi. */
  tatbikat?: boolean;
};
/** (P251 §1) SUNUCUNUN SAYILARI — durum ve tatbikat suzgecinden bagimsiz. */
type Ozet = {
  acik: number;
  bugun: number;
  kapanan: number;
  yanlis_alarm: number;
  iptal: number;
  tatbikat: number;
};
type Liste = { items: Alarm[]; durumlar?: string[]; ozet?: Ozet | null };

const DURUM_ETIKET: Record<string, SozlukAnahtari> = {
  beklemede: "panikDurumBeklemede",
  acik: "panikDurumAcik",
  mudahale: "panikDurumMudahale",
  kapandi: "panikDurumKapandi",
  iptal: "panikDurumIptal",
  yanlis_alarm: "panikDurumYanlisAlarm",
};
const TIP_ETIKET: Record<string, SozlukAnahtari> = {
  sakin: "panikTipSakin",
  guvenlik: "panikTipGuvenlik",
  yonetici_anons: "panikTipAnons",
};
const IKINCIL = "ikincil" as const;
/** JSX ucluda sabit dize yazilamaz (depo kurali `sabit-metin`). */
const TIP_YEDEK: SozlukAnahtari = "panikTipBasligi";
const DURUM_YEDEK: SozlukAnahtari = "panikDurumAcik";
const BIRINCIL = "birincil" as const;

export default function PanikPage() {
  const t = useT();
  const toast = useToast();
  // (P245) DURUM SUZGECI — SUNUCUDA (`?durum=`).
  const [durumSuzgec, setDurumSuzgec] = useState<string>(SUZGEC_HEPSI);
  const [kaynak, setKaynak] = useState<Kaynak>(KAYNAK_GERCEK);
  // (P251 §1) TEK ISTEK, SAYILAR SUNUCUDAN.
  //
  // Onceden seridin sayilari IKINCI bir istekten (200 kayit) ve
  // ISTEMCIDE `kapandi_at == null` ile hesaplaniyordu. Iki kusur
  // OLCULDU: (1) iptal ve yanlis alarm `kapandi_at` YAZMAZ, yani
  // sonsuza kadar "acik" sayiliyordu (ekrandaki "Acik cagri: 2"nin
  // ikisi de yanlis alarm/iptaldi); (2) o istek HIC yenilenmiyordu —
  // kapatilan alarm seritte "acik" kaliyordu. Simdi `ozet` listeyle
  // ayni yanitta, durumdan hesaplanir ve 15 sn'de bir yenilenir.
  // Suzgecten BAGIMSIZDIR (P244 §8c dersi).
  const { data, error, isLoading, mutate } = useSWR<Liste>(
    `/api/panik?limit=50${durumSuzgec ? `&durum=${durumSuzgec}` : ""}${KAYNAK_SORGU[kaynak]}`,
    jsonFetcher,
    // ACIK ALARM CANLI OLMALI: bu ekran acikken biri "gidiyorum"
    // derse, yenilemeden gorunmeli.
    { refreshInterval: 15_000 },
  );
  // (P249 §2) Tatbikat planlama yalniz yonetimde (sunucu da zorlar).
  const rol = useRol(null);
  const [kapatilan, setKapatilan] = useState<Alarm | null>(null);
  // (P249 §1b) Daire bazinda durumu acilan toplu uyari.
  const [durumAlarm, setDurumAlarm] = useState<Alarm | null>(null);
  const [not, setNot] = useState("");
  const [bekliyor, setBekliyor] = useState(false);

  async function kapat() {
    if (!kapatilan) return;
    setBekliyor(true);
    try {
      await apiSend(`/api/panik/${kapatilan.id}/kapat`, "POST", {
        kapanis_notu: not || null,
      });
      setKapatilan(null);
      setNot("");
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  const satirlar = data?.items ?? [];

  const ozet = data?.ozet;
  const acikCagri = ozet?.acik ?? 0;
  const kapananCagri = ozet?.kapanan ?? 0;
  const bugunCagri = ozet?.bugun ?? 0;
  const durumlar = data?.durumlar?.length ? data.durumlar : PANIK_DURUMLARI_YEDEK;

  return (
    <div>
      <SayfaBasligi baslik={t("panikTakipBaslik")} aciklama={t("panikTakipAlt")} />

      {/* (P245) OZET SERIDI — referansta (ui3) "Acil Durum Cagrilari"
          ekraninin ustunde dort kart var: aktif cagri, bugun toplam,
          ortalama mudahale, zamaninda oran.
          -----------------------------------------------------------------
          ORTALAMA MUDAHALE ve ZAMANINDA ORANI UYDURULMADI: ikisi de
          cagri basina "mudahale baslangici" damgasi ister; kayitta
          `created_at` ve `kapandi_at` var, ARADAKI adim YOK. Sunucu
          onu vermeden hesaplanan bir "4 dk", olculmemis bir sayidir.
          Yerine bu listenin GERCEKTEN yanitladigi uc soru kondu. */}
      <OzetSeridi>
        <OzetKarti
          etiket={t("panikOzetAcik")}
          deger={String(acikCagri)}
          durum={acikCagri > 0 ? "kritik" : "olumlu"}
          ikon={<PanikIkonu yol={IKON_ALARM} />}
          altBilgi={acikCagri > 0 ? t("panikOzetAcikAlt") : undefined}
        />
        <OzetKarti
          etiket={t("panikOzetBugun")}
          deger={String(bugunCagri)}
          durum="bilgi"
          ikon={<PanikIkonu yol={IKON_TAKVIM} />}
        />
        <OzetKarti
          etiket={t("panikOzetKapanan")}
          deger={String(kapananCagri)}
          durum="olumlu"
          ikon={<PanikIkonu yol={IKON_ONAY} />}
          altBilgi={
            ozet && ozet.yanlis_alarm + ozet.iptal > 0
              ? t("panikOzetKapananAlt", { yanlis: ozet.yanlis_alarm, iptal: ozet.iptal })
              : undefined
          }
        />
      </OzetSeridi>

      <FiltreCubugu
        aktifSayi={(durumSuzgec ? 1 : 0) + (kaynak !== KAYNAK_GERCEK ? 1 : 0)}
        onTemizle={() => {
          setDurumSuzgec(SUZGEC_HEPSI);
          setKaynak(KAYNAK_GERCEK);
        }}
      >
        <Secim
          aria-label={t("panikKaynakSuzgec")}
          data-test="panik-kaynak"
          value={kaynak}
          onChange={(e) => setKaynak(e.target.value as Kaynak)}
          className="w-auto"
        >
          <option value={KAYNAK_GERCEK}>{t("panikKaynakGercek")}</option>
          <option value={KAYNAK_TATBIKAT}>{t("panikKaynakTatbikat")}</option>
          <option value={KAYNAK_HEPSI}>{t("panikKaynakHepsi")}</option>
        </Secim>
        <Secim
          aria-label={t("panikDurumSuzgec")}
          data-test="panik-durum-suzgec"
          value={durumSuzgec}
          onChange={(e) => setDurumSuzgec(e.target.value)}
          className="w-auto"
        >
          <option value={SUZGEC_HEPSI}>{t("panikDurumHepsi")}</option>
          {durumlar.map((d) => (
            <option key={d} value={d}>
              {t(DURUM_ETIKET[d] ?? DURUM_YEDEK)}
            </option>
          ))}
        </Secim>
      </FiltreCubugu>

      <HataDurumu mesaj={error ? t("ortakHataOlustu") : null} />

      <Kart>
        {/* BOS DURUM SARTI HATAYI DA ELER: `isLoading` bitmis ama istek
            DUSMUSSE liste bos gelir ve "kayit yok" yazmak, hatayi
            "veri yok" gibi gosterirdi (depo kilidi `hata-mesaji`). */}
        {/* (P245) YUKLENIRKEN ISKELET — eskiden BOS TABLO ciziliyordu.
            Kosul yalniz "bos durum"u ayiriyordu; `isLoading` dogruyken
            else dalina duserek BASLIKSIZ, SATIRSIZ bir tablo ciziyordu.
            Gercek tarayicida olculdu: sayfa bir an "kayit yok" bile
            demeden bos bir izgara gosteriyor. */}
        {isLoading && !error ? (
          <IskeletMetin satir={4} />
        ) : !error && satirlar.length === 0 ? (
          /* (P245) `ikon="alert"` DIZGESI EKRANA "alert" DIYE YAZILIYORDU.
             `BosDurum.ikon` bir `ReactNode` bekler; dize verilince
             aynen cizilir. Gercek tarayicida goruldu — jsdom'da da
             "alert" metni vardi ama hicbir iddia onu sorgulamiyordu.
             Varsayilan ikon zaten notr bir kutu; burada ALARM ikonu
             anlamli, bu yuzden sayfanin kendi ikonu verildi. */
          <BosDurum
            ikon={<PanikIkonu yol={IKON_ALARM} />}
            baslik={t("panikAlarmYok")}
            aciklama={t("panikAlarmYokAlt")}
          />
        ) : (
          <Tablo>
            <TabloBasligi>
              <Th>{t("ortakTarih")}</Th>
              <Th>{t("panikTipBasligi")}</Th>
              <Th>{t("ortakDurum")}</Th>
              <Th>{t("panikKimBasligi")}</Th>
              {/* (P251 §1) "/ gordu" BASLIGI: satir metni yer tutuculari
                  BOS verilerek baslik yapilmisti. Baslik kendi anahtarini
                  tasir. Eylem sutunu da gorunur baslik alir (eskiden
                  `aria-label` `Th`de yutuluyordu — bos baslik). */}
              <Th>{t("panikGorenBasligi")}</Th>
              <Th>{t("panikMudahaleSuresi")}</Th>
              <Th>{t("ortakIslemSutunu")}</Th>
            </TabloBasligi>
            <tbody>
              {satirlar.map((a) => {
                const goren = a.alicilar.filter((x) => x.goruldu_at).length;
                const yer =
                  a.daire_no
                    ? `${a.blok ?? ""} ${a.daire_no}`.trim()
                    : (a.checkpoint_ad ?? "");
                return (
                  <Tr key={a.id} data-test={`panik-satir-${a.id}`}>
                    <Td>{formatDateTime(a.created_at)}</Td>
                    <Td data-test={`panik-kategori-${a.id}`}>
                      {/* (P249 §1b) KATEGORI ONCE: "DEPREM ALARMI" tipten
                          ("Tum siteye anons") daha cok sey soyler. */}
                      {a.baslik || t(TIP_ETIKET[a.tip] ?? TIP_YEDEK)}
                      {a.baslik && (
                        <span className="block" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
                          {t(TIP_ETIKET[a.tip] ?? TIP_YEDEK)}
                        </span>
                      )}
                      {a.tatbikat && (
                        <span className="mt-1 inline-block" data-test={`panik-tatbikat-${a.id}`}>
                          <Rozet durum="bilgi">{t("panikRozetTatbikat")}</Rozet>
                        </span>
                      )}
                    </Td>
                    <Td>
                      <Rozet
                        durum={
                          a.durum === "kapandi"
                            ? "olumlu"
                            : a.durum === "iptal" || a.durum === "yanlis_alarm"
                              ? "notr"
                              : "kritik"
                        }
                      >
                        {t(DURUM_ETIKET[a.durum] ?? DURUM_YEDEK)}
                      </Rozet>
                    </Td>
                    <Td>
                      {a.olusturan_ad ?? ""}
                      {yer ? ` · ${yer}` : ""}
                    </Td>
                    <Td data-test={`panik-goren-${a.id}`}>
                      {t("panikGorenSayisi", {
                        goren,
                        toplam: a.alicilar.length,
                      })}
                    </Td>
                    <Td data-test={`panik-sure-${a.id}`}>
                      {/* SURE YOKSA CIZGI: "0 sn" yazmak, mudahale
                          edilmemis bir alarmi ANINDA mudahale edilmis
                          gibi gosterirdi. */}
                      {a.mudahale_suresi_sn === null
                        ? "—"
                        : t("panikSaniye", { n: a.mudahale_suresi_sn })}
                    </Td>
                    <Td>
                      {a.toplu && (
                        <Dugme
                          type="button"
                          boy="kucuk"
                          tur={IKINCIL}
                          data-test={`panik-durum-ac-${a.id}`}
                          onClick={() => setDurumAlarm(a)}
                        >
                          {t("panikYanitGoster")}
                        </Dugme>
                      )}{" "}
                      {a.durum !== "kapandi" &&
                        a.durum !== "iptal" &&
                        a.durum !== "yanlis_alarm" && (
                          <Dugme
                            type="button"
                            boy="kucuk"
                            tur={IKINCIL}
                            data-test={`panik-kapat-${a.id}`}
                            onClick={() => setKapatilan(a)}
                          >
                            {t("panikKapat")}
                          </Dugme>
                        )}
                    </Td>
                  </Tr>
                );
              })}
            </tbody>
          </Tablo>
        )}
      </Kart>

      <TatbikatBolumu yonetim={rol === "admin" || rol === "yonetici"} />

      <Modal
        acik={durumAlarm !== null}
        onKapat={() => setDurumAlarm(null)}
        baslik={durumAlarm ? `${durumAlarm.baslik} — ${t("panikYanitBaslik")}` : t("panikYanitBaslik")}
      >
        {durumAlarm && <PanikDurumPaneli alarmId={durumAlarm.id} />}
      </Modal>

      <Modal
        acik={kapatilan !== null}
        onKapat={() => setKapatilan(null)}
        baslik={t("panikKapat")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setKapatilan(null)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
              tur={BIRINCIL}
              data-test="panik-kapat-onayla"
              yukleniyor={bekliyor}
              onClick={() => void kapat()}
            >
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <Alan maxLength={SINIR.NOT}
          data-test="panik-kapanis-notu"
          aria-label={t("panikKapanisNotu")}
          placeholder={t("panikKapanisNotu")}
          value={not}
          onChange={(e) => setNot(e.target.value)}
        />
      </Modal>
    </div>
  );
}
