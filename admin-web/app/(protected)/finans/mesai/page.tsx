"use client";

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Kart, Rozet, Secim } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL } from "@/lib/money";

/**
 * (P203 §5) FAZLA MESAI — aylik personel gideri.
 *
 * =========================================================================
 * TEK DEFTER (P192) BOZULMADI
 * =========================================================================
 * "Gidere yaz" bir MESAI TABLOSUNA yazmaz: `finansal_hareket`e
 * `tip='gider'` olarak duser. Ekran bunu kullaniciya da soyler —
 * yoneticinin "bu para nereye gitti" sorusunu Finans ekraninda
 * yanitlayabilmesi gerekiyor.
 *
 * =========================================================================
 * OTOMATIK YAZMA YOK
 * =========================================================================
 * Hareket ONAY BEKLEYEN olarak yazilir ve bakiyeyi DUSURMEZ. Ekran bunu
 * dugmenin yaninda ACIKCA yazar: yonetici "yazdim, bitti" sanip onay
 * adimini atlarsa gider hic gerceklesmez.
 */

type Kisi = {
  user_id: string;
  ad: string;
  toplam_saat: number;
  fazla_saat: number;
  saatlik_ucret_kurus: number | null;
  fazla_mesai_kurus: number | null;
  ucret_tanimsiz: boolean;
  gidere_yazildi: boolean;
};
type Ozet = { yil: number; ay: number; katsayi: number; kaynak: string; kisiler: Kisi[] };

const AYLAR = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

