"use client";

/**
 * (P252 §3) PERSONEL DETAYI — Kisiler › Personel satirindan ya da kasa
 * hareketindeki maas satirindan acilir.
 *
 *   * calisma bilgileri (maas karti — Finans › Maas kartlari ile AYNI
 *     kayit; buradan da duzenlenir),
 *   * odeme gecmisi: donem, tutar, kasa, maas / fazla mesai, durum,
 *   * bu ay: vardiya sayisi ve saati, devriye turu,
 *   * bu yil odenen.
 *
 * Adres `?kisi=<hesap>` ya da `?kart=<maas karti>` (hesapsiz personel).
 * YALNIZ yonetim: rota kapisi (`ROTA_ROLLERI`) ve sunucu (amire 403).
 */
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import useSWR from "swr";

import { CalismaBilgileriPenceresi } from "@/components/kisiler/calisma-bilgileri";
import { Dugme, HataDurumu, Kart, Rozet, SayfaBasligi, VeriTablosu, type Kolon } from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useI18n } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { kurusToTL } from "@/lib/money";
import type { OdemeTuru, PersonelDetay } from "@/lib/personel";
import { rolAdi } from "@/lib/roles";
import { saltTarihBicimi } from "@/lib/tarih";
import type { UserRole } from "@/lib/types";

const YOK = "—";
const TUR_ANAHTARI: Record<OdemeTuru, SozlukAnahtari> = {
  maas: "pdTurMaas",
  mesai: "pdTurMesai",
  diger: "pdTurDiger",
};
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  odendi: "finansDurumOdendi",
  bekliyor: "finansDurumBekliyor",
  onay_bekliyor: "finansDurumOnayBekliyor",
  iptal: "finansDurumReddedildi",
};
const DURUM_YEDEK: SozlukAnahtari = "finansDurumBekliyor";

type Odeme = PersonelDetay["odemeler"][number];

function Satir({ etiket, deger }: { etiket: string; deger: string }) {
  return (
    <div className="flex justify-between gap-4 py-1" style={{ fontSize: "var(--yz-fs-sm)" }}>
      <dt style={{ color: "var(--yz-text-2)" }}>{etiket}</dt>
      <dd className="text-end font-medium" style={{ color: "var(--yz-text)" }}>{deger}</dd>
    </div>
  );
}

