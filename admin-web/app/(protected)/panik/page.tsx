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
const PANIK_DURUMLARI = ["beklemede", "acik", "mudahale", "kapandi", "iptal"] as const;

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
};

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
  // SERIT SAYILARI SUZGECTEN BAGIMSIZ (P244 §8c dersi): suzgec acikken
  // ayni kumeden saymak, "Kapanan" secildiginde "Acik cagri: 0" yazmak
  // olurdu — yani ekran acik cagri OLMADIGINI soylerdi.
  const { data: tumAlarmlar } = useSWR<{ items: Alarm[] }>(
    "/api/panik?limit=200",
    jsonFetcher,
  );
  const { data, error, isLoading, mutate } = useSWR<{ items: Alarm[] }>(
    `/api/panik?limit=50${durumSuzgec ? `&durum=${durumSuzgec}` : ""}`,
    jsonFetcher,
    // ACIK ALARM CANLI OLMALI: bu ekran acikken biri "gidiyorum"
    // derse, yenilemeden gorunmeli.
    { refreshInterval: 15_000 },
  );
  const [kapatilan, setKapatilan] = useState<Alarm | null>(null);
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

  // SAYILAR GORUNEN LISTEDEN ve bu BILINCLI: uc durum suzgeci
  // sunmuyor ve panik cagrisi tesis basina gunde birkac kayittir —
  // sayfalama sinirina carpmaz.
  const tumSatirlar = tumAlarmlar?.items ?? [];
  const acikCagri = tumSatirlar.filter((a) => a.kapandi_at == null).length;
  const kapananCagri = tumSatirlar.length - acikCagri;
  const bugunBasi = new Date();
  bugunBasi.setHours(0, 0, 0, 0);
  const bugunCagri = tumSatirlar.filter(
    (a) => new Date(a.created_at).getTime() >= bugunBasi.getTime(),
  ).length;

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
        />
      </OzetSeridi>

      <FiltreCubugu
        aktifSayi={durumSuzgec ? 1 : 0}
        onTemizle={() => setDurumSuzgec(SUZGEC_HEPSI)}
      >
        <Secim
          aria-label={t("panikDurumSuzgec")}
          value={durumSuzgec}
          onChange={(e) => setDurumSuzgec(e.target.value)}
          className="w-auto"
        >
          <option value={SUZGEC_HEPSI}>{t("panikDurumHepsi")}</option>
          {PANIK_DURUMLARI.map((d) => (
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
              <Th>{t("panikGorenSayisi", { goren: "", toplam: "" })}</Th>
              <Th>{t("panikMudahaleSuresi")}</Th>
              <Th aria-label={t("panikKapat")} />
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
                    <Td>{t(TIP_ETIKET[a.tip] ?? TIP_YEDEK)}</Td>
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
