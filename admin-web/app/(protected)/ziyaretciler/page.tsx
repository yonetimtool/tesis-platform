"use client";

// (P126.4) ZİYARETÇİLER — güvenliğin kapı ekranı.
//
// KAYIT YALNIZ GÜVENLİK: sunucu `_REGISTRAR = require_role("security")` ile
// zorlar; yönetici/admin geçmişi okur ama kayıt açmaz (kapı operasyonu).
// Bu sayfa `app.*` tesis yüzeyindedir ve rol kapısı girişte uygulanır.
//
// (E2E 2026-09 / GUVENLIK-14) KARAR: FORM KALDIRILMADI, MOBİLDEKİ SEÇİCİ
// TAŞINDI. Sayfa P129 ile PARK (`lib/yuzey.ts` `"/ziyaretciler": []`) ve
// P129'un kendi kuralı "geri açmak = rol adını satıra yazmak". Ölçülen:
// park edilmiş form geri açılsa ÇALIŞMAZDI — gövde `{unit_no, ziyaretci_ad}`
// idi, `target_resident_user_id` sunucuda ZORUNLU (her kayıt 422) ve
// daire serbest metindi. Formu silmek sayfayı geri açılamaz bırakırdı ve
// P162'nin (düzenleme paritesi) kararını geri alırdı; bu yüzden mobilin
// `units/ara` (numara VEYA sakin adıyla) + hedef sakin seçicisi buraya
// taşındı. Park kararı DEĞİŞMEDİ — bu tur hiçbir role sayfa açmıyor.
import { useEffect, useState } from "react";
import useSWR from "swr";

// (P245) UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SUZGEC_HEPSI = "" as const;
const SUZGEC_ICERDE = "true" as const;
const SUZGEC_CIKMIS = "false" as const;

import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Modal,
  OzetKarti,
  OzetSeridi,
  Rozet,
  SayfaBasligi,
  VeriTablosu,
  FiltreCubugu,
  Secim,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Ziyaretci = {
  id: string;
  unit_no: string | null;
  ziyaretci_ad: string;
  notlar: string | null;
  giris_zamani: string;
  cikis_zamani: string | null;
  target_resident_user_id?: string | null;
  target_resident_ad?: string | null;
};

/** `GET /units/ara` satiri — daire + AKTIF sakinleri (tek yanitta). */
type SakinOzet = { user_id: string; ad: string };
type DaireSonuc = { id: string; no: string; blok: string | null; sakinler: SakinOzet[] };

/** Arama en az IKI karakterle baslar (sunucu da tek harfe bos doner). */
const ARAMA_ALT_SINIR = 2;
/** Her tusta istek atilmasin. */
const ARAMA_GECIKME_MS = 250;

