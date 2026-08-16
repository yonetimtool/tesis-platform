"use client";

/**
 * (P166 §8.1) KURULUM SIHIRBAZI — ILK ACILISTA HATIRLATMA.
 *
 * =========================================================================
 * NEDEN GEREKLI
 * =========================================================================
 * Sihirbaz P154'ten beri `/kurulum`da duruyor ve calisiyor. Sorun onun
 * BULUNMASIYDI: yeni bir yonetici panele girince bos listeler goruyor ve
 * "nereden baslayacagini" menude bir satir arayarak bulmak zorunda
 * kaliyordu. Brief: "ilk acilista modal olarak ciksin ve kullaniciyi
 * sihirbaz ekranina yonlendirsin."
 *
 * =========================================================================
 * KENDI FORMUNU CIZMEZ — SIHIRBAZA GOTURUR
 * =========================================================================
 * Bu bir HATIRLATICIDIR, ikinci bir sihirbaz degil. Adimlarin listesi,
 * ilerleme ve atlama `/kurulum` sayfasinda; burada ikinci bir kopya
 * tutmak, biri degistiginde otekini unutmak olurdu. Gosterilen tek sey
 * SAYAC ("3/8") ve iki dugme.
 *
 * =========================================================================
 * KIME GORUNUR
 * =========================================================================
 * YALNIZ admin + yonetici. Uc (`/kurulum`) zaten oteki rollere 403
 * doner; istegi HIC ATMAMAK ise sakinin/gorevlinin her sayfa acilisinda
 * bosa bir 403 uretmesini engeller. Rol kapisi burada bir GORUNURLUK
 * karari degil, gereksiz istegi kesme karari — asil kapi sunucuda.
 *
 * =========================================================================
 * NE ZAMAN GORUNMEZ
 * =========================================================================
 *  * Kurulum BITTIYSE (gecilen === toplam). Biten bir isi hatirlatmak,
 *    modali "her acilista kapatilan bir sey"e cevirirdi.
 *  * Kullanici KAPATTIYSA. Karar tarayicida saklanir; sunucuda bir alan
 *    acmak, kullanici basina degil TESIS basina bir tercih uretirdi ve
 *    bir yonetici kapatinca oteki de gormezdi.
 *  * Kullanici ZATEN `/kurulum`daysa — orada olan birine "kuruluma git"
 *    demek gurultudur.
 *
 * TAMAMLANANLAR KALICI ISARETLI: sayac sunucudan geliyor ve sunucu onu
 * SAYIYOR, saklamiyor (bkz. `routers/kurulum.py`) — yani tarayici
 * temizlense de ilerleme kaybolmaz.
 */

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import useSWR from "swr";

import { Modal } from "@/components/Modal";
import { btnGhost, btnPrimary } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/** Kapatma tercihi — TEKNIK anahtar, marka adindan bagimsiz (bkz. §6). */
const KAPATILDI_ANAHTARI = "yonetio.kurulum.kapatildi";
const UC = "/api/panel/kurulum";
const KURULUM_ROTASI = "/kurulum";
/** Sihirbazi gorebilen roller — uctaki `require_role` ile AYNI kume. */
const YONETIM_ROLLERI = ["admin", "yonetici"];

interface Durum {
  toplam: number;
  gecilen: number;
}

/** Ayarlardan "tekrar goster" icin: kapatma kaydini siler. */
export function kurulumHatirlaticiyiAc(): void {
  try {
    localStorage.removeItem(KAPATILDI_ANAHTARI);
  } catch {
    // Erisilemez depolama bir sey KIRMAZ; hatirlatici zaten gorunur.
  }
}

export function KurulumHatirlatici({ rol }: { rol: string | null }) {
  const t = useT();
  const pathname = usePathname();
  const yetkili = rol !== null && YONETIM_ROLLERI.includes(rol);
  const { data } = useSWR<Durum>(yetkili ? UC : null, jsonFetcher);

  // `null` BASLAR ve etkide doldurulur: sunucu karesinde `localStorage`
  // yok. `false` ile baslasaydik sunucu modali cizer, istemci bir kare
  // sonra kaldirirdi — kullanici bir "sicrama" gorurdu.
  const [kapatildi, setKapatildi] = useState<boolean | null>(null);
  useEffect(() => {
    try {
      setKapatildi(localStorage.getItem(KAPATILDI_ANAHTARI) === "1");
    } catch {
      setKapatildi(false);
    }
  }, []);

  function kapat() {
    setKapatildi(true);
    try {
      localStorage.setItem(KAPATILDI_ANAHTARI, "1");
    } catch {
      // Yazilamazsa bu oturumda kapali kalir, kalici olmaz.
    }
  }

  const bitti = data ? data.gecilen >= data.toplam : true;
  const acik =
    yetkili &&
    kapatildi === false &&
    data !== undefined &&
    !bitti &&
    pathname !== KURULUM_ROTASI;

  return (
    <Modal
      baslik={t("kurulumHatirlaticiBaslik")}
      acik={acik}
      kapat={kapat}
      altBilgi={
        <>
          <button type="button" className={btnGhost} onClick={kapat}>
            {t("kurulumHatirlaticiSonra")}
          </button>
          {/* BAGLANTI, DUGME DEGIL: hedef bir SAYFA ve orta tikla yeni
              sekmede acilabilmeli. Tiklayinca modal da kapanir — aksi
              hâlde kullanici sihirbaza gidip ustunde modal bulurdu. */}
          <Link href={KURULUM_ROTASI} className={btnPrimary} onClick={kapat}>
            {t("kurulumHatirlaticiGit")}
          </Link>
        </>
      }
    >
      <div className="space-y-2">
        <p style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
          {t("kurulumHatirlaticiMetin")}
        </p>
        {data && (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("kurulumSayac", { gecilen: data.gecilen, toplam: data.toplam })}
          </p>
        )}
      </div>
    </Modal>
  );
}
