"use client";

/**
 * (P241 §1) PERIYODIK BAKIM TAKIBI.
 *
 * =========================================================================
 * RENK TEK BASINA ANLAM TASIMAZ
 * =========================================================================
 * Istegin acik maddesi. Her satirda durum rozetinin YANINDA GUN SAYISI
 * yazili ("12 gun kaldi" / "4 gun gecikti"). Renk korlugu bir yana,
 * yazdirilan bir listede de renk kaybolur ve denetime verilen kagitta
 * "hangisi gecikmisti" sorusu yanitsiz kalirdi.
 *
 * =========================================================================
 * SIRALAMA SUNUCUDA
 * =========================================================================
 * En yakin tarih ustte; gecikmisler tarihleri gecmiste oldugu icin dogal
 * olarak en basta. Istemcide yeniden siralamak, sayfalanmis bir listede
 * YALNIZ ACIK SAYFAYI sirasaydi ve kullanici bunu goremezdi.
 */
import { useState } from "react";
import useSWR from "swr";

import { Tablo, TabloBasligi, Td, Th, Tr } from "@/components/tablo";
import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  Kart,
  Modal,
  Rozet,
  Secim,
  Sekmeler,
  useOnay,
} from "@/components/ui";
import { TelefonAlani } from "@/components/TelefonAlani";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type Ekipman = {
  id: string;
  ad: string;
  tur: string;
  blok_ad: string | null;
  alan: string | null;
  periyot: string;
  periyot_gun: number | null;
  son_bakim: string | null;
  sonraki_bakim: string;
  firma_ad: string | null;
  sorumlu_ad: string | null;
  sorumlu_telefon: string | null;
  yasal: boolean;
  uyari_gun: number | null;
  etkin_uyari_gun: number;
  notlar: string | null;
  aktif: boolean;
  durum: string;
  kalan_gun: number;
};
type Kayit = {
  id: string;
  ekipman_id: string;
  ekipman_ad: string | null;
  tarih: string;
  firma_ad: string | null;
  yapan_ad: string | null;
  islem: string | null;
  tutar_kurus: number | null;
  hareket_id: string | null;
};
type OzetSatiri = {
  ekipman_id: string;
  ad: string;
  tur: string;
  yasal: boolean;
  bakim_sayisi: number;
  toplam_kurus: number;
  son_bakim: string | null;
  sonraki_bakim: string;
};
type Ozet = {
  yil: number;
  satirlar: OzetSatiri[];
  toplam_kurus: number;
  yasal_eksik: string[];
};

const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;
const KUCUK = "kucuk" as const;
const CIZGI = "—";
const AYRAC = " · ";

const PERIYOTLAR: Record<string, SozlukAnahtari> = {
  aylik: "bakimPeriyotAylik",
  uc_aylik: "bakimPeriyotUcAylik",
  alti_aylik: "bakimPeriyotAltiAylik",
  yillik: "bakimPeriyotYillik",
  gun: "bakimPeriyotGun",
};
const DURUMLAR: Record<string, SozlukAnahtari> = {
  gecikti: "bakimDurumGecikti",
  bugun: "bakimDurumBugun",
  yaklasti: "bakimDurumYaklasti",
  planli: "bakimDurumPlanli",
};
const YEDEK_PERIYOT: SozlukAnahtari = "bakimPeriyotAylik";
const YEDEK_DURUM: SozlukAnahtari = "bakimDurumPlanli";
const PERIYOT_ANAHTARLARI = Object.keys(PERIYOTLAR);
const DURUM_ANAHTARLARI = Object.keys(DURUMLAR);

