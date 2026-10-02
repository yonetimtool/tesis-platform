"use client";

/**
 * (P251 §10) GONDERIM GUNLUGU — PLATFORM PANELI.
 *
 * E-posta, SMS ve uygulama bildirimi (push) teslim sonuclari, TUM
 * tesislerde. Saglayicinin ham hata ayrintisi (535, 5.7.8, gecersiz jeton)
 * YALNIZ burada gorunur: tesis yoneticisinin bildirim ve mesaj
 * ekranlarindaki teknik gunlukler buraya tasindi; yonetici kendi
 * ekraninda baglam icindeki sade durumu gorur (odeme kodu satirinda
 * "Iletildi / Ulasmadi").
 *
 * Push saglayici durumu ve "kendime test gonder" (P191 §2) bu sayfanin
 * altinda — eskiden tesis yoneticisinin bildirim sayfasinin ustundeydi.
 */
import { useEffect, useState } from "react";
import useSWR from "swr";

import { PushTeshis } from "@/components/PushTeshis";
import {
  Alan,
  AlanSarmal,
  Dugme,
  FiltreCubugu,
  HataDurumu,
  IskeletMetin,
  Kart,
  Rozet,
  SayfaBasligi,
  Secim,
  Tablo,
  TabloBasligi,
  Td,
  Th,
  Tr,
  type RozetDurumu,
} from "@/components/ui";
import { pushKimlikAdi } from "@/lib/enum-adlari";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { SINIR } from "@/lib/girdi-siniri";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type Satir = {
  id: string;
  kanal: string;
  tenant_id: string | null;
  tesis_ad: string | null;
  alici_ad: string | null;
  hedef: string | null;
  amac: string | null;
  durum: string;
  hata: string | null;
  saglayici: string | null;
  created_at: string;
};
type Liste = { meta: { total: number }; items: Satir[] };

const SAYFA = 50;
const HEPSI = "";
const KANALLAR = ["eposta", "sms", "push"] as const;
const KANAL_ETIKET: Record<string, SozlukAnahtari> = {
  eposta: "mesajKanal_eposta",
  sms: "mesajKanal_sms",
  push: "gunlukKanalPush",
};
/** Durumlar: e-posta/SMS (`mesaj_durum`) + push (`push_gonderim.durum`). */
const DURUMLAR: readonly (readonly [string, SozlukAnahtari, RozetDurumu])[] = [
  ["kuyrukta", "mesajDurum_kuyrukta", "notr"],
  ["gonderildi", "mesajDurum_gonderildi", "bilgi"],
  ["iletildi", "mesajDurum_iletildi", "olumlu"],
  ["okundu", "mesajDurum_okundu", "olumlu"],
  ["basarisiz", "mesajDurum_basarisiz", "kritik"],
  ["yapilandirilmadi", "mesajDurum_yapilandirilmadi", "uyari"],
  ["gecersiz_token", "pushDurumGecersizToken", "uyari"],
  ["noop", "pushDurumNoop", "uyari"],
  ["hedef_yok", "pushDurumHedefYok", "uyari"],
];
const AMAC: Record<string, SozlukAnahtari> = {
  odeme_kodu: "gunlukAmac_odeme_kodu",
  hosgeldin: "gunlukAmac_hosgeldin",
  aidat_hatirlatma: "gunlukAmac_aidat_hatirlatma",
  operasyonel: "gunlukAmac_operasyonel",
  pazarlama: "gunlukAmac_pazarlama",
};
const ROZET_YEDEK: RozetDurumu = "notr";
const KANAL_YEDEK: SozlukAnahtari = "gunlukKanalPush";