export default function MesaiSayfasi() {
  const t = useT();
  const toast = useToast();
  const simdi = new Date();
  const [yil, setYil] = useState(simdi.getFullYear());
  const [ay, setAy] = useState(simdi.getMonth() + 1);
  const [bekliyor, setBekliyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  // (P211 §5) KATSAYI ARTIK EKRANDAN DEGISTIRILEBILIR.
  //
  // P203 sutunu acmis ve belgesine "degistirilebilir" yazmisti; ama
  // hicbir uc onu yazmiyordu — yani soz ancak SQL ile tutuluyordu.
  // Yetki SUNUCUDA: denetci okur, yazamaz (sayi dogrudan paraya
  // cevriliyor). Buradaki alanin varligi bir yetki karari DEGILDIR.
  const [katsayiDuzenle, setKatsayiDuzenle] = useState(false);
  const [katsayiMetin, setKatsayiMetin] = useState("");

  const uc = `/api/mesai/ozet?yil=${yil}&ay=${ay}`;
  const { data, error, mutate } = useSWR<Ozet>(uc, jsonFetcher);

  const yazilabilir = (data?.kisiler ?? []).filter(
    (k) => k.fazla_saat > 0 && !k.ucret_tanimsiz && !k.gidere_yazildi,
  );
  const toplam = yazilabilir.reduce((n, k) => n + (k.fazla_mesai_kurus ?? 0), 0);

  async function katsayiKaydet() {
    const n = Number(katsayiMetin.replace(",", "."));
    if (!Number.isFinite(n)) return;
    setBekliyor(true);
    setHata(null);
    try {
      await apiSend("/api/mesai/ayar", "PATCH", { katsayi: n });
      toast.success(t("mesaiKatsayiKaydedildi"));
      setKatsayiDuzenle(false);
      // OZET YENIDEN CEKILIR: katsayi tutarlari degistirir; eski sayiyi
      // ekranda birakmak, yoneticinin yazacagi giderle gordugu sayinin
      // ayrismasi demekti.
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  async function gidereYaz() {
    setBekliyor(true);
    setHata(null);
    try {
      await apiSend("/api/mesai/gidere-yaz", "POST", {
        yil,
        ay,
        satirlar: yazilabilir.map((k) => ({ user_id: k.user_id })),
      });
      toast.success(t("mesaiYazildi"));
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("mesaiBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("mesaiAlt")}
        </p>
      </div>

      <HataDurumu mesaj={hata ?? (error ? t("ortakHataOlustu") : null)} />

      <div className="flex flex-wrap items-end gap-3">
        {/* IKI SECICI, IKI AYRI ETIKET.
            Once ikisini tek <label>("Donem") icine koymustum ve
            `erisilebilir-etiket` kilidi HAKLI OLARAK dustu: bir etiket
            iki alani sarmalayamaz — ekran okuyucu YIL seciciyi de
            "Donem" diye okur ve kullanici hangisinde oldugunu
            ayirt edemez. */}
        <div className="flex gap-2">
          <AlanSarmal etiket={t("mesaiAy")}>
            {(baglar) => (
              <Secim
                {...baglar}
                value={String(ay)}
                data-test="mesai-ay"
                onChange={(e) => setAy(Number(e.target.value))}
              >
                {AYLAR.map((a) => (
                  <option key={a} value={a}>
                    {String(a).padStart(2, "0")}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesaiYil")}>
            {(baglar) => (
              <Secim
                {...baglar}
                value={String(yil)}
                data-test="mesai-yil"
                onChange={(e) => setYil(Number(e.target.value))}
              >
                {[yil - 1, yil, yil + 1].map((y) => (
                  <option key={y} value={y}>
                    {y}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        </div>
        {data && !katsayiDuzenle && (
          <span className="flex items-center gap-2">
            <Rozet durum="bilgi">
              {t("mesaiKatsayi", { n: data.katsayi })}
            </Rozet>
            <Dugme
              tur="ikincil"
              data-test="mesai-katsayi-duzenle"
              onClick={() => {
                setKatsayiMetin(String(data.katsayi));
                setKatsayiDuzenle(true);
              }}
            >
              {t("mesaiKatsayiDuzenle")}
            </Dugme>
          </span>
        )}
        {katsayiDuzenle && (
          <span className="flex items-end gap-2">
            <AlanSarmal etiket={t("mesaiKatsayiDuzenle")}>
              {(baglar) => (
                <Alan
                  {...baglar}
                  data-test="mesai-katsayi-alan"
                  inputMode="decimal"
                  value={katsayiMetin}
                  onChange={(e) => setKatsayiMetin(e.target.value)}
                />
              )}
            </AlanSarmal>
            <Dugme
              tur="birincil"
              disabled={bekliyor}
              data-test="mesai-katsayi-kaydet"
              onClick={() => void katsayiKaydet()}
            >
              {t("ortakKaydet")}
            </Dugme>
            <Dugme tur="ikincil" onClick={() => setKatsayiDuzenle(false)}>
              {t("ortakIptal")}
            </Dugme>
          </span>
        )}
      </div>

      {katsayiDuzenle && (
        <p
          data-test="mesai-katsayi-notu"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
        >
          {t("mesaiKatsayiNotu")}
        </p>
      )}

      {/* KAYNAK ACIKCA SOYLENIR: hesap PLAN uzerinden yapiliyor ve
          sistemde gercek bir mesai kaydi YOK. Bunu gizlemek, PARAYA
          donusen bir sayiyi olculmus gibi gostermek olurdu. */}
      {data?.kaynak === "plan" && (
        <p
          data-test="mesai-kaynak-notu"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
        >
          {t("mesaiKaynakPlan")}
        </p>
      )}

      <Kart>
        <ul className="space-y-2" data-test="mesai-liste">
          {(data?.kisiler ?? []).map((k) => (
            <li
              key={k.user_id}
              className="flex flex-wrap items-center justify-between gap-2 border-b border-yuzey-divider pb-2 last:border-0"
              data-test={`mesai-satir-${k.user_id}`}
            >
              <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                {k.ad}
              </span>
              <span
                className="tabular-nums"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {t("mesaiSaatler", { toplam: k.toplam_saat, fazla: k.fazla_saat })}
              </span>
              <span className="tabular-nums" style={{ color: "var(--yz-text)" }}>
                {/* UCRET TANIMSIZ -> TUTAR YERINE UYARI. `0,00 TL`
                    yazmak, yoneticiye "mesai yok" demenin sessiz ve
                    yanlis yoluydu. */}
                {k.ucret_tanimsiz ? (
                  <Rozet durum="uyari">{t("mesaiUcretTanimsiz")}</Rozet>
                ) : k.gidere_yazildi ? (
                  <Rozet durum="olumlu">{t("mesaiYazilmis")}</Rozet>
                ) : (
                  kurusToTL(k.fazla_mesai_kurus ?? 0)
                )}
              </span>
            </li>
          ))}
          {(data?.kisiler ?? []).length === 0 && (
            <li style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
              {t("mesaiKayitYok")}
            </li>
          )}
        </ul>
      </Kart>

      {yazilabilir.length > 0 && (
        <Kart>
          <p className="text-sm text-metin-body" data-test="mesai-toplam">
            {t("mesaiYazilacakToplam", {
              n: yazilabilir.length,
              tutar: kurusToTL(toplam),
            })}
          </p>
          {/* ONAY ADIMI ACIKCA YAZILIR: yonetici "yazdim, bitti" sanip
              onayi atlarsa gider HIC GERCEKLESMEZ. */}
          <p
            className="mt-1"
            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
          >
            {t("mesaiOnayNotu")}
          </p>
          <div className="mt-3">
            <Dugme
              type="button"
              disabled={bekliyor}
              data-test="mesai-gidere-yaz"
              onClick={() => void gidereYaz()}
            >
              {bekliyor ? t("ortakKaydediliyor") : t("mesaiGidereYaz")}
            </Dugme>
          </div>
        </Kart>
      )}
    </div>
  );
}
