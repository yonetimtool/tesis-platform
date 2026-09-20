"use client";

// (P126.5) DIŞ HİZMETLER — güvenilir esnaf rehberi.
//
// OKUMA tüm rollere açıktır (sunucu: "güvenilir esnafı herkes görür/
// arayabilir"), YAZMA admin+yönetici. Ekran ikisini de tek sayfada tutar;
// yazma formunu role göre gizlemiyoruz çünkü `app.*`ta bu sayfa yönetici
// menüsündedir — sunucu zaten reddeder ve gizlemek yetkilendirme değildir.
//
// TELEFON P123 MASKESİNDEN GEÇER: rehberdeki numara aranmak içindir;
// gruplanmamış 11 hane okunmaz ve yanlış tuşlanır.
//
// ===========================================================================
// (P244 §8a) KART YIGINI -> ARANABILIR REHBER TABLOSU
// ===========================================================================
// Rehber her esnafi AYRI BIR KART olarak diziyordu. `yonetim-iletisim`
// icin kart DOGRU secimdir (orada liste UC-BES kisilik sabit bir yonetim
// kadrosudur, kartvizit gibi okunur); rehber ise BUYUR — tesisin tum
// guvenilir esnafi. Karti buyuyen listede kullanmak, "tesisatci kimdi"
// sorusunu sayfa boyu kaydirmaya cevirir.
//
// ARAMA ISTEMCIDE ve bu BILINCLI: uc sayfalamiyor, TUM listeyi tek
// seferde donuyor (`GET /external-services`, `limit` parametresi YOK).
// Yani elimizdeki dizi listenin TAMAMI; istemcide suzmek burada eksik
// sonuc uretmez (kargo/arac ekranlarinda uretirdi — orada sunucuda
// suzuluyor).
import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Alan,
  AlanSarmal,
  AramaAlani,
  Dugme,
  FiltreCubugu,
  Kart,
  Rozet,
  SayfaBasligi,
  Secim,
  VeriTablosu,
  useOnay,
} from "@/components/ui";
import type { Kolon } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { TelefonAlani, telefonHataMetni } from "@/components/TelefonAlani";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";

type Hizmet = {
  id: string;
  tur: string;
  ad: string;
  soyad: string;
  telefon: string;
  aciklama: string | null;
};
/** Liste yaniti bir de BOLUM NOTU tasir (yoneticinin serbest metni). */
type Liste = { note: string | null; items: Hizmet[] };

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const ROZET_NOTR = "notr" as const;
const HEPSI = "" as const;
const YOK = "—";

