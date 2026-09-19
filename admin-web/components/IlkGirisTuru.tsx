"use client";

import { useCallback, useEffect, useState } from "react";
import useSWR, { mutate as globalMutate } from "swr";

import { Modal } from "@/components/Modal";
import { btnGhost, btnPrimary } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P243 §6d) ILK GIRIS TURU — 3-4 ekranlik kisa tanitim.
 *
 * =========================================================================
 * NEDEN VAR
 * =========================================================================
 * Brief: "Yoneticiye 3-4 ekranlik kisa tanitim. Atlanabilir, bir kez
 * gosterilir, sonradan tekrar acilabilir."
 *
 * Kurulum sihirbazi "NE YAPILACAGINI" soyluyordu ama "BU URUN NASIL
 * CALISIR"i hicbir yerde soylemiyordu. Olculen kusurun kaynagi buydu:
 * yeni yonetici 19 adimlik bir liste goruyor ve hangisinin gercekten
 * gerektigini bilmiyordu (bkz. §6a).
 *
 * =========================================================================
 * "BIR KEZ" NEREDE TUTULUR: HESAPTA, CIHAZDA DEGIL
 * =========================================================================
 * `localStorage` olsaydi ofiste turu atlayan yonetici evdeki
 * bilgisayarda onu YENIDEN gorurdu — "bir kez" sozu cihaz basina
 * tutulmus olurdu. Isaret `app_user.tur_goruldu_at` (goc 0148) ve
 * KULLANICI BASINA: ayni tesise sonradan eklenen ikinci yonetici turu
 * KENDI ilk girisinde gorur.
 *
 * ATLAMAK DA "GORDU"DUR: atlama ile sonuna kadar izleme ayni isareti
 * yazar. Aksi hâlde turu atlayan kisi her girisde ayni pencereyle
 * karsilasirdi — yani "atla" dugmesi calismiyor olurdu.
 *
 * =========================================================================
 * KIM GORUR
 * =========================================================================
 * YALNIZ YONETIM (`admin` / `yonetici`). Sakin ve saha personeli bu
 * yuzeyde zaten sayfa gormez (P129) ve tur kurulumu anlatiyor — sakine
 * "once bloklari girin" demek anlamsiz olurdu.
 */

/** Tur ekranlari — baslik + metin sozluk anahtari. */
const EKRANLAR: readonly { baslik: SozlukAnahtari; metin: SozlukAnahtari }[] = [
  { baslik: "tur1Baslik", metin: "tur1Metin" },
  { baslik: "tur2Baslik", metin: "tur2Metin" },
  { baslik: "tur3Baslik", metin: "tur3Metin" },
  { baslik: "tur4Baslik", metin: "tur4Metin" },
];

const PROFIL_UC = "/api/me";

interface Profil {
  role?: string;
  tur_goruldu_at?: string | null;
}

const YONETIM = ["admin", "yonetici"];

/** Turu elle acmak icin (kurulum sihirbazindaki "tekrar goster"). */
export function ilkGirisTurunuAc(): void {
  window.dispatchEvent(new CustomEvent(TUR_OLAYI));
}

const TUR_OLAYI = "yonetio:tur-ac";

export function IlkGirisTuru() {
  const t = useT();
  const { data } = useSWR<Profil>(PROFIL_UC, jsonFetcher);
  const [elleAcik, setElleAcik] = useState(false);
  const [kapatildi, setKapatildi] = useState(false);
  const [sira, setSira] = useState(0);

  // Elle acma olayi — kurulum sayfasindaki "tekrar goster" dugmesinden
  // gelir. OLAY, PROP DEGIL: dugme sihirbaz sayfasinda, tur kabukta;
  // aralarinda ortak bir ata bilesen yok ve bir baglam saglayicisi
  // kurmak tek bir dugme icin fazla olurdu (`kurulumHatirlaticiyiAc`
  // ayni deseni kullaniyor).
  const ac = useCallback(() => {
    setSira(0);
    setKapatildi(false);
    setElleAcik(true);
  }, []);
  useEffect(() => {
    window.addEventListener(TUR_OLAYI, ac);
    return () => window.removeEventListener(TUR_OLAYI, ac);
  }, [ac]);

  const yonetimMi = data?.role !== undefined && YONETIM.includes(data.role);
  // PROFIL GELMEDEN CIZILMEZ: rolu bilmeden acmak, sakine bir kare
  // boyunca yonetim turunu gostermek olurdu.
  const ilkKez = yonetimMi && data?.tur_goruldu_at == null;
  const acik = (elleAcik || ilkKez) && !kapatildi;

  async function bitir() {
    setKapatildi(true);
    setElleAcik(false);
    try {
      await apiSend(`${PROFIL_UC}/tur-goruldu`, "POST", {});
      await globalMutate(PROFIL_UC);
    } catch {
      // ISARET YAZILAMADIYSA SESSIZ KALINIR ve pencere yine kapanir.
      // Kullaniciyi bir ag hatasi yuzunden tanitim penceresinde tutmak,
      // hatanin kendisinden daha kotu olurdu; tur bir sonraki girisde
      // yeniden cikar (kabul edilen bedel).
    }
  }

  if (!acik) return null;
  const ekran = EKRANLAR[sira];
  const sonMu = sira === EKRANLAR.length - 1;

  return (
    <Modal baslik={t("turBaslik")} acik={acik} kapat={bitir} genislik="sm">
      <div className="space-y-3">
        <p className="tabular-nums" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
          {t("turSayac", { sira: sira + 1, toplam: EKRANLAR.length })}
        </p>
        <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t(ekran.baslik)}
        </h3>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t(ekran.metin)}
        </p>
        <div className="flex flex-wrap items-center justify-between gap-2 pt-2">
          {/* ATLA HER EKRANDA: yalniz ilk ekranda olsaydi, ikinci
              ekranda ilgisini kaybeden kisinin cikisi kalmazdi. */}
          <button type="button" className={btnGhost} onClick={bitir}>
            {t("turAtla")}
          </button>
          <div className="flex gap-2">
            {sira > 0 && (
              <button type="button" className={btnGhost} onClick={() => setSira(sira - 1)}>
                {t("turGeri")}
              </button>
            )}
            <button
              type="button"
              className={btnPrimary}
              onClick={() => (sonMu ? bitir() : setSira(sira + 1))}
            >
              {sonMu ? t("turBitir") : t("turIleri")}
            </button>
          </div>
        </div>
      </div>
    </Modal>
  );
}
