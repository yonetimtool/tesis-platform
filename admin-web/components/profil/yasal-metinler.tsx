"use client";

/**
 * (P170 §2) YASAL METINLER — OKUMA YUZEYI.
 *
 * =========================================================================
 * NE TASINDI, NE KALDI
 * =========================================================================
 * Metinlerin YONETIMI (olusturma, surumleme) `panel.*` altina tasindi ve
 * yalniz platform yoneticisine acik. OKUMA tasinmadi ve tasinmamaliydi:
 * bir kullanicinin kendisi hakkindaki aydinlatma metnini okuyamamasi,
 * aydinlatmanin kendisini imkansiz kilardi. KVKK'nin istedigi sey de tam
 * olarak bu erisimdir.
 *
 * BU EKRAN HER ROLE ACIK: sakin, yonetici, personel, denetci. Rol suzgeci
 * YOK — cunku gosterilen sey kullanicinin KENDI verisidir.
 *
 * =========================================================================
 * ONAY GECMISI: "HANGI SURUMU NE ZAMAN ONAYLADIM"
 * =========================================================================
 * Yalniz "onayladim" demek yetmez; onay BIR SURUME verilir ve o surum
 * degismis olabilir. Gecmis satiri hem tarihi hem surumu tasir ve surum
 * artik yururlukte degilse bunu ACIKCA soyler — aksi halde kullanici
 * okumadigi bir metni onaylamis sanirdi.
 *
 * (P171) METIN GOVDESI ZENGIN METIN OLARAK CIZILIR. Guvenligi SUNUCU
 * saglar: govde yazma aninda beyaz listeyle temizlenir
 * (`backend/app/temizleme.py`). Ayrintili gerekce cizim yerinde.
 */
import { useState } from "react";
import useSWR from "swr";

import {
  BosDurum,
  IskeletMetin,
  Kart,
  Rozet,
  Sekmeler,
} from "@/components/ui";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

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

interface Metin {
  id: string;
  tur: string;
  surum: number;
  baslik: string;
  govde: string;
  created_at: string;
}

interface Onay {
  tur: string;
  surum: number;
  onay_at: string;
  guncel_mi: boolean;
}

const ROZET_OLUMLU = "olumlu" as const;
const ROZET_UYARI = "uyari" as const;

export function YasalMetinler() {
  const t = useT();
  const [tur, setTur] = useState<Tur>("aydinlatma");

  const { data, error, isLoading } = useSWR<Metin>(
    `/api/kvkk/metin?tur=${tur}`,
    jsonFetcher,
    // 404 = "tesis bu metni henuz yayinlamadi" ve BU BIR HATA DEGIL, bir
    // DURUM. Yeniden denemek ayni yaniti getirirdi.
    { shouldRetryOnError: false },
  );
  const { data: onaylar } = useSWR<Onay[]>("/api/kvkk/onaylarim", jsonFetcher);

  const buTur = (onaylar ?? []).filter((o) => o.tur === tur);

  return (
    <div className="space-y-4">
      <div>
        <h2 style={{ fontSize: "var(--yz-fs-h2)", color: "var(--yz-text)" }}>
          {t("profilYasalMetinler")}
        </h2>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("profilYasalAlt")}
        </p>
      </div>

      <Sekmeler
        aktifId={tur}
        onDegis={(id) => setTur(id as Tur)}
        sekmeler={TURLER.map((x) => ({
          id: x,
          baslik: t(TUR_ETIKETI[x]),
          icerik: null,
        }))}
      />

      {isLoading ? (
        <IskeletMetin satir={6} />
      ) : error ? (
        // METIN YOKSA "HATA" DEMEK YANLIS: tesis o metni henuz
        // yayinlamamis olabilir ve kullanicinin yapacagi bir sey yok.
        <BosDurum baslik={t("profilYasalYok")} aciklama={t("profilYasalYokAlt")} />
      ) : data ? (
        <Kart className="space-y-3 p-kart">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {data.baslik}
            </h3>
            <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
              {t("kvkkSurum")} v{data.surum} · {formatDateTime(data.created_at)}
            </span>
          </div>
          {/* (P171) ZENGIN METIN GERI GELDI — CUNKU SUNUCU TEMIZLIYOR.
              =====================================================
              P170'te bu govde duz metne cevriliyordu. Guvenliydi ama
              bedeli agirdi: KVKK metinleri BASLIKLI VE MADDELI
              belgelerdir ve duz metin okunabilirligi dusuruyordu.

              Bugun kosul saglandi: govde YAZMA ANINDA sunucuda beyaz
              listeyle temizleniyor (`backend/app/temizleme.py`, `nh3`) —
              `on*`, `style`, `script`, `iframe`, `svg`, `img` ve
              `javascript:`/`data:` semalari saklanmadan atiliyor. Mevcut
              satirlar da onarim gocuyle temizlendi (0066), yani "dunden
              kalan kirli satir" diye bir sey YOK.

              NEDEN ISTEMCIDE IKINCI BIR TEMIZLIK YOK: temizlik ISTEMCI
              KARARI OLSAYDI her istemci (web, mobil, e-posta, rapor) onu
              ayri ayri dogru yapmak zorunda kalirdi ve birinin atlamasi
              sessiz bir acik olurdu. Tek dogru yer, verinin GIRDIGI yer.
              Istemcideki bir temizleyici burada yalniz ayni isi ikinci
              kez yapar ve "asil koruma nerede" sorusunu bulaniklastirirdi.

              SUNUCU KANITLANDI: `backend/tests/test_temizleme.py` hem
              vektorlerin atildigini hem MESRU BICIMLENDIRMENIN korundugunu
              olcuyor; sema tipi (`ZenginHtml`) envanterle kilitli, yani
              yeni bir zengin metin alani temizlik olmadan eklenemiyor. */}
          <div
            className="yz-yasal-govde"
            style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
            dangerouslySetInnerHTML={{ __html: data.govde }}
          />
        </Kart>
      ) : null}

      <section className="space-y-2">
        <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("profilOnayGecmisi")}
        </h3>
        {buTur.length === 0 ? (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("profilOnayYok")}
          </p>
        ) : (
          <ul className="space-y-1">
            {buTur.map((o) => (
              <li
                key={`${o.tur}-${o.surum}`}
                className="flex flex-wrap items-center justify-between gap-2 border-b py-2 last:border-b-0"
                style={{ borderColor: "var(--yz-border)" }}
              >
                <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                  {t("kvkkSurum")} v{o.surum} · {formatDateTime(o.onay_at)}
                </span>
                {/* GUNCEL OLMAYAN ONAY ACIKCA SOYLENIR: sessiz birakmak,
                    kullaniciya okumadigi bir metni onaylamis gibi
                    gosterirdi. */}
                <Rozet durum={o.guncel_mi ? ROZET_OLUMLU : ROZET_UYARI}>
                  {o.guncel_mi ? t("kvkkYururlukte") : t("profilOnayEskimis")}
                </Rozet>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
