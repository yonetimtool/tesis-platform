"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  AramaAlani,
  FiltreCubugu,
  HataDurumu,
  OzetKarti,
  OzetSeridi,
  SayfaBasligi,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * P41 — YETKI MATRISI gorunumu.
 *
 * SAYFA HICBIR YETKI BILGISI TASIMAZ: satirlar da sutunlar da sunucudan
 * gelir. Panelde bir kopya tutmak, bir uc `require_role`unu degistirdiginde
 * burasinin YANLIS bir tablo gostermesi demekti — ve "kim neye erisiyor"
 * sorusunda yanlis yanit, yanit vermemekten daha kotudur.
 *
 * `roller: null` ROZETI AYRIDIR: "rol kapisi yok" ile "herkese acik" AYNI
 * SEY DEGILDIR (kimlik dogrulamasi yine gerekebilir); ikisini ayni gostermek
 * kimliksiz erisilebilir bir uc varmis gibi gosterirdi.
 */

interface Satir {
  metot: string;
  yol: string;
  roller: string[] | null;
  moda_bagli: boolean;
}
interface Matris {
  roller: string[];
  items: Satir[];
}

const IKON_YOL = "M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01";
const IKON_KISI = "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4 21a8 8 0 0 1 16 0";
const IKON_KILIT = "M7 11V8a5 5 0 0 1 10 0v3M5 11h14v10H5z";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

export default function YetkiPage() {
  const t = useT();
  const { data, error } = useSWR<Matris>("/api/panel/yetki-matrisi", jsonFetcher);
  const [ara, setAra] = useState("");

  const satirlar = (data?.items ?? []).filter(
    (s) => !ara || s.yol.toLowerCase().includes(ara.toLowerCase()),
  );

  // Kolonlar SUNUCUDAN gelen rol listesine gore kurulur: panelde sabit
  // bir rol dizisi tutmak, sunucuya rol eklendiginde matrisin EKSIK
  // gorunmesi demekti.
  const kolonlar: Kolon<Satir>[] = useMemo(() => {
    const temel: Kolon<Satir>[] = [
      {
        id: "metot",
        baslik: t("yetkiMetot"),
        gizlenebilir: false,
        deger: (s) => s.metot,
        hucre: (s) => <span className="font-mono">{s.metot}</span>,
      },
      {
        id: "yol",
        baslik: t("yetkiYol"),
        gizlenebilir: false,
        deger: (s) => s.yol,
        hucre: (s) => (
          <span className="font-mono">
            {s.yol}
            {s.moda_bagli ? (
              <span
                className="ms-1"
                style={{ color: "var(--yz-warning-ink)" }}
                title={t("yetkiModaBagliIpucu")}
              >
                {t("yetkiModaBagli")}
              </span>
            ) : null}
          </span>
        ),
      },
    ];
    for (const r of data?.roller ?? []) {
      temel.push({
        id: r,
        // Rol adlari SOZLUKTEN: sunucu wire degerini doner, panel onu
        // kullanicinin dilinde cizer.
        baslik: t(`rol_${r}` as never),
        hucre: (s) =>
          s.roller === null ? (
            // "rol kapisi yok" ile "herkese acik" AYNI SEY DEGILDIR.
            <span style={{ color: "var(--yz-text-3)" }} title={t("yetkiKapisizIpucu")}>
              {t("yetkiKapisiz")}
            </span>
          ) : s.roller.includes(r) ? (
            <span style={{ color: "var(--yz-success-ink)" }}>{t("yetkiIzin")}</span>
          ) : (
            <span style={{ color: "var(--yz-text-3)" }}>{t("yetkiRed")}</span>
          ),
      });
    }
    return temel;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [t, data]);

  return (
    <div>
      <SayfaBasligi baslik={t("yetkiBaslik")} aciklama={t("yetkiAlt")} />

      {/* (P244 §9) SAYILAR SUNUCUDAN GELEN MATRISTEN TURETILIR.
          Matris sayfali DEGIL — sunucu tum uclari tek yanitta veriyor
          (yetki sorusu ancak boyle yanitlanir). Elimizdeki dizi
          listenin tamami oldugu icin istemci sayimi DOGRUDUR; ayrica
          "rol kapisi olmayan uc kac tane" sorusunun yanitini baska
          hicbir yerden okuyamazdik. */}
      <OzetSeridi>
        <OzetKarti
          etiket={t("yetkiOzetUc")}
          deger={String(data?.items?.length ?? 0)}
          ikon={<Ikon yol={IKON_YOL} />}
          durum="notr"
        />
        <OzetKarti
          etiket={t("yetkiOzetRol")}
          deger={String(data?.roller?.length ?? 0)}
          ikon={<Ikon yol={IKON_KISI} />}
          durum="bilgi"
        />
        <OzetKarti
          etiket={t("yetkiOzetKapisiz")}
          deger={String((data?.items ?? []).filter((x) => x.roller === null).length)}
          ikon={<Ikon yol={IKON_KILIT} />}
          durum="uyari"
          altBilgi={t("yetkiOzetKapisizAlt")}
        />
      </OzetSeridi>

      {error && <HataDurumu mesaj={t("yetkiHata")} />}

      <FiltreCubugu
        arama={
          /* (P63) Yer tutucu tek basina erisilebilir AD saglamaz. */
          <AramaAlani
            etiket={t("yetkiAra")}
            yerTutucu={t("yetkiAra")}
            temizleEtiketi={t("ortakKapat")}
            deger={ara}
            onDegisim={setAra}
          />
        }
        aktifSayi={ara.trim() ? 1 : 0}
        onTemizle={() => setAra("")}
      />

      <p className="mb-3" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {t("yetkiNotu")}
      </p>

      <VeriTablosu<Satir>
        kolonlar={kolonlar}
        satirlar={satirlar}
        satirId={(s) => `${s.metot} ${s.yol}`}
        yukleniyor={!data && !error}
        // MATRIS YOGUN OKUNUR: yuzlerce uc ve rol basina bir sutun var;
        // ekrana cok satir sigmasi, satir yuksekliginden daha degerli.
        yogunluk="sik"
        yapiskanBaslik
      />
    </div>
  );
}