export default function PersonelDetayPage() {
  const { t, dil } = useI18n();
  const sp = useSearchParams();
  const kisi = sp?.get("kisi") ?? null;
  const kart = sp?.get("kart") ?? null;
  const qs = kisi ? `user_id=${kisi}` : kart ? `kart_id=${kart}` : null;
  const { data, error, mutate } = useSWR<PersonelDetay>(
    qs ? `/api/personel/detay?${qs}` : null,
    jsonFetcher,
  );
  const [duzenle, setDuzenle] = useState(false);
  const tarih = (iso: string | null) => (iso ? saltTarihBicimi(iso, dil) : YOK);

  const kolonlar: Kolon<Odeme>[] = [
    { id: "donem", baslik: t("ortakDonem"), hucre: (o) => o.donem ?? YOK },
    { id: "tarih", baslik: t("finansSutunTarih"), hucre: (o) => tarih(o.tarih) },
    { id: "tur", baslik: t("finansSutunTur"), hucre: (o) => t(TUR_ANAHTARI[o.tur] ?? TUR_ANAHTARI.diger) },
    { id: "kasa", baslik: t("finansSutunKasa"), hucre: (o) => o.kasa_ad ?? YOK },
    { id: "durum", baslik: t("finansSutunDurum"),
      hucre: (o) => <Rozet>{t(DURUM_ANAHTARI[o.durum] ?? DURUM_YEDEK)}</Rozet> },
    { id: "tutar", baslik: t("finansSutunTutar"), sayisal: true,
      hucre: (o) => <span className="tabular-nums">{kurusToTL(o.tutar_kurus)}</span> },
  ];

  if (!qs || error) {
    return (
      <div className="space-y-4">
        <SayfaBasligi baslik={t("pdBulunamadi")} />
        <HataDurumu mesaj={error ? error.message : t("pdBulunamadi")} />
      </div>
    );
  }

  const c = data?.calisma ?? null;
  return (
    <div className="space-y-4" data-test="personel-detay">
      <SayfaBasligi
        baslik={data?.ad ?? t("ortakYukleniyor")}
        aciklama={data?.rol ? rolAdi(t, data.rol as UserRole) : undefined}
        ustBilgi={
          <Link href="/kisiler?sekme=personel" className="underline" style={{ fontSize: "var(--yz-fs-sm)" }}>
            {t("pdGeri")}
          </Link>
        }
        eylem={
          data?.user_id ? (
            <Dugme onClick={() => setDuzenle(true)} data-test="pd-duzenle">{t("calismaDugme")}</Dugme>
          ) : data?.kart_id ? (
            <Link href={`/finans/maas-kartlari?kart=${data.kart_id}`} className="underline">
              {t("calismaDugme")}
            </Link>
          ) : null
        }
      />
      {data ? (
        <div className="grid gap-4 lg:grid-cols-3">
          <Kart>
            <h2 className="mb-2" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("calismaBaslik")}
            </h2>
            {c ? (
              <dl data-test="pd-calisma">
                <Satir etiket={t("calismaGorev")} deger={c.gorev ?? YOK} />
                <Satir etiket={t("calismaGiris")} deger={tarih(c.giris_tarihi)} />
                {c.cikis_tarihi ? <Satir etiket={t("pdCikis")} deger={tarih(c.cikis_tarihi)} /> : null}
                <Satir etiket={t("calismaUcret")} deger={c.maas_kurus != null ? kurusToTL(c.maas_kurus) : YOK} />
                <Satir
                  etiket={t("calismaOdemeGunu")}
                  deger={c.odeme_gunu != null ? t("pdOdemeGunu", { gun: c.odeme_gunu }) : YOK}
                />
                <Satir etiket={t("calismaKasa")} deger={c.kasa_ad ?? t("calismaKasaVarsayilan")} />
                {c.iban ? <Satir etiket={t("calismaIban")} deger={c.iban} /> : null}
                {c.notlar ? <Satir etiket={t("calismaNot")} deger={c.notlar} /> : null}
              </dl>
            ) : (
              <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("pdKartYok")}</p>
            )}
          </Kart>
          <Kart>
            <h2 className="mb-2" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("pdBuAy")}
            </h2>
            <p data-test="pd-vardiya" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
              {t("pdVardiya", { adet: data.bu_ay.vardiya_sayisi, saat: data.bu_ay.vardiya_saat })}
            </p>
            <p data-test="pd-devriye" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
              {t("pdDevriye", { tur: data.bu_ay.devriye_tur, okutma: data.bu_ay.okutma_sayisi })}
            </p>
          </Kart>
          <Kart>
            <h2 className="mb-2" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("pdYilOdenen")}
            </h2>
            <p data-test="pd-yil" className="tabular-nums"
              style={{ fontSize: "var(--yz-fs-h2)", fontWeight: 700, color: "var(--yz-text)" }}>
              {kurusToTL(data.yil_odenen_kurus)}
            </p>
          </Kart>
        </div>
      ) : null}
      <Kart>
        <h2 className="mb-2" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("pdOdemeGecmisi")}
        </h2>
        <VeriTablosu
          kolonlar={kolonlar}
          satirlar={data?.odemeler ?? []}
          satirId={(o) => o.id}
          yukleniyor={!data}
          bosBaslik={t("pdOdemeYok")}
        />
      </Kart>
      {duzenle && data?.user_id ? (
        <CalismaBilgileriPenceresi
          kullanici={{ id: data.user_id, ad: data.ad, email: "", role: (data.rol ?? "security") as UserRole }}
          acik={duzenle}
          onKapat={() => {
            setDuzenle(false);
            void mutate();
          }}
        />
      ) : null}
    </div>
  );
}
