"use client";

// (P126.4) ARAÇ GEÇİŞLERİ — SALT OKUMA.
//
// Kayıtlar ANPR ile OTOMATİK oluşur (P16). Elle giriş formu bilerek yok:
// plakayı elle yazmak, otomatik kayıtla çelişen ikinci bir gerçek üretirdi
// ve "hangisi doğru?" sorusunu operasyona bırakırdı. BFF proxy'si de
// yalnız `GET` açıyor.
//
// ===========================================================================
// (P244 §6) YENIDEN TASARIM — OLCULEN EN ZAYIF EKRAN
// ===========================================================================
// Sayfa 69 satirdi ve her kaydi AYRI BIR KART olarak alt alta diziyordu:
// 50 gecis = 50 kart. Referansta ayni ekran bes ozet karti + YOGUN bir
// operasyon tablosu (saat, plaka, tip, surucu, kapi, durum).
//
// Kart dizisi burada yanlis bir secimdi: gecis kaydi UC ALANLI ve
// TEKRARLI bir kayittir; kart dili her kayda bir baslik seviyesi verip
// ekrana dort kayit sigdiriyordu. Tablo ayni alanda yirmi bes kayit
// gosterir ve goz sutunlari takip eder.
import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  AramaAlani,
  FiltreCubugu,
  OzetKarti,
  OzetSeridi,
  Rozet,
  SayfaBasligi,
  Secim,
  VeriTablosu,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Gecis = {
  id: string;
  plaka: string;
  arac_tanim: string | null;
  giris_zamani: string;
  cikis_zamani: string | null;
  unit_no: string | null;
  ziyaretci_mi: boolean;
};
type Sayfa = { items: Gecis[]; meta?: { total?: number } };

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const HEPSI = "" as const;
const ACIK = "true" as const;
const KAPALI = "false" as const;

const IKON_ARAC =
  "M5 17a2 2 0 1 0 4 0 2 2 0 0 0-4 0ZM15 17a2 2 0 1 0 4 0 2 2 0 0 0-4 0ZM4 17H3v-4l2-5h11l3 5h2v4h-1M7 17h8";
const IKON_ICERI = "M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 12H3m0 0 3-3m-3 3 3 3";
const IKON_MISAFIR = "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4 21a8 8 0 0 1 16 0";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

/** Gun basi — "bugun kac giris" sayaci icin (sozlesmenin tarif ettigi kullanim). */
function gunBasi(): string {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.toISOString();
}

