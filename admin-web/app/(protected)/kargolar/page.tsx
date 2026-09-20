"use client";

// (P126.4) KARGOLAR — kapı teslimatı + sakinin teslim alması.
//
// Kargo kapıda TESLİM ALINIR, sonra sakine TESLİM EDİLİR: iki ayrı an ve
// iki ayrı durum (`bekliyor` → `teslim_alindi`).
//
// (P162 §5) İKİNCİ AN DA BURADA. Ölçüldü: mobilde sakin kargosunu
// "teslim aldım" diye işaretleyebiliyordu, webde işaretleyemiyordu.
//
// AYRI SAYFA AÇILMADI ve bu bilinçli: `GET /kargo` zaten ROL KAPSAMLI —
// `resident` yalnızca KENDİ dairelerinin kargolarını görür
// (`_aktif_daire_ids`). Yani sakin bu sayfayı açtığında zaten kendi
// listesini görüyordu; eksik olan tek şey düğmeydi. İkinci bir sayfa,
// aynı listeyi iki yerde tutmak olurdu.
//
// DÜĞME ROL FARKINDA ama YETKİ KARARI SUNUCUDA: `PATCH /kargo/{id}`
// yalnız o dairenin aktif sakinine açık (başkasına 404 — varlık
// sızdırılmaz). İstemcideki kontrol yalnızca GÖRÜNÜRLÜK içindir;
// güvenliğe basacağı 404 üreten bir düğme göstermemek için.
//
// ===========================================================================
// (P244 §8a) KART YIGINI -> OPERASYON TABLOSU
// ===========================================================================
// Ekran her kargoyu AYRI BIR KART olarak diziyordu. Kargo kaydi bes
// alanli ve TEKRARLI bir kayittir (daire, firma, zaman, not, durum);
// kart dili her kayda bir baslik seviyesi verip ekrana dort kayit
// sigdiriyordu. Kapidaki gorevlinin sordugu soru ise "hangi daireninki
// bekliyor" — bu bir TARAMA sorusudur ve sutun ister.
import { useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Alan,
  AlanSarmal,
  Dugme,
  FiltreCubugu,
  HataDurumu,
  OzetKarti,
  OzetSeridi,
  Rozet,
  SayfaBasligi,
  Secim,
  VeriTablosu,
} from "@/components/ui";
import type { Kolon } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihSaatUzun } from "@/lib/tarih";

type Kargo = {
  id: string;
  unit_no: string | null;
  firma: string | null;
  notlar: string | null;
  durum: string;
  created_at: string;
};
type KargoSayfa = { items: Kargo[]; meta?: { total?: number } };

// METIN DEGIL KIMLIK (modul duzeyi — tur 18 dersi).
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  bekliyor: "kargoBekliyor",
  teslim_alindi: "kargoTeslimAlindi",
};

function durumAnahtari(durum: string): SozlukAnahtari {
  const a = DURUM_ANAHTARI[durum];
  if (a) return a;
  // `??` tek satirda yazilirsa sabit-metin taramasi bunu bir uclu sayar.
  return "kargoDurumBilinmiyor";
}

// UCLUDE/GOVDEDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const ROL_SAKIN = "resident" as const;
const KARGO_BEKLIYOR = "bekliyor" as const;
const KARGO_TESLIM = "teslim_alindi" as const;
const HEPSI = "" as const;
const YOK = "—";

const IKON_KUTU = "M3 8.5 12 4l9 4.5M3 8.5V17l9 4.5M3 8.5l9 4.5m0 0v9m0-9 9-4.5M21 8.5V17l-9 4.5";
const IKON_ONAY = "M20 6 9 17l-5-5";
const IKON_ARSIV = "M3 6h18v4H3zM5 10v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-9M10 14h4";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

