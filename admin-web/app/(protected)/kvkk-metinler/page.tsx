"use client";

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  Kart,
  Rozet,
  Secim,
  Sekmeler,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { ZenginMetin } from "@/components/ZenginMetin";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

/**
 * (P168 §5 · P170 §2) KVKK VE YASAL METINLER — PLATFORM YONETIMI.
 *
 * =========================================================================
 * (P170 §2) BU SAYFA ARTIK `panel.*` ALTINDA VE TESIS SECER
 * =========================================================================
 * Eskiden tesis yuzeyindeydi ve `yonetici` de yayin yapabiliyordu. Metinleri
 * PLATFORM yonetir: tesis yoneticisinin kendi aydinlatma metnini yazmasi,
 * hukuki sorumlulugu yazma yetkisiyle karistirmakti.
 *
 * VERI TENANT'A BAGLI KALDI — her tesisin veri sorumlusu kendisidir ve
 * platforma gomulu TEK bir metin 200 tesise baskasinin metnini imzalatmak
 * olurdu. Bu yuzden sayfa once TESIS sorar: hedef tenant yolda tasinir
 * (`/api/tenants/{id}/kvkk`), oturumdan turetilmez.
 *
 * OKUMA YUZEYI TASINMADI: her rol kendi profilinden metinleri okumaya ve
 * onay gecmisini gormeye devam ediyor (`/profil` -> Yasal Metinler).
 *
 * =========================================================================
 * BES METIN, HER BIRI KENDI SURUM SERISI
 * =========================================================================
 * Brief bes metin istiyor: Aydinlatma · Acik Riza · Gizlilik Politikasi ·
 * Kullanim Kosullari · Cerez Politikasi.
 *
 * Sekme basina ayri sayfa YAZILMADI: bes sayfa, ayni yayin formunu ve
 * ayni surum tablosunu bes kez tutmak olurdu. Tur bir SEKME, geri kalan
 * her sey ORTAK.
 *
 * =========================================================================
 * DUZENLEME YOK, YENI SURUM VAR
 * =========================================================================
 * Yayinlanmis bir metnin govdesini degistirmek, dun onay vermis bir
 * kullanicinin onayini BUGUN BASKA BIR METNE ait gostermek olurdu. Uc de
 * duzenleme tasimaz (P36 karari); ekran o kararin aynasi.
 *
 * YURURLUKTE OLAN, TUR BASINA EN YUKSEK SURUMDUR ve sunucudan TURETILMIS
 * gelir — istemci kendi hesaplamaz.
 */

interface TesisOgesi {
  id: string;
  ad: string;
}

interface PlatformDurum {
  metinler: Metin[];
  onaylar: { tur: string; surum: number; onaylayan: number }[];
}

interface Metin {
  id: string;
  tur: string;
  surum: number;
  baslik: string;
  govde: string;
  yeniden_onay_gerekir: boolean;
  yururlukte: boolean;
  created_at: string;
}

type Tur = "aydinlatma" | "acik_riza" | "gizlilik" | "kullanim_kosullari" | "cerez";
const TURLER: readonly Tur[] = [
  "aydinlatma",
  "acik_riza",
  "gizlilik",
  "kullanim_kosullari",
  "cerez",
];
const TUR_ETIKETI: Record<Tur, SozlukAnahtari> = {
  aydinlatma: "kvkkTurAydinlatma",
  acik_riza: "kvkkTurAcikRiza",
  gizlilik: "kvkkTurGizlilik",
  kullanim_kosullari: "kvkkTurKullanim",
  cerez: "kvkkTurCerez",
};

const BOS = "";
const ROZET_OLUMLU = "olumlu" as const;
const ROZET_NOTR = "notr" as const;