export default function ZiyaretcilerPage() {
  const t = useT();
  const toast = useToast();
  // (P245) ICERDE SUZGECI — SUNUCUDA (`?icerde=`). Istemcide suzmek
  // yalniz GORUNEN 50 kaydi arardi.
  const [icerdeSuzgec, setIcerdeSuzgec] = useState<string>(SUZGEC_HEPSI);
  const { data, error, isLoading, mutate } = useSWR<{ items: Ziyaretci[] }>(
    `/api/visitors?limit=50&offset=0${icerdeSuzgec ? `&icerde=${icerdeSuzgec}` : ""}`,
    jsonFetcher,
  );
  // SERIT SAYILARI SUZGECTEN BAGIMSIZ — AYRI ISTEK.
  //
  // Suzgec eklenince `kayitlar` SUZULMUS kume oldu; seridi ondan
  // beslemek "Cikmis" secildiginde "Icerideki: 0" yazmak olurdu — yani
  // ekran, iceride kimse OLMADIGINI soylerdi. (P244 §8c dersi.)
  const { data: tumu } = useSWR<{ items: Ziyaretci[] }>(
    "/api/visitors?limit=200&offset=0",
    jsonFetcher,
  );
  const tumKayitlar = tumu?.items ?? [];

  const [ad, setAd] = useState("");
  // (E2E 2026-09 / GUVENLIK-14) DAIRE SERBEST METIN DEGIL: aranir, secilir.
  const [arama, setArama] = useState("");
  const [gecikmeliArama, setGecikmeliArama] = useState("");
  const [daire, setDaire] = useState<DaireSonuc | null>(null);
  const [hedef, setHedef] = useState("");
  const [notlar, setNotlar] = useState("");
  useEffect(() => {
    const z = setTimeout(() => setGecikmeliArama(arama.trim()), ARAMA_GECIKME_MS);
    return () => clearTimeout(z);
  }, [arama]);
  const { data: aramaSonucu } = useSWR<DaireSonuc[]>(
    !daire && gecikmeliArama.length >= ARAMA_ALT_SINIR
      ? `/api/units/ara?q=${encodeURIComponent(gecikmeliArama)}&limit=10`
      : null,
    jsonFetcher,
  );

  function daireSec(d: DaireSonuc | null) {
    setDaire(d);
    // TEK SAKIN VARSA OTOMATIK SECILIR — kapida en sik durum; birden
    // cok sakinde secim zorunlu (bildirim YALNIZ ona gider).
    setHedef(d && d.sakinler.length === 1 ? d.sakinler[0].user_id : "");
    if (!d) setArama("");
  }

  function formuSifirla() {
    setAd("");
    setArama("");
    setGecikmeliArama("");
    setDaire(null);
    setHedef("");
    setNotlar("");
  }
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  // (P162 §5) ZIYARETCI KAYDINI DUZENLEME — webde YOKTU.
  //
  // Uc (`PATCH /visitors/{id}`) ve rol kapisi (`_REGISTRAR` = guvenlik)
  // zaten vardi; mobilde kullaniliyordu, webde vekil ve dugme eksikti.
  // Kapida yanlis yazilan bir ad ya da daire, vardiya devrinde
  // duzeltilebilmeli — aksi halde kayit kalici olarak yanlis kalir.
  //
  // AYNI MODAL: yeni kayit ile duzenleme tek formu paylasir. Iki ayri
  // form, iki ayri dogrulama demekti ve biri gerilerdi.
  const [duzenlenen, setDuzenlenen] = useState<{ id: string } | null>(null);

  const kayitlar = data?.items ?? [];

  async function kaydet() {
    if (!ad.trim() || !daire) {
      setHata(t("ziyaretciAlanZorunlu"));
      return;
    }
    // (E2E 2026-09 / GUVENLIK-14) HEDEF SAKIN ZORUNLU — sunucu da ister
    // (422); bildirim ve gorunurluk YALNIZ ona baglidir.
    if (!hedef) {
      setHata(t("ziyaretciHedefZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      // DAIRE NO ile gonderilir: kapida görevli daire NUMARASINI bilir,
      // kaydın kimliğini değil. Sunucu numarayı çözer.
      const govde = {
        unit_no: daire.no,
        target_resident_user_id: hedef,
        ziyaretci_ad: ad.trim(),
        // `null` ACIKCA gonderilir: notu TEMIZLEMEK icin tek yol bu.
        // Alani hic gondermemek "degistirme" demek olurdu.
        notlar: notlar.trim() || null,
      };
      if (duzenlenen) await apiSend(`/api/visitors/${duzenlenen.id}`, "PATCH", govde);
      else await apiSend("/api/visitors", "POST", govde);
      formuSifirla();
      setDuzenlenen(null);
      setModalAcik(false);
      toast.success(t("ziyaretciKaydedildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  async function cikisYap(id: string) {
    try {
      await apiSend(`/api/visitors/${id}/checkout`, "POST");
      toast.success(t("ziyaretciCikisYapildi"));
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  // (P244 §6c) ICERIDEKI = cikis damgasi olmayan kayit.
  const iceridekiler = tumKayitlar.filter((z) => !z.cikis_zamani).length;

  const kolonlar = [
    {
      id: "ad",
      baslik: t("ziyaretciKolonAd"),
      hucre: (z: Ziyaretci) => (
        <span>
          <span className="block" style={{ color: "var(--yz-text)" }}>
            {z.ziyaretci_ad}
          </span>
          {z.notlar ? (
            <span
              className="block truncate"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {z.notlar}
            </span>
          ) : null}
        </span>
      ),
      deger: (z: Ziyaretci) => z.ziyaretci_ad,
    },
    {
      id: "daire",
      baslik: t("aracKolonDaire"),
      hucre: (z: Ziyaretci) => z.unit_no ?? "—",
      deger: (z: Ziyaretci) => z.unit_no ?? "",
    },
    {
      id: "giris",
      baslik: t("ziyaretciKolonGiris"),
      hucre: (z: Ziyaretci) => tarihSaatUzun(z.giris_zamani),
      deger: (z: Ziyaretci) => z.giris_zamani,
    },
    {
      id: "durum",
      baslik: t("ortakDurum"),
      // ROZET METIN TASIR: renk tek tasiyici degil.
      hucre: (z: Ziyaretci) =>
        z.cikis_zamani ? (
          <span style={{ color: "var(--yz-text-2)" }}>
            {t("aracCikti", { saat: tarihSaatUzun(z.cikis_zamani) })}
          </span>
        ) : (
          <Rozet durum="bilgi" nokta>
            {t("aracIceride")}
          </Rozet>
        ),
      deger: (z: Ziyaretci) => (z.cikis_zamani ? "1" : "0"),
    },
    {
      id: "eylem",
      kartRolu: "eylem" as const,
      baslik: "",
      gizlenebilir: false,
      hucre: (z: Ziyaretci) => (
        <div className="flex justify-end gap-2">
          {/* DUZENLEME CIKISTAN BAGIMSIZ: kapida yanlis yazilan bir ad ya
              da daire, ziyaretci ciktiktan SONRA da duzeltilebilmeli —
              kayit aksi halde kalici olarak yanlis kalir. Sunucu kapisi
              (`_REGISTRAR`) ikisinde de ayni. */}
          <Dugme
            boy="kucuk"
            onClick={() => {
              setDuzenlenen({ id: z.id });
              formuSifirla();
              setAd(z.ziyaretci_ad);
              // Kayitli daire + hedef ON-SECILI gelir: duzenleme yalniz adi
              // duzeltmek icin acildiysa daireyi yeniden aramak gerekmesin.
              if (z.unit_no) {
                setDaire({
                  id: "",
                  no: z.unit_no,
                  blok: null,
                  sakinler: z.target_resident_user_id
                    ? [{ user_id: z.target_resident_user_id, ad: z.target_resident_ad ?? "" }]
                    : [],
                });
                setHedef(z.target_resident_user_id ?? "");
              }
              setNotlar(z.notlar ?? "");
              setHata(null);
              setModalAcik(true);
            }}
          >
            {t("ortakDuzenle")}
          </Dugme>
          {/* CIKIS DUGMESI yalnizca ICERIDEKI ziyaretcide: cikmis birine
              tekrar cikis yaptirmak, kaydi ikinci kez damgalamak
              olurdu. */}
          {!z.cikis_zamani ? (
            <Dugme boy="kucuk" onClick={() => void cikisYap(z.id)}>
              {t("ziyaretciCikis")}
            </Dugme>
          ) : null}
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <SayfaBasligi
        baslik={t("ziyaretciBaslik")}
        eylem={
          <Dugme
          tur="birincil"
          boy="kucuk"
          onClick={() => {
            // YENI KAYIT: duzenleme durumu ve alanlar TEMIZLENIR.
            // Temizlemeseydik "yeni" dugmesi son duzenlenen kaydin
            // uzerine yazardi.
            setDuzenlenen(null);
            formuSifirla();
            setHata(null);
            setModalAcik(true);
          }}
        >
            {t("ziyaretciYeni")}
          </Dugme>
        }
      />

      {/* (P244 §6c / P245) OZET SERIDI — SUZGECTEN BAGIMSIZ KUMEDEN.
          Eskiden gorunen listeden sayiliyordu ve bu dogruydu: suzgec
          YOKTU. "Icerideki" sayisi operasyonun en sik sordugu soru
          (kapida kac kisi var) ve suzgec acikken de dogru kalmali. */}
      {!isLoading && !error && tumKayitlar.length > 0 && (
        <OzetSeridi>
          <OzetKarti
            etiket={t("ziyaretciOzetToplam")}
            deger={String(tumKayitlar.length)}
            durum="notr"
          />
          <OzetKarti
            etiket={t("ziyaretciOzetIceride")}
            deger={String(iceridekiler)}
            durum={iceridekiler > 0 ? "bilgi" : "olumlu"}
            altBilgi={t("ziyaretciOzetIcerideAlt")}
          />
          <OzetKarti
            etiket={t("ziyaretciOzetCikmis")}
            deger={String(tumKayitlar.length - iceridekiler)}
            durum="olumlu"
          />
        </OzetSeridi>
      )}

      <FiltreCubugu
        aktifSayi={icerdeSuzgec ? 1 : 0}
        onTemizle={() => setIcerdeSuzgec(SUZGEC_HEPSI)}
      >
        {/* SECIM GORUNMEZ ETIKETLI: serit her kontrolun ustune bir
            etiket satiri koyunca iki kata cikiyordu; ad `aria-label`
            ile KALIR. */}
        <Secim
          aria-label={t("ziyaretciDurumSuzgec")}
          value={icerdeSuzgec}
          onChange={(e) => setIcerdeSuzgec(e.target.value)}
          className="w-auto"
        >
          <option value={SUZGEC_HEPSI}>{t("ziyaretciDurumHepsi")}</option>
          <option value={SUZGEC_ICERDE}>{t("ziyaretciOzetIceride")}</option>
          <option value={SUZGEC_CIKMIS}>{t("ziyaretciOzetCikmis")}</option>
        </Secim>
      </FiltreCubugu>

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={duzenlenen ? t("ziyaretciDuzenle") : t("ziyaretciYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
            tur="birincil"
            disabled={gonderiyor}
            onClick={() => void kaydet()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : duzenlenen ? t("ortakKaydet") : t("ziyaretciGirisKaydet")}
          </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
          <AlanSarmal etiket={t("ziyaretciAd")}>
  {(b) => (
    <Alan {...b} value={ad}
              onChange={(e) => setAd(e.target.value)}
              maxLength={120} />
  )}
</AlanSarmal>
          {daire ? (
            <div className="space-y-2" data-test="ziyaretci-secili-daire">
              <div className="flex items-center justify-between gap-2">
                <span style={{ color: "var(--yz-text)" }}>
                  <span style={{ color: "var(--yz-text-2)" }}>{t("ziyaretciDaire")}</span>{" "}
                  <strong>{daire.no}</strong>
                </span>
                <Dugme boy="kucuk" tur="sessiz" onClick={() => daireSec(null)}>
                  {t("ziyaretciDaireDegistir")}
                </Dugme>
              </div>
              {daire.sakinler.length === 0 ? (
                <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
                  {t("ziyaretciSakinYok")}
                </p>
              ) : (
                <AlanSarmal etiket={t("ziyaretciHedefSakin")}>
                  {(b) => (
                    <Secim {...b} value={hedef} onChange={(e) => setHedef(e.target.value)}>
                      <option value="">—</option>
                      {daire.sakinler.map((s) => (
                        <option key={s.user_id} value={s.user_id}>
                          {s.ad}
                        </option>
                      ))}
                    </Secim>
                  )}
                </AlanSarmal>
              )}
            </div>
          ) : (
            <div className="space-y-2">
              <AlanSarmal etiket={t("ziyaretciDaireAra")}>
                {(b) => (
                  <Alan {...b} value={arama}
                    onChange={(e) => setArama(e.target.value)}
                    maxLength={100} />
                )}
              </AlanSarmal>
              {gecikmeliArama.length >= ARAMA_ALT_SINIR && aramaSonucu ? (
                aramaSonucu.length === 0 ? (
                  <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
                    {t("ziyaretciAramaSonucYok")}
                  </p>
                ) : (
                  <ul className="space-y-1" data-test="ziyaretci-daire-sonuclari">
                    {aramaSonucu.map((d) => (
                      <li key={d.id}>
                        <Dugme boy="kucuk" tur="sessiz" onClick={() => daireSec(d)}>
                          {d.no}
                          {d.sakinler.length > 0
                            ? ` · ${d.sakinler.map((s) => s.ad).join(", ")}`
                            : null}
                        </Dugme>
                      </li>
                    ))}
                  </ul>
                )
              ) : null}
            </div>
          )}
          <AlanSarmal etiket={t("ziyaretciNot")}>
  {(b) => (
    <Alan {...b} value={notlar}
              onChange={(e) => setNotlar(e.target.value)}
              maxLength={500} />
  )}
</AlanSarmal>
        </div>
        <HataDurumu mesaj={hata} />
        </div>
      </Modal>

      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("ziyaretciListe")}</h2>
        {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <IskeletMetin satir={3} />
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <BosDurum baslik={t("ziyaretciYok")} aciklama={t("ziyaretciYokAlt")} />
        ) : null}
        {/* (P244 §6c) KART YIGINI -> TABLO.
            Her ziyaretci AYRI BIR KARTTI; kayit tekrarli ve kisa alanli
            (ad, daire, giris, cikis). Tablo ayni alanda cok daha fazla
            kayit gosterir ve "kim iceride" sorusu tek sutundan okunur.
            HATA TABLOYA VERILIR (P61): istek dustugunde "kayit yok"
            yazmak, kayit OLMADIGINI soylemek olurdu. */}
        <VeriTablosu
          kolonlar={kolonlar}
          satirlar={kayitlar}
          satirId={(z) => z.id}
          yukleniyor={isLoading}
          hata={error ? t("ortakHataOlustu") : null}
          yogunluk="sik"
          bosBaslik={t("ziyaretciYok")}
          bosAciklama={t("ziyaretciYokAlt")}
        />
      </section>
    </div>
  );
}