export default function KargolarPage() {
  const t = useT();
  const toast = useToast();
  const [durumSuzgec, setDurumSuzgec] = useState<string>(HEPSI);

  // SUZGEC SUNUCUDA: liste sayfalanmis geliyor (`limit=50`) ve istemcide
  // suzmek YALNIZ GORUNEN sayfayi suzerdi — kullanici "bekleyen yok" der,
  // oysa bekleyen kayit ikinci sayfadadir.
  const sorgu = new URLSearchParams({ limit: "50", offset: "0" });
  if (durumSuzgec) sorgu.set("durum", durumSuzgec);
  const { data, error, isLoading, mutate } = useSWR<KargoSayfa>(
    `/api/kargo?${sorgu.toString()}`,
    jsonFetcher,
  );

  // OZET SAYILARI `meta.total`DAN — GORUNEN SAYFADAN DEGIL. Gorunen 50
  // kaydi saymak, "3 kargo bekliyor" gibi yanlis bir sayi uretirdi.
  const { data: bekleyen } = useSWR<KargoSayfa>(
    `/api/kargo?limit=1&offset=0&durum=${KARGO_BEKLIYOR}`,
    jsonFetcher,
  );
  const { data: teslim } = useSWR<KargoSayfa>(
    `/api/kargo?limit=1&offset=0&durum=${KARGO_TESLIM}`,
    jsonFetcher,
  );

  const [daireNo, setDaireNo] = useState("");
  const [firma, setFirma] = useState("");
  const [notlar, setNotlar] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  // Rol: teslim düğmesinin GÖRÜNÜRLÜĞÜ için (yetki sunucuda).
  const { data: ben } = useSWR<{ role?: string }>("/api/me", jsonFetcher);
  const sakinMi = ben?.role === ROL_SAKIN;

  async function teslimAl(id: string) {
    try {
      // Sunucu ATOMİK yapar: `durum='bekliyor'` koşullu UPDATE. Eşler
      // aynı anda bassa bile ikincisi 409 alır ve KİMİN teslim aldığı
      // değişmez.
      await apiSend(`/api/kargo/${id}`, "PATCH", { durum: KARGO_TESLIM });
      toast.success(t("kargoTeslimAlindiBildirim"));
      void mutate();
    } catch (e) {
      toast.error(alanliHataMetni(e, t("ortakHataOlustu")));
    }
  }

  const kayitlar = data?.items ?? [];

  async function kaydet() {
    if (!daireNo.trim()) {
      setHata(t("kargoDaireZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      // DAIRE NO ile: kapidaki gorevli daire NUMARASINI bilir (ziyaretci
      // ekraniyla ayni gerekce). Sunucu numarayi cozer.
      await apiSend("/api/kargo", "POST", {
        unit_no: daireNo.trim(),
        firma: firma.trim() || null,
        notlar: notlar.trim() || null,
      });
      setDaireNo("");
      setFirma("");
      setNotlar("");
      setModalAcik(false);
      toast.success(t("kargoKaydedildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  const kolonlar: Kolon<Kargo>[] = [
    {
      id: "daire",
      baslik: t("kargoDaire"),
      hucre: (k) => <span className="font-medium tabular-nums">{k.unit_no ?? YOK}</span>,
      deger: (k) => k.unit_no ?? "",
      kartRolu: "baslik",
    },
    {
      id: "firma",
      baslik: t("kargoFirma"),
      hucre: (k) => k.firma ?? YOK,
      deger: (k) => k.firma ?? "",
      kartRolu: "ozet",
    },
    {
      id: "zaman",
      baslik: t("kargoKolonZaman"),
      hucre: (k) => tarihSaatUzun(k.created_at),
      deger: (k) => k.created_at,
      kartRolu: "ozet",
    },
    {
      id: "not",
      baslik: t("kargoNot"),
      hucre: (k) => k.notlar ?? YOK,
      darEkrandaGizle: true,
    },
    {
      id: "durum",
      baslik: t("kargoKolonDurum"),
      // DURUM RENKLE DEGIL METINLE: kelime rozetin icinde yaziyor, renk
      // yalnizca ikinci ipucu.
      hucre: (k) => (
        <Rozet durum={k.durum === KARGO_BEKLIYOR ? "uyari" : "olumlu"}>
          {t(durumAnahtari(k.durum))}
        </Rozet>
      ),
      kartRolu: "rozet",
    },
    {
      id: "eylem",
      baslik: t("listeIslemler"),
      // TESLIM ALDIM — yalniz SAKIN ve yalniz BEKLEYEN kargoda.
      // Teslim alinmis bir kargoyu tekrar isaretlemek, geri donusu
      // olmayan bir damgayi ikinci kez basmakti (sunucu da 409 doner).
      // Guvenlikte dugme HIC cizilmez: sunucu ona 404 verir ve
      // basilacak bir dugme gostermek "yetkim var sandim" demektir.
      hucre: (k) =>
        sakinMi && k.durum === KARGO_BEKLIYOR ? (
          <Dugme boy="kucuk" tur="birincil" onClick={() => void teslimAl(k.id)}>
            {t("kargoTeslimAldim")}
          </Dugme>
        ) : null,
      gizlenebilir: false,
      kartRolu: "eylem",
    },
  ];

  return (
    <div>
      <SayfaBasligi
        baslik={t("kargoBaslik")}
        aciklama={t("kargoSayfaAlt")}
        eylem={
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden
              // acildiginda onceki denemenin mesaji ekranda duruyordu ve
              // kullanici hic denemeden hata gormus oluyordu.
              setHata(null);
              setModalAcik(true);
            }}
          >
            {t("kargoYeni")}
          </Dugme>
        }
      />

      <OzetSeridi>
        <OzetKarti
          etiket={t("kargoOzetBekleyen")}
          deger={String(bekleyen?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_KUTU} />}
          durum="uyari"
          altBilgi={t("kargoOzetBekleyenAlt")}
        />
        <OzetKarti
          etiket={t("kargoOzetTeslim")}
          deger={String(teslim?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_ONAY} />}
          durum="olumlu"
        />
        <OzetKarti
          etiket={t("kargoOzetToplam")}
          deger={String((bekleyen?.meta?.total ?? 0) + (teslim?.meta?.total ?? 0))}
          ikon={<Ikon yol={IKON_ARSIV} />}
          durum="notr"
        />
      </OzetSeridi>

      <FiltreCubugu
        aktifSayi={durumSuzgec ? 1 : 0}
        onTemizle={() => setDurumSuzgec(HEPSI)}
      >
        {/* SECIM GORUNMEZ ETIKETLI: serit iki kata cikmasin; ekran
            okuyucu icin ad `aria-label` ile KALIR. */}
        <Secim
          aria-label={t("kargoDurumSuzgec")}
          value={durumSuzgec}
          onChange={(e) => setDurumSuzgec(e.target.value)}
          className="w-auto"
        >
          <option value={HEPSI}>{t("kargoDurumHepsi")}</option>
          <option value={KARGO_BEKLIYOR}>{t("kargoBekliyor")}</option>
          <option value={KARGO_TESLIM}>{t("kargoTeslimAlindi")}</option>
        </Secim>
      </FiltreCubugu>

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("kargoYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={gonderiyor} onClick={() => void kaydet()}>
              {gonderiyor ? t("ortakKaydediliyor") : t("kargoTeslimAl")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <AlanSarmal etiket={t("kargoDaire")}>
              {(b) => (
                <Alan
                  {...b}
                  value={daireNo}
                  onChange={(e) => setDaireNo(e.target.value)}
                  maxLength={30}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("kargoFirma")}>
              {(b) => (
                <Alan
                  {...b}
                  value={firma}
                  onChange={(e) => setFirma(e.target.value)}
                  maxLength={80}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("kargoNot")}>
              {(b) => (
                <Alan
                  {...b}
                  value={notlar}
                  onChange={(e) => setNotlar(e.target.value)}
                  maxLength={500}
                />
              )}
            </AlanSarmal>
          </div>
          <HataDurumu mesaj={hata} />
        </div>
      </Modal>

      {/* (P61) HATA TABLOYA VERILIR: istek dustugunde `kayitlar` bos
          gelir ve "kargo kaydi yok" yazmak, kaydin OLMADIGINI soylemek
          olurdu — oysa bilinen tek sey listenin okunamadigi. */}
      <VeriTablosu
        kolonlar={kolonlar}
        satirlar={kayitlar}
        satirId={(k) => k.id}
        yukleniyor={isLoading}
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
        yogunluk="sik"
        yapiskanBaslik
        bosBaslik={t("kargoYok")}
        bosAciklama={durumSuzgec ? t("kargoYokSuzgecli") : t("kargoYokAlt")}
      />
    </div>
  );
}