export default function DisHizmetlerPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<Liste>(
    "/api/external-services",
    jsonFetcher,
  );

  const [tur, setTur] = useState("");
  const [ad, setAd] = useState("");
  const [soyad, setSoyad] = useState("");
  const [telefon, setTelefon] = useState("");
  /** (P166 §9) Telefonun ALAN BAZINDA hatasi — sayfa hata kutusundan AYRI. */
  const [telefonHatasiMetni, setTelefonHatasiMetni] = useState<string | null>(null);
  const [aciklama, setAciklama] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  // (P162 §5) DIS HIZMET DUZENLEME + SILME — webde YOKTU.
  //
  // Uclar (`PATCH/DELETE /external-services/{id}`) ve rol kapisi
  // (`_WRITER` = admin + yonetici) zaten vardi; mobilde kullaniliyordu,
  // webde vekil ve dugme eksikti. Rehberdeki bir numara degistiginde
  // kaydi silip yeniden yazmak, kaydin kimligini (ve ona bagli izleri)
  // gereksizce degistirmekti.
  //
  // AYNI MODAL: yeni kayit ile duzenleme tek formu paylasir.
  const [duzenlenen, setDuzenlenen] = useState<{ id: string } | null>(null);
  const { onayla, diyalog } = useOnay();

  // (P244 §8a) ARAMA + TUR SUZGECI — rehberin asil kullanimi.
  const [arama, setArama] = useState("");
  const [turSuzgec, setTurSuzgec] = useState<string>(HEPSI);

  // `?? []` her cizimde YENI bir dizi uretir ve asagidaki `useMemo`lar
  // hicbir zaman onbellege vurmaz; referansi sabitliyoruz.
  const kayitlar = useMemo(() => data?.items ?? [], [data]);

  /** Rehberdeki TURLER veriden turetilir — sabit bir liste YOK (tur
      serbest metin alanidir; sabit liste bir gun veriyle ayrisirdi). */
  const turler = useMemo(
    () => [...new Set(kayitlar.map((h) => h.tur))].sort((a, b) => a.localeCompare(b)),
    [kayitlar],
  );

  const gorunen = useMemo(() => {
    const q = arama.trim().toLocaleLowerCase();
    return kayitlar.filter((h) => {
      if (turSuzgec && h.tur !== turSuzgec) return false;
      if (!q) return true;
      // AD, SOYAD, TUR ve TELEFON aranir: kullanici "kimdi" diye de
      // "hangi numaraydi" diye de arar.
      return `${h.ad} ${h.soyad} ${h.tur} ${h.telefon}`.toLocaleLowerCase().includes(q);
    });
  }, [kayitlar, arama, turSuzgec]);

  const aktifSuzgec = (arama.trim() ? 1 : 0) + (turSuzgec ? 1 : 0);

  function duzenlemeyeAc(h: Hizmet) {
    setDuzenlenen({ id: h.id });
    setTur(h.tur);
    setAd(h.ad);
    setSoyad(h.soyad);
    setTelefon(telefonGiris(h.telefon));
    setAciklama(h.aciklama ?? "");
    setHata(null);
    setModalAcik(true);
  }

  const kolonlar: Kolon<Hizmet>[] = [
    {
      id: "kisi",
      baslik: t("disHizmetKolonKisi"),
      hucre: (h) => (
        <span className="font-medium">
          {h.ad} {h.soyad}
        </span>
      ),
      deger: (h) => `${h.ad} ${h.soyad}`,
      kartRolu: "baslik",
    },
    {
      id: "tur",
      baslik: t("disHizmetTur"),
      hucre: (h) => <Rozet durum={ROZET_NOTR}>{h.tur}</Rozet>,
      deger: (h) => h.tur,
      kartRolu: "rozet",
    },
    {
      id: "telefon",
      baslik: t("kullaniciTelefon"),
      // `tel:` baglantisi KALDI: rehberdeki numara ARANMAK icindir ve
      // tabloya tasinirken kaybedilseydi ekran iş görmezdi.
      hucre: (h) => (
        <a
          className="underline tabular-nums"
          style={{ color: "var(--yz-accent-ink)" }}
          href={`tel:${h.telefon}`}
        >
          {telefonGiris(h.telefon)}
        </a>
      ),
      deger: (h) => h.telefon,
      kartRolu: "ozet",
    },
    {
      id: "aciklama",
      baslik: t("disHizmetAciklama"),
      hucre: (h) => h.aciklama ?? YOK,
      darEkrandaGizle: true,
    },
    {
      id: "eylem",
      baslik: t("listeIslemler"),
      hucre: (h) => (
        <div className="flex flex-wrap gap-2">
          <Dugme boy="kucuk" onClick={() => duzenlemeyeAc(h)}>
            {t("ortakDuzenle")}
          </Dugme>
          <Dugme boy="kucuk" tur="tehlike" onClick={() => void sil(h)}>
            {t("ortakSil")}
          </Dugme>
        </div>
      ),
      gizlenebilir: false,
      kartRolu: "eylem",
    },
  ];

  async function ekle() {
    // SOYAD DA ZORUNLU: sunucu `DisHizmetCreate.soyad` icin min_length=1
    // istiyor. Bos gondermek 422 uretirdi — kural sunucudan OKUNDU.
    if (!tur.trim() || !ad.trim() || !soyad.trim()) {
      setHata(t("disHizmetAlanZorunlu"));
      return;
    }
    // (P166 §9) HATA ALANIN YANINDA — sayfa kutusunda DEGIL. Ikisi
    // birden cizilirse kullanici ayni cumleyi iki yerde okur.
    const telHata = telefonHataMetni(telefon, true, t);
    if (telHata) {
      setTelefonHatasiMetni(telHata);
      return;
    }
    setTelefonHatasiMetni(null);
    setHata(null);
    setGonderiyor(true);
    try {
      const govde = {
        tur: tur.trim(),
        ad: ad.trim(),
        soyad: soyad.trim(),
        // Sunucuya NORMALLESTIRILMIS gider (P123).
        telefon: telefonNormalle(telefon),
        aciklama: aciklama.trim() || null,
      };
      if (duzenlenen) {
        await apiSend(`/api/external-services/${duzenlenen.id}`, "PATCH", govde);
      } else {
        await apiSend("/api/external-services", "POST", govde);
      }
      setTur("");
      setAd("");
      setSoyad("");
      setTelefon("");
      setAciklama("");
      setDuzenlenen(null);
      setModalAcik(false);
      toast.success(t("disHizmetEklendi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  async function sil(h: { id: string; ad: string; soyad: string }) {
    const ok = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("ortakSilOnay", { ad: `${h.ad} ${h.soyad}` }),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      await apiSend(`/api/external-services/${h.id}`, "DELETE");
      toast.success(t("ortakSilindi"));
      void mutate();
    } catch (e) {
      toast.error(alanliHataMetni(e, t("ortakSilinemedi")));
    }
  }

  return (
    <div>
      <SayfaBasligi
        baslik={t("disHizmetBaslik")}
        aciklama={t("disHizmetSayfaAlt")}
        eylem={
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              // YENI KAYIT: duzenleme durumu ve alanlar temizlenir; aksi
              // halde "yeni" dugmesi son duzenlenenin uzerine yazardi.
              setDuzenlenen(null);
              setTur("");
              setAd("");
              setSoyad("");
              setTelefon("");
              setAciklama("");
              setHata(null);
              setModalAcik(true);
            }}
          >
            {t("disHizmetYeni")}
          </Dugme>
        }
      />

      {/* BOLUM NOTU — yoneticinin serbest metni. Ozet serit YOK ve bu
          bilincli: rehberde sayilacak anlamli bir sey yok ("12 esnaf"
          kimsenin sordugu soru degil). Referansin her ekrana serit
          koyma refleksi burada bos bir kart seridi uretirdi. */}
      {data?.note ? (
        <Kart className="mb-4">
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>{data.note}</p>
        </Kart>
      ) : null}

      <FiltreCubugu
        arama={
          <AramaAlani
            deger={arama}
            onDegisim={setArama}
            etiket={t("disHizmetAramaEtiket")}
            yerTutucu={t("disHizmetAramaIpucu")}
            temizleEtiketi={t("ortakKapat")}
          />
        }
        aktifSayi={aktifSuzgec}
        onTemizle={() => {
          setArama("");
          setTurSuzgec(HEPSI);
        }}
      >
        <Secim
          aria-label={t("disHizmetTurSuzgec")}
          value={turSuzgec}
          onChange={(e) => setTurSuzgec(e.target.value)}
          className="w-auto"
        >
          <option value={HEPSI}>{t("disHizmetTurHepsi")}</option>
          {turler.map((x) => (
            <option key={x} value={x}>
              {x}
            </option>
          ))}
        </Secim>
      </FiltreCubugu>

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("disHizmetYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={gonderiyor} yukleniyor={gonderiyor} onClick={() => void ekle()}>
            {gonderiyor ? t("ortakKaydediliyor") : t("ortakEkle")}
          </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
          <AlanSarmal etiket={t("disHizmetTur")} zorunlu>
            {(b) => (
              <Alan {...b} value={tur} onChange={(e) => setTur(e.target.value)} maxLength={60} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("disHizmetAd")} zorunlu>
            {(b) => (
              <Alan {...b} value={ad} onChange={(e) => setAd(e.target.value)} maxLength={80} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("disHizmetSoyad")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={soyad}
                onChange={(e) => setSoyad(e.target.value)}
                maxLength={80}
              />
            )}
          </AlanSarmal>
          <TelefonAlani
            etiket={t("kullaniciTelefon")}
            zorunlu
            deger={telefon}
            hata={telefonHatasiMetni}
            onDegisti={(v) => {
              setTelefon(v);
              setTelefonHatasiMetni(null);
            }}
          />
          <AlanSarmal etiket={t("disHizmetAciklama")}>
            {(b) => (
              <Alan
                {...b}
                value={aciklama}
                onChange={(e) => setAciklama(e.target.value)}
                maxLength={500}
              />
            )}
          </AlanSarmal>
        </div>
        {hata && (
          <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
            {hata}
          </p>
        )}
        </div>
      </Modal>

      {/* (P61) HATA TABLOYA VERILIR: istek dustugunde `kayitlar` bos
          gelir ve "kayitli esnaf yok" yazmak, rehberin BOS oldugunu
          soylemek olurdu — oysa bilinen tek sey okunamadigi. */}
      <VeriTablosu
        kolonlar={kolonlar}
        satirlar={gorunen}
        satirId={(h) => h.id}
        yukleniyor={isLoading}
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
        bosBaslik={t("disHizmetYok")}
        bosAciklama={aktifSuzgec > 0 ? t("disHizmetYokSuzgecli") : t("disHizmetYokAlt")}
      />
      {diyalog}
    </div>
  );
}
