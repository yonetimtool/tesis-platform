"use client";

/**
 * (P171 duzeltme) API'YE ULASILAMIYOR — MERKEZI DURUM EKRANI.
 *
 * =========================================================================
 * NEDEN VAR
 * =========================================================================
 * `admin-web` artik `api`nin sagligina BAGLI DEGIL: iki servisin
 * basarisizlik modu ayri olmali. API semasi uyumsuzsa kapali kalmasi
 * DOGRU (yanlis semaya yazmak veriyi bozar); ama admin-web veriye yazmaz,
 * API'yi cagirir — API yoksa kullanici BIR SAYFA gorup anlamli bir hata
 * almali, alan adi komple 502 vermemeli.
 *
 * Bu ayrilmanin bedeli: artik "API kapali" YAYGIN bir durum ve her
 * sayfanin onu kendi metniyle anlatmasi kabul edilemez. Onceden her
 * ekran kendi `HataDurumu`sunu ciziyor ve kullanici "bir hata olustu"
 * goruyordu — sunucunun KAPALI oldugunu degil, yani beklemenin ise
 * yarayacagini da bilmiyordu.
 *
 * =========================================================================
 * NEDEN SWR SEVIYESINDE, HER SAYFADA DEGIL
 * =========================================================================
 * Panelin butun okumalari `jsonFetcher` uzerinden ve SWR ile yapiliyor.
 * `SWRConfig.onError` TEK bir kanca noktasidir: yeni bir sayfa eklendiginde
 * hicbir sey yapmadan kapsama girer. Sayfa basina yazmak, bir gun birinin
 * unutacagi ve o ekranin sessizce ham hata gosterecegi anlamina gelirdi.
 *
 * METNE DEGIL KODA BAKILIR (`API_KAPALI_KODU`): metin yedi dilde degisir.
 *
 * =========================================================================
 * ICERIK DEGISTIRILIR, USTUNE BINILMEZ
 * =========================================================================
 * Ortu (overlay) yerine icerigin YERINE ciziliyor. Arkada yari gorunen
 * bos tablolar ve "0 kayit" yazilari, kullaniciya VERI YOK dedirtirdi;
 * oysa gercek "veri OKUNAMADI". Kabuk (menu, ust bar) YERINDE KALIR:
 * kullanici nerede oldugunu kaybetmemeli ve cikis yapabilmeli.
 *
 * TOPARLANMA OTOMATIK: SWR yeniden dogrulama basarili olur olmaz
 * (`onSuccess`) durum temizlenir — kullanici "tekrar dene"ye basmak
 * ZORUNDA degil, ama isterse hemen deneyebilir.
 */
import { useCallback, useState, type ReactNode } from "react";
import { SWRConfig, useSWRConfig } from "swr";

import { Dugme } from "@/components/ui";
import { API_KAPALI_KODU } from "@/lib/backend-kodlari";
import { useT } from "@/lib/i18n/kullan";

function apiKapaliMi(e: unknown): boolean {
  return (e as { kod?: string; code?: string } | null)?.kod === API_KAPALI_KODU
    // `ApiHatasi` (yazma yolu) alani `code` diye tasiyor; `jsonFetcher`
    // (okuma yolu) `kod`. Ikisi de ayni gercegi anlatiyor.
    || (e as { code?: string } | null)?.code === API_KAPALI_KODU;
}

export function SunucuDurumu({ children }: { children: ReactNode }) {
  const [kapali, setKapali] = useState(false);

  return (
    <SWRConfig
      value={{
        onError: (e) => {
          if (apiKapaliMi(e)) setKapali(true);
        },
        // BASARILI HER OKUMA DURUMU TEMIZLER: sunucu geri geldiginde
        // ekranin elle yenilenmesini beklemek, calisan bir sistemi
        // bozuk gostermek olurdu.
        onSuccess: () => setKapali(false),
      }}
    >
      {kapali ? <SunucuKapaliEkrani onTemizle={() => setKapali(false)} /> : children}
    </SWRConfig>
  );
}

function SunucuKapaliEkrani({ onTemizle }: { onTemizle: () => void }) {
  const t = useT();
  const { mutate } = useSWRConfig();
  const [deneniyor, setDeneniyor] = useState(false);

  const tekrarDene = useCallback(async () => {
    setDeneniyor(true);
    try {
      // TUM anahtarlari yeniden dogrula. Tek bir anahtari tazelemek,
      // sayfanin bir parcasini canlandirip gerisini olu birakirdi.
      await mutate(() => true);
      onTemizle();
    } finally {
      setDeneniyor(false);
    }
  }, [mutate, onTemizle]);

  return (
    <div
      className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-8 text-center"
      // CANLI BOLGE: durum kullanici bir sey yapmadan degisebilir
      // (sunucu geri gelince) ve ekran okuyucu bunu duymali.
      role="status"
      aria-live="polite"
    >
      <p style={{ fontSize: "var(--yz-fs-h2)", color: "var(--yz-text)" }}>
        {t("sunucuKapaliBaslik")}
      </p>
      <p
        className="max-w-prose"
        style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text-2)" }}
      >
        {t("sunucuKapaliAciklama")}
      </p>
      <Dugme tur="birincil" disabled={deneniyor} onClick={() => void tekrarDene()}>
        {deneniyor ? t("ortakYukleniyor") : t("ortakYenidenDene")}
      </Dugme>
    </div>
  );
}
