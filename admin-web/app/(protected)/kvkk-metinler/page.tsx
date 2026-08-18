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
 * (P168 §5) KVKK VE YASAL METINLER.
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

  const { data, error, mutate } = useSWR<Metin[]>(
    `/api/panel/kvkk-metinler?tur=${tur}`,
    jsonFetcher,
  );

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
      await apiSend("/api/panel/kvkk-metin", "POST", {
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
    { id: "surum", baslik: t("kvkkSurum"), sayisal: true, hucre: (m) => `v${m.surum}` },
    { id: "baslik", baslik: t("yonKvkkBaslik"), hucre: (m) => m.baslik },
    {
      id: "created_at",
      baslik: t("kvkkYayinTarihi"),
      hucre: (m) => formatDateTime(m.created_at),
    },
    {
      id: "yururlukte",
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
        <VeriTablosu<Metin>
          kolonlar={kolonlar}
          satirlar={data ?? []}
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

      {(data?.length ?? 0) === 0 && !error ? (
        <BosDurum baslik={t("yonKvkkYok")} aciklama={t("yonKvkkYokAlt")} />
      ) : null}
    </div>
  );
}