export default function AracGecisleriPage() {
  const t = useT();
  const [plaka, setPlaka] = useState("");
  const [durum, setDurum] = useState<string>(HEPSI);

  // ARAMA SUNUCUDA, ISTEMCIDE DEGIL: liste sayfalanmis geliyor ve
  // istemcide suzmek YALNIZ GORUNEN 50 kaydi arardi — kullanici
  // "plakam yok" der, oysa kayit ikinci sayfadadir.
  const sorgu = new URLSearchParams({ limit: "50", offset: "0" });
  if (plaka.trim()) sorgu.set("plaka", plaka.trim());
  if (durum) sorgu.set("acik", durum);
  const { data, error, isLoading } = useSWR<Sayfa>(
    `/api/vehicle-passes?${sorgu.toString()}`,
    jsonFetcher,
  );

  // OZET SAYILARI `meta.total`DAN — GORUNEN SAYFADAN DEGIL.
  // Gorunen 50 kaydi saymak, "bugun 50 giris oldu" gibi YANLIS bir sayi
  // uretirdi; sozlesme bu sayaclari tam olarak boyle tarif ediyor
  // (`?acik=true&limit=1` -> `meta.total`).
  const { data: iceride } = useSWR<Sayfa>(
    "/api/vehicle-passes?acik=true&limit=1&offset=0",
    jsonFetcher,
  );
  const [bugunBasi] = useState(gunBasi);
  const { data: bugun } = useSWR<Sayfa>(
    `/api/vehicle-passes?limit=1&offset=0&baslangic=${encodeURIComponent(bugunBasi)}`,
    jsonFetcher,
  );

  const kayitlar = data?.items ?? [];
  const aktifSuzgec = (plaka.trim() ? 1 : 0) + (durum ? 1 : 0);

  const kolonlar = useMemo(
    () => [
      {
        id: "saat",
        baslik: t("aracKolonSaat"),
        hucre: (g: Gecis) => tarihSaatUzun(g.giris_zamani),
        deger: (g: Gecis) => g.giris_zamani,
      },
      {
        id: "plaka",
        baslik: t("aracKolonPlaka"),
        // PLAKA SABIT GENISLIKTE RAKAMLA: sutun kaymasin, goz tarasin.
        hucre: (g: Gecis) => <span className="font-medium tabular-nums">{g.plaka}</span>,
        deger: (g: Gecis) => g.plaka,
      },
      {
        id: "arac",
        baslik: t("aracKolonArac"),
        hucre: (g: Gecis) => g.arac_tanim ?? "—",
        darEkrandaGizle: true,
      },
      {
        id: "daire",
        baslik: t("aracKolonDaire"),
        hucre: (g: Gecis) => g.unit_no ?? "—",
        deger: (g: Gecis) => g.unit_no ?? "",
      },
      {
        id: "tip",
        baslik: t("aracKolonTip"),
        hucre: (g: Gecis) => (
          <Rozet durum={g.ziyaretci_mi ? "bilgi" : "notr"}>
            {g.ziyaretci_mi ? t("aracZiyaretci") : t("aracSakin")}
          </Rozet>
        ),
        darEkrandaGizle: true,
      },
      {
        id: "durum",
        baslik: t("aracKolonDurum"),
        // DURUM RENKLE DEGIL METINLE: "İçeride"/"Çıktı" kelimesi rozetin
        // icinde yaziyor; renk yalnizca ikinci ipucu.
        hucre: (g: Gecis) =>
          g.cikis_zamani ? (
            <span style={{ color: "var(--yz-text-2)" }}>
              {t("aracCikti", { saat: tarihSaatUzun(g.cikis_zamani) })}
            </span>
          ) : (
            <Rozet durum="olumlu" nokta>
              {t("aracIceride")}
            </Rozet>
          ),
      },
    ],
    [t],
  );

  return (
    <div>
      <SayfaBasligi baslik={t("aracBaslik")} aciklama={t("aracOtomatikNot")} />

      <OzetSeridi>
        <OzetKarti
          etiket={t("aracOzetBugun")}
          deger={String(bugun?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_ARAC} />}
          durum="bilgi"
        />
        <OzetKarti
          etiket={t("aracOzetIceride")}
          deger={String(iceride?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_ICERI} />}
          durum="olumlu"
          altBilgi={t("aracOzetIcerideAlt")}
        />
        <OzetKarti
          etiket={t("aracOzetToplam")}
          deger={String(data?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_MISAFIR} />}
          durum="notr"
          altBilgi={aktifSuzgec > 0 ? t("aracOzetSuzgecli") : undefined}
        />
      </OzetSeridi>

      <FiltreCubugu
        arama={
          <AramaAlani
            deger={plaka}
            onDegisim={setPlaka}
            etiket={t("aracAramaEtiket")}
            yerTutucu={t("aracAramaIpucu")}
            temizleEtiketi={t("ortakKapat")}
          />
        }
        aktifSayi={aktifSuzgec}
        onTemizle={() => {
          setPlaka("");
          setDurum(HEPSI);
        }}
      >
        {/* SECIM GORUNMEZ ETIKETLI: filtre cubugunda her kontrolun
            ustune bir etiket satiri koymak seridi iki kata cikarirdi;
            ekran okuyucu icin ad `aria-label` ile KALIR. */}
        <Secim
          aria-label={t("aracKolonDurum")}
          value={durum}
          onChange={(e) => setDurum(e.target.value)}
          className="w-auto"
        >
          <option value={HEPSI}>{t("aracDurumHepsi")}</option>
          <option value={ACIK}>{t("aracIceride")}</option>
          <option value={KAPALI}>{t("aracCiktiKisa")}</option>
        </Secim>
      </FiltreCubugu>

      {/* (P61) HATA TABLOYA VERILIR, YANINA YAZILMAZ.
          Ilk yazimda hata ayri bir satirda duruyor ve tablo ALTINDA
          tablonun bos durumunu ciziyordu — yani istek dusmusken
          kullaniciya KAYIT OLMADIGI soyleniyordu. Bilinen tek sey
          listenin okunamadigi. `VeriTablosu` hatayi alinca bos durum
          yerine tekrar dugmesini cizer. */}
      <VeriTablosu
        kolonlar={kolonlar}
        satirlar={kayitlar}
        satirId={(g) => g.id}
        yukleniyor={isLoading}
        hata={error ? t("ortakHataOlustu") : null}
        // YOGUN: operasyon tablosu. Kayit tekrarli ve kisa; ekrana cok
        // satir sigmasi okunurluktan daha degerli.
        yogunluk="sik"
        yapiskanBaslik
        numarali
        bosBaslik={t("aracYok")}
        bosAciklama={aktifSuzgec > 0 ? t("aracYokSuzgecli") : t("aracYokAlt")}
      />
    </div>
  );
}