function kurusMetin(kurus: number | null): string {
  if (kurus === null) return CIZGI;
  return (kurus / 100).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

export default function BakimPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();

  const [durumSuzgeci, setDurumSuzgeci] = useState("");
  const [yil, setYil] = useState(String(new Date().getFullYear()));

  const ekipmanlar = useSWR<{ items: Ekipman[] }>(
    `/api/bakim/ekipmanlar?limit=200${durumSuzgeci ? `&durum=${durumSuzgeci}` : ""}`,
    jsonFetcher,
  );
  const kayitlar = useSWR<{ items: Kayit[] }>(
    "/api/bakim/kayitlar?limit=100",
    jsonFetcher,
  );
  const ozet = useSWR<Ozet>(`/api/bakim/ozet?yil=${yil}`, jsonFetcher);

  const [form, setForm] = useState(false);
  const [ad, setAd] = useState("");
  const [tur, setTur] = useState("");
  const [periyot, setPeriyot] = useState(PERIYOT_ANAHTARLARI[0]);
  const [periyotGun, setPeriyotGun] = useState("");
  const [sonBakim, setSonBakim] = useState("");
  const [alan, setAlan] = useState("");
  const [sorumlu, setSorumlu] = useState("");
  const [telefon, setTelefon] = useState("");
  const [yasal, setYasal] = useState(false);
  const [uyariGun, setUyariGun] = useState("");

  const [kayitFormu, setKayitFormu] = useState<Ekipman | null>(null);
  const [kTarih, setKTarih] = useState("");
  const [kYapan, setKYapan] = useState("");
  const [kIslem, setKIslem] = useState("");
  const [kTutar, setKTutar] = useState("");
  const [kGidere, setKGidere] = useState(true);

  function hata(e: unknown) {
    toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
  }

  async function ekipmanKaydet() {
    try {
      await apiSend("/api/bakim/ekipmanlar", "POST", {
        ad,
        tur,
        periyot,
        periyot_gun: periyot === "gun" ? Number(periyotGun) : null,
        son_bakim: sonBakim || null,
        alan: alan || null,
        sorumlu_ad: sorumlu || null,
        sorumlu_telefon: telefon || null,
        yasal,
        uyari_gun: uyariGun ? Number(uyariGun) : null,
      });
      setForm(false);
      setAd("");
      setTur("");
      setPeriyotGun("");
      setSonBakim("");
      setAlan("");
      setSorumlu("");
      setTelefon("");
      setYasal(false);
      setUyariGun("");
      await ekipmanlar.mutate();
    } catch (e) {
      hata(e);
    }
  }

  async function kayitKaydet() {
    if (!kayitFormu) return;
    try {
      await apiSend(
        `/api/bakim/ekipmanlar/${kayitFormu.id}/kayitlar`,
        "POST",
        {
          tarih: kTarih,
          yapan_ad: kYapan || null,
          islem: kIslem || null,
          tutar_kurus: kTutar ? Math.round(Number(kTutar) * 100) : null,
          gidere_yaz: kGidere,
        },
      );
      setKayitFormu(null);
      setKYapan("");
      setKIslem("");
      setKTutar("");
      await Promise.all([ekipmanlar.mutate(), kayitlar.mutate(), ozet.mutate()]);
    } catch (e) {
      hata(e);
    }
  }

  async function ekipmanSil(e: Ekipman) {
    if (
      !(await onayla({
        baslik: t("ortakSil"),
        mesaj: e.ad,
        onayMetni: t("ortakSil"),
        tehlikeli: true,
      }))
    )
      return;
    try {
      await apiSend(`/api/bakim/ekipmanlar/${e.id}`, "DELETE");
      await ekipmanlar.mutate();
    } catch (err) {
      hata(err);
    }
  }

  const liste = ekipmanlar.data?.items ?? [];

  const listeIcerik = (
    <Kart>
      <div className="mb-3 flex items-center justify-between gap-2">
        <div style={{ maxWidth: "16rem" }}>
          <AlanSarmal etiket={t("bakimFiltreDurum")}>
            {(p) => (
              <Secim
                {...p}
                data-test="bakim-durum-suzgeci"
                value={durumSuzgeci}
                onChange={(e) => setDurumSuzgeci(e.target.value)}
              >
                <option value="">{t("bakimFiltreTumu")}</option>
                {DURUM_ANAHTARLARI.map((d) => (
                  <option key={d} value={d}>
                    {t(DURUMLAR[d])}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        </div>
        <Dugme
          type="button"
          boy={KUCUK}
          tur={BIRINCIL}
          data-test="bakim-ekipman-ekle"
          onClick={() => setForm(true)}
        >
          {t("bakimEkipmanEkle")}
        </Dugme>
      </div>

      {liste.length === 0 ? (
        <BosDurum baslik={t("bakimEkipmanYok")} aciklama={t("bakimEkipmanYokAlt")} />
      ) : (
        <Tablo>
          <TabloBasligi>
            <Tr>
              <Th>{t("ortakAd")}</Th>
              <Th>{t("bakimPeriyot")}</Th>
              <Th>{t("bakimSonrakiBakim")}</Th>
              <Th>{t("ortakDurum")}</Th>
              <Th>{t("bakimSorumlu")}</Th>
              <Th aria-label={t("ortakSil")} />
            </Tr>
          </TabloBasligi>
          <tbody>
            {liste.map((e) => (
              <Tr key={e.id} data-test={`bakim-satir-${e.id}`}>
                <Td>
                  <span>
                    {e.ad}
                    {e.yasal ? `${AYRAC}${t("bakimYasal")}` : ""}
                    {e.blok_ad || e.alan
                      ? `${AYRAC}${e.blok_ad ?? e.alan}`
                      : ""}
                  </span>
                </Td>
                <Td>
                  <span>
                    {t(PERIYOTLAR[e.periyot] ?? YEDEK_PERIYOT)}
                    {e.periyot_gun ? ` (${e.periyot_gun})` : ""}
                  </span>
                </Td>
                <Td>{e.sonraki_bakim}</Td>
                <Td data-test={`bakim-durum-${e.id}`}>
                  {/* RENGIN YANINDA SAYI: renk tek basina anlam
                      tasimamali (yazdirilan listede de kaybolur). */}
                  <span className="flex items-center gap-2">
                    <Rozet
                      durum={
                        e.durum === "gecikti"
                          ? "kritik"
                          : e.durum === "bugun"
                            ? "uyari"
                            : e.durum === "yaklasti"
                              ? "uyari"
                              : "olumlu"
                      }
                    >
                      {t(DURUMLAR[e.durum] ?? YEDEK_DURUM)}
                    </Rozet>
                    <span style={{ fontSize: "var(--yz-fs-sm)" }}>
                      {e.kalan_gun < 0
                        ? t("bakimGecikmeGun", { n: -e.kalan_gun })
                        : t("bakimKalanGun", { n: e.kalan_gun })}
                    </span>
                  </span>
                </Td>
                <Td>
                  <span>{e.firma_ad ?? e.sorumlu_ad ?? CIZGI}</span>
                </Td>
                <Td>
                  <div className="flex gap-2">
                    <Dugme
                      type="button"
                      boy={KUCUK}
                      tur={BIRINCIL}
                      data-test={`bakim-kayit-ekle-${e.id}`}
                      onClick={() => {
                        setKayitFormu(e);
                        setKTarih(new Date().toISOString().slice(0, 10));
                      }}
                    >
                      {t("bakimKayitEkle")}
                    </Dugme>
                    <Dugme
                      type="button"
                      boy={KUCUK}
                      tur={IKINCIL}
                      data-test={`bakim-sil-${e.id}`}
                      onClick={() => ekipmanSil(e)}
                    >
                      {t("ortakSil")}
                    </Dugme>
                  </div>
                </Td>
              </Tr>
            ))}
          </tbody>
        </Tablo>
      )}
    </Kart>
  );

  const gecmisIcerik = (
    <Kart>
      {(kayitlar.data?.items ?? []).length === 0 ? (
        <BosDurum baslik={t("bakimGecmisYok")} aciklama={t("bakimGecmisYokAlt")} />
      ) : (
        <Tablo>
          <TabloBasligi>
            <Tr>
              <Th>{t("bakimKayitTarihi")}</Th>
              <Th>{t("ortakAd")}</Th>
              <Th>{t("bakimYapan")}</Th>
              <Th>{t("bakimIslem")}</Th>
              <Th>{t("bakimTutar")}</Th>
            </Tr>
          </TabloBasligi>
          <tbody>
            {(kayitlar.data?.items ?? []).map((k) => (
              <Tr key={k.id} data-test={`bakim-kayit-${k.id}`}>
                <Td>{k.tarih}</Td>
                <Td>
                  <span>{k.ekipman_ad ?? CIZGI}</span>
                </Td>
                <Td>
                  <span>{k.firma_ad ?? k.yapan_ad ?? CIZGI}</span>
                </Td>
                <Td>
                  <span>{k.islem ?? CIZGI}</span>
                </Td>
                <Td>
                  <span>{kurusMetin(k.tutar_kurus)}</span>
                </Td>
              </Tr>
            ))}
          </tbody>
        </Tablo>
      )}
    </Kart>
  );

  const ozetIcerik = (
    <Kart>
      <div className="mb-3" style={{ maxWidth: "10rem" }}>
        <AlanSarmal etiket={t("bakimOzetBaslik")}>
          {(p) => (
            <Alan
              {...p}
              inputMode="numeric"
              data-test="bakim-ozet-yil"
              value={yil}
              onChange={(e) => setYil(e.target.value)}
            />
          )}
        </AlanSarmal>
      </div>
      {/* YASAL EKSIKLER EN USTTE ve AYRI: denetimin ilk sorusu budur ve
          toplamlarin arasinda kaybolmamali. */}
      <div className="mb-3" data-test="bakim-yasal-eksik">
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {(ozet.data?.yasal_eksik ?? []).length === 0
            ? t("bakimYasalEksikYok")
            : `${t("bakimYasalEksik")}: ${(ozet.data?.yasal_eksik ?? []).join(", ")}`}
        </p>
      </div>
      <Tablo>
        <TabloBasligi>
          <Tr>
            <Th>{t("ortakAd")}</Th>
            <Th>{t("bakimOzetSayi")}</Th>
            <Th>{t("bakimOzetToplam")}</Th>
            <Th>{t("bakimSonBakim")}</Th>
            <Th>{t("bakimSonrakiBakim")}</Th>
          </Tr>
        </TabloBasligi>
        <tbody>
          {(ozet.data?.satirlar ?? []).map((s) => (
            <Tr key={s.ekipman_id} data-test={`bakim-ozet-${s.ekipman_id}`}>
              <Td>
                <span>
                  {s.ad}
                  {s.yasal ? `${AYRAC}${t("bakimYasal")}` : ""}
                </span>
              </Td>
              <Td>{s.bakim_sayisi}</Td>
              <Td>
                <span>{kurusMetin(s.toplam_kurus)}</span>
              </Td>
              <Td>
                <span>{s.son_bakim ?? CIZGI}</span>
              </Td>
              <Td>{s.sonraki_bakim}</Td>
            </Tr>
          ))}
        </tbody>
      </Tablo>
    </Kart>
  );

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("bakimBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("bakimAciklama")}
        </p>
      </div>

      <HataDurumu
        mesaj={ekipmanlar.error || ozet.error ? t("ortakHataOlustu") : null}
      />

      <Sekmeler
        sekmeler={[
          { id: "liste", baslik: t("bakimBaslik"), icerik: listeIcerik },
          { id: "gecmis", baslik: t("bakimGecmis"), icerik: gecmisIcerik },
          { id: "ozet", baslik: t("bakimOzetBaslik"), icerik: ozetIcerik },
        ]}
      />

      <Modal
        acik={form}
        baslik={t("bakimEkipmanEkle")}
        onKapat={() => setForm(false)}
      >
        <div className="space-y-3">
          <AlanSarmal etiket={t("ortakAd")}>
            {(p) => (
              <Alan
                {...p}
                data-test="bakim-ad"
                value={ad}
                onChange={(e) => setAd(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("bakimTur")}>
            {(p) => (
              <Alan
                {...p}
                data-test="bakim-tur"
                value={tur}
                onChange={(e) => setTur(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("bakimPeriyot")}>
            {(p) => (
              <Secim
                {...p}
                data-test="bakim-periyot"
                value={periyot}
                onChange={(e) => setPeriyot(e.target.value)}
              >
                {PERIYOT_ANAHTARLARI.map((k) => (
                  <option key={k} value={k}>
                    {t(PERIYOTLAR[k])}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          {periyot === "gun" && (
            <AlanSarmal etiket={t("bakimPeriyotGunSayisi")}>
              {(p) => (
                <Alan
                  {...p}
                  inputMode="numeric"
                  data-test="bakim-periyot-gun"
                  value={periyotGun}
                  onChange={(e) => setPeriyotGun(e.target.value)}
                />
              )}
            </AlanSarmal>
          )}
          <AlanSarmal etiket={t("bakimSonBakim")}>
            {(p) => (
              <Alan
                {...p}
                type="date"
                data-test="bakim-son-bakim"
                value={sonBakim}
                onChange={(e) => setSonBakim(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("bakimSorumlu")}>
            {(p) => (
              <Alan
                {...p}
                data-test="bakim-sorumlu"
                value={sorumlu}
                onChange={(e) => setSorumlu(e.target.value)}
              />
            )}
          </AlanSarmal>
          {/* PAYLASILAN BILESEN: bicim, ulke kodu ve hata metni birlikte
              gelir. Duz bir `<input>` birakmak `telefon-kapsam` kilidini
              (hakli olarak) kirdi — sorumlu firmanin numarasi da her
              yerdeki gibi bicimlenmeli. */}
          <TelefonAlani
            etiket={t("tanimAlanTelefon")}
            deger={telefon}
            onDegisti={setTelefon}
          />
          <AlanSarmal etiket={t("bakimUyariGun")} ipucu={t("bakimUyariGunIpucu")}>
            {(p) => (
              <Alan
                {...p}
                inputMode="numeric"
                data-test="bakim-uyari-gun"
                value={uyariGun}
                onChange={(e) => setUyariGun(e.target.value)}
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
              data-test="bakim-yasal"
              checked={yasal}
              onChange={(e) => setYasal(e.target.checked)}
            />
            {t("bakimYasal")}
          </label>
          <Dugme
            type="button"
            tur={BIRINCIL}
            data-test="bakim-kaydet"
            onClick={ekipmanKaydet}
          >
            {t("ortakKaydet")}
          </Dugme>
        </div>
      </Modal>

      <Modal
        acik={kayitFormu !== null}
        baslik={t("bakimKayitEkle")}
        onKapat={() => setKayitFormu(null)}
      >
        <div className="space-y-3">
          <AlanSarmal etiket={t("bakimKayitTarihi")}>
            {(p) => (
              <Alan
                {...p}
                type="date"
                data-test="bakim-kayit-tarih"
                value={kTarih}
                onChange={(e) => setKTarih(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("bakimYapan")}>
            {(p) => (
              <Alan
                {...p}
                data-test="bakim-kayit-yapan"
                value={kYapan}
                onChange={(e) => setKYapan(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("bakimIslem")}>
            {(p) => (
              <Alan
                {...p}
                data-test="bakim-kayit-islem"
                value={kIslem}
                onChange={(e) => setKIslem(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("bakimTutar")}>
            {(p) => (
              <Alan
                {...p}
                inputMode="decimal"
                data-test="bakim-kayit-tutar"
                value={kTutar}
                onChange={(e) => setKTutar(e.target.value)}
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
              data-test="bakim-kayit-gidere"
              checked={kGidere}
              onChange={(e) => setKGidere(e.target.checked)}
            />
            {t("bakimGidereYaz")}
          </label>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("bakimGidereYazIpucu")}
          </p>
          <Dugme
            type="button"
            tur={BIRINCIL}
            data-test="bakim-kayit-kaydet"
            onClick={kayitKaydet}
          >
            {t("ortakKaydet")}
          </Dugme>
        </div>
      </Modal>

      {diyalog}
    </div>
  );
}