export default function KvkkMetinlerPage() {
  const t = useT();
  const toast = useToast();
  // SEKME ADRESTE: yenilemede ve paylasilan baglantida ayni metin acilsin.
  const [tur, setTur] = useSorguSecimi<Tur>("tur", TURLER, "aydinlatma");

  // TESIS LISTESI: platform yoneticisi hangi tesise yayin yaptigini SECER.
  const { data: tesisler } = useSWR<{ items: TesisOgesi[] }>(
    "/api/tenants",
    jsonFetcher,
  );
  // SECIM ADRESTE: yenilemede ve paylasilan baglantida ayni tesis acilir —
  // "hangi tesise yayinladim" sorusu adres cubugundan okunabilmeli.
  const [tesisId, setTesisId] = useState(BOS);

  const { data, error, mutate } = useSWR<PlatformDurum>(
    tesisId ? `/api/tenants/${tesisId}/kvkk` : null,
    jsonFetcher,
  );

  // TUR SUZGECI ISTEMCIDE: uc bir tesisin TUM metinlerini tek cagrida
  // veriyor (sunucu yorumu). Sekme basina yeni bir istek acmak, ayni
  // yaniti bes kez cekmek olurdu.
  const surumler = (data?.metinler ?? []).filter((m) => m.tur === tur);
  const onayOzeti = (data?.onaylar ?? []).find((o) => o.tur === tur);

  const [baslik, setBaslik] = useState(BOS);
  const [govde, setGovde] = useState(BOS);
  // (P168 §5) VARSAYILAN ACIK: guvenli yon SORMAKTIR. Kapali baslasaydi,
  // esasli bir degisikligi yayinlayan yonetici kutuyu isaretlemeyi
  // unuttugunda kimseye sorulmaz ve bu sessizce hukuki bir eksiklik
  // olurdu.
  const [yenidenOnay, setYenidenOnay] = useState(true);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  async function yayinla() {
    setHata(null);
    if (!baslik.trim() || !govde.trim()) {
      setHata(t("yonKvkkZorunlu"));
      return;
    }
    setMesgul(true);
    try {
      await apiSend(`/api/tenants/${tesisId}/kvkk`, "POST", {
        tur,
        baslik: baslik.trim(),
        govde,
        yeniden_onay_gerekir: yenidenOnay,
      });
      setBaslik(BOS);
      setGovde(BOS);
      setYenidenOnay(true);
      toast.success(t("yonKvkkYayinlandi"));
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  const kolonlar: Kolon<Metin>[] = [
    { id: "surum", kartRolu: "baslik", baslik: t("kvkkSurum"), sayisal: true, hucre: (m) => `v${m.surum}` },
    { id: "baslik", kartRolu: "ozet", baslik: t("yonKvkkBaslik"), hucre: (m) => m.baslik },
    {
      id: "created_at", kartRolu: "ozet",
      baslik: t("kvkkYayinTarihi"),
      hucre: (m) => formatDateTime(m.created_at),
    },
    {
      id: "yururlukte", kartRolu: "rozet",
      baslik: t("kvkkYururluk"),
      hucre: (m) => (
        <Rozet durum={m.yururlukte ? ROZET_OLUMLU : ROZET_NOTR}>
          {m.yururlukte ? t("kvkkYururlukte") : t("kvkkGecmisSurum")}
        </Rozet>
      ),
    },
    {
      id: "yeniden_onay_gerekir",
      baslik: t("kvkkYenidenOnay"),
      hucre: (m) => (m.yeniden_onay_gerekir ? t("ortakEvet") : t("ortakHayir")),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kvkkMetinlerBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("kvkkMetinlerAlt")}
        </p>
      </div>

      {hata ? <HataDurumu mesaj={hata} /> : null}

      {/* TESIS SECIMI ONCE GELIR: hangi tesise yayin yapildigi sayfanin en
          kritik bilgisidir ve yanlisi geri alinamaz (yayinlanan surum
          silinmez). Formdan SONRA sorulsaydi, kullanici metni yazip
          hedefi en son secerdi. */}
      <AlanSarmal etiket={t("kvkkTesisSec")} zorunlu>
        {(b) => (
          <Secim
            {...b}
            value={tesisId}
            onChange={(e) => setTesisId(e.target.value)}
          >
            <option value={BOS}>{t("kvkkTesisSecYer")}</option>
            {(tesisler?.items ?? []).map((x) => (
              <option key={x.id} value={x.id}>
                {x.ad}
              </option>
            ))}
          </Secim>
        )}
      </AlanSarmal>

      {tesisId === BOS ? (
        <BosDurum baslik={t("kvkkTesisSecYer")} aciklama={t("kvkkTesisSecAlt")} />
      ) : (
      <>
      <Sekmeler
        aktifId={tur}
        onDegis={(id) => setTur(id as Tur)}
        sekmeler={TURLER.map((x) => ({
          id: x,
          baslik: t(TUR_ETIKETI[x]),
          icerik: null,
        }))}
      />

      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("kvkkMetinSurumler")}
        </h2>
        {/* KAC KISI ONAYLADI: yayinlamanin tek olculebilir sonucu bu.
            KISI LISTESI YOK ve uc de dondurmuyor — yonetim isi icin
            gereksiz bir kisisel veri akisi olurdu. */}
        {onayOzeti && (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("kvkkOnaylayanSayisi", {
              n: String(onayOzeti.onaylayan),
              surum: String(onayOzeti.surum),
            })}
          </p>
        )}
        <VeriTablosu<Metin>
          kolonlar={kolonlar}
          satirlar={surumler}
          satirId={(m) => m.id}
          yukleniyor={!data && !error}
          hata={error ? t("yonKvkkHata") : null}
          onTekrar={() => void mutate()}
          bosBaslik={t("yonKvkkYok")}
          bosAciklama={t("yonKvkkYokAlt")}
        />
      </section>

      <Kart className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("kvkkMetinYeniSurum")}
        </h2>
        {/* DUZENLEME YOK, YENI SURUM VAR — ve bunun NEDENI ekranda yazili:
            kullanici "neden duzenleyemiyorum" diye sormamali. */}
        <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
          {t("kvkkSurumNotu")}
        </p>
        <AlanSarmal etiket={t("yonKvkkBaslik")} zorunlu>
          {(b) => <Alan {...b} value={baslik} onChange={(e) => setBaslik(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("yonKvkkGovde")} zorunlu>
          {() => (
            <ZenginMetin
              deger={govde}
              onDegisti={setGovde}
              etiket={t("yonKvkkGovde")}
            />
          )}
        </AlanSarmal>
        <label
          className="flex items-start gap-2"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
        >
          <input
            type="checkbox"
            checked={yenidenOnay}
            onChange={(e) => setYenidenOnay(e.target.checked)}
          />
          <span>
            {t("kvkkYenidenOnayIste")}
            <span
              className="block"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {t("kvkkYenidenOnayNotu")}
            </span>
          </span>
        </label>
        <Dugme tur="birincil" disabled={mesgul} onClick={() => void yayinla()}>
          {t("yonKvkkYayinla")}
        </Dugme>
      </Kart>
      </>
      )}


    </div>
  );
}