export default function GonderimGunluguPage() {
  const t = useT();
  const [ara, setAra] = useState("");
  const [gecikmeli, setGecikmeli] = useState("");
  const [kanal, setKanal] = useState<string>(HEPSI);
  const [durum, setDurum] = useState<string>(HEPSI);
  const [basarisiz, setBasarisiz] = useState(false);
  const [bas, setBas] = useState("");
  const [bit, setBit] = useState("");
  const [boy, setBoy] = useState(SAYFA);

  useEffect(() => {
    const z = setTimeout(() => setGecikmeli(ara.trim()), 300);
    return () => clearTimeout(z);
  }, [ara]);
  // Suzgec degisince ilk sayfaya don.
  useEffect(() => setBoy(SAYFA), [gecikmeli, kanal, durum, basarisiz, bas, bit]);

  const q = new URLSearchParams({ limit: String(boy), offset: "0" });
  if (gecikmeli) q.set("ara", gecikmeli);
  if (kanal) q.set("kanal", kanal);
  if (durum) q.set("durum", durum);
  if (basarisiz) q.set("basarisiz", "true");
  if (bas) q.set("from", new Date(`${bas}T00:00:00`).toISOString());
  if (bit) q.set("to", new Date(`${bit}T23:59:59`).toISOString());
  const { data, error, isLoading } = useSWR<Liste>(
    `/api/platform/gonderim-gunlugu?${q}`,
    jsonFetcher,
  );
  const satirlar = data?.items ?? [];
  const toplam = data?.meta.total ?? 0;
  const aktif = [gecikmeli, kanal, durum, basarisiz ? "1" : "", bas, bit].filter(Boolean).length;

  function amacAdi(s: Satir): string {
    if (!s.amac) return "—";
    const a = AMAC[s.amac];
    if (a) return t(a);
    // Push satirinda amac bildirim tipidir (panik kategorisi dahil).
    return pushKimlikAdi(t, s.amac);
  }

  return (
    <div className="space-y-4">
      <SayfaBasligi baslik={t("gunlukBaslik")} aciklama={t("gunlukAlt")} />

      <FiltreCubugu
        aktifSayi={aktif}
        onTemizle={() => {
          setAra(""); setKanal(HEPSI); setDurum(HEPSI);
          setBasarisiz(false); setBas(""); setBit("");
        }}
      >
        <Alan
          type="search"
          maxLength={SINIR.ARAMA}
          aria-label={t("gunlukAra")}
          placeholder={t("gunlukAra")}
          value={ara}
          data-test="gunluk-ara"
          onChange={(e) => setAra(e.target.value)}
        />
        <Secim aria-label={t("gunlukKanal")} value={kanal} data-test="gunluk-kanal"
          onChange={(e) => setKanal(e.target.value)}>
          <option value={HEPSI}>{t("gunlukKanalHepsi")}</option>
          {KANALLAR.map((k) => <option key={k} value={k}>{t(KANAL_ETIKET[k])}</option>)}
        </Secim>
        <Secim aria-label={t("gunlukDurum")} value={durum} data-test="gunluk-durum"
          onChange={(e) => setDurum(e.target.value)}>
          <option value={HEPSI}>{t("gunlukDurumHepsi")}</option>
          {DURUMLAR.map(([k, a]) => <option key={k} value={k}>{t(a)}</option>)}
        </Secim>
        <label className="flex items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
          <input type="checkbox" checked={basarisiz} data-test="gunluk-basarisiz"
            onChange={(e) => setBasarisiz(e.target.checked)} />
          {t("gunlukYalnizBasarisiz")}
        </label>
        <AlanSarmal etiket={t("gunlukBaslangic")}>
          {(b) => <Alan {...b} type="date" value={bas} onChange={(e) => setBas(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("gunlukBitis")}>
          {(b) => <Alan {...b} type="date" value={bit} onChange={(e) => setBit(e.target.value)} />}
        </AlanSarmal>
      </FiltreCubugu>

      <HataDurumu mesaj={error ? t("ortakHataOlustu") : null} />
      <Kart>
        <p className="mb-2" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("gunlukToplam", { n: toplam })}
        </p>
        {isLoading && !data ? (
          <IskeletMetin satir={5} />
        ) : satirlar.length === 0 ? (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("gunlukBos")}</p>
        ) : (
          <div className="overflow-x-auto">
            <Tablo>
              <TabloBasligi>
                <Th>{t("ortakTarih")}</Th>
                <Th>{t("gunlukKanal")}</Th>
                <Th>{t("gunlukTesis")}</Th>
                <Th>{t("gunlukAlici")}</Th>
                <Th>{t("gunlukAmac")}</Th>
                <Th>{t("gunlukDurum")}</Th>
                <Th>{t("gunlukHata")}</Th>
              </TabloBasligi>
              <tbody>
                {satirlar.map((s) => {
                  const d = DURUMLAR.find(([k]) => k === s.durum);
                  return (
                    <Tr key={`${s.kanal}-${s.id}`} data-test={`gunluk-satir-${s.id}`}>
                      <Td className="whitespace-nowrap">{formatDateTime(s.created_at)}</Td>
                      <Td>{t(KANAL_ETIKET[s.kanal] ?? KANAL_YEDEK)}</Td>
                      <Td>{s.tesis_ad ?? "—"}</Td>
                      <Td>
                        <span className="block">{s.alici_ad ?? "—"}</span>
                        <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                          {s.hedef ?? ""}
                        </span>
                      </Td>
                      <Td>{amacAdi(s)}</Td>
                      <Td>
                        <Rozet durum={d?.[2] ?? ROZET_YEDEK}>{d ? t(d[1]) : s.durum}</Rozet>
                      </Td>
                      <Td>
                        {/* HAM AYRINTI — yalniz platformda (kirpilmaz). */}
                        <span className="break-all font-mono" data-test={`gunluk-hata-${s.id}`}
                          style={{ fontSize: "var(--yz-fs-xs)" }}>
                          {s.hata ?? "—"}
                        </span>
                      </Td>
                    </Tr>
                  );
                })}
              </tbody>
            </Tablo>
          </div>
        )}
        {satirlar.length < toplam ? (
          <div className="mt-3">
            <Dugme boy="kucuk" onClick={() => setBoy((b) => b + SAYFA)}>
              {t("gunlukDahaFazla")}
            </Dugme>
          </div>
        ) : null}
      </Kart>

      <section className="space-y-2">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("gunlukPushBaslik")}
        </h2>
        <PushTeshis />
      </section>
    </div>
  );
}
