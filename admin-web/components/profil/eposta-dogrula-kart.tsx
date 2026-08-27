"use client";

// (P181 Bölüm 1 · P184-ek §9) E-POSTA GÖRÜNTÜLE / DEĞİŞTİR / DOĞRULA.
//
// TEK BİLEŞEN, ÜÇ DURUM:
//   * dogrulandi=true  → mevcut adres + "E-postayı değiştir" (YENİ adrese kod).
//   * dogrulandi=false + adres var → "Doğrula" (mevcut adrese kod).
//   * adres yok        → "E-posta ekle".
// Akış her durumda adres → kod. Backend `/me/eposta/kod-iste` + `/me/eposta/
// dogrula` (hız sınırlı, SIZDIRMAZ: adres başkasındaysa aynı yanıt döner ama
// kod gelmez; eski adres yeni adres doğrulanana kadar GEÇERLİ kalır — kilitleme
// yok; eski adrese "değiştirme talebi" bildirimi gider). SSO bağı e-postaya
// DEĞİL user_id'ye bağlı, o yüzden e-posta değişimi kimlik bağını bozmaz.
import { useState } from "react";

import { btnPrimary, inputCls } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";

export function EpostaDogrulaKart({
  mevcutEposta,
  dogrulandi,
  onDone,
}: {
  mevcutEposta?: string | null;
  dogrulandi: boolean;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const [adim, setAdim] = useState<"goster" | "adres" | "kod">("goster");
  const [eposta, setEposta] = useState("");
  const [kod, setKod] = useState("");
  const [bekliyor, setBekliyor] = useState(false);

  function duzenlemeyeGec() {
    // DEĞİŞTİRME (doğrulanmış) → YENİ adres için alan BOŞ başlar.
    // EKLEME/DOĞRULAMA (doğrulanmamış) → mevcut adres ön-dolu gelir.
    setEposta(dogrulandi ? "" : (mevcutEposta ?? ""));
    setKod("");
    setAdim("adres");
  }

  async function kodIste() {
    setBekliyor(true);
    try {
      await apiSend("/api/me/eposta/kod-iste", "POST", {
        eposta: eposta.trim().toLowerCase(),
      });
      setAdim("kod");
      toast.success(t("profilEpostaGonderildi"));
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBekliyor(false);
    }
  }

  async function dogrula() {
    setBekliyor(true);
    try {
      await apiSend("/api/me/eposta/dogrula", "POST", {
        eposta: eposta.trim().toLowerCase(),
        kod: kod.trim(),
      });
      toast.success(t("profilEpostaDogrulandi"));
      setAdim("goster");
      onDone();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBekliyor(false);
    }
  }

  if (adim === "goster") {
    return (
      <div className="space-y-1.5">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm" style={{ color: "var(--yz-text)" }}>
            {mevcutEposta || "—"}
          </span>
          {mevcutEposta ? (
            <span
              className="text-xs"
              style={{ color: dogrulandi ? "var(--yz-text-2)" : "var(--yz-text-3)" }}
            >
              {dogrulandi ? "✓" : t("profilEpostaRozetBekliyor")}
            </span>
          ) : null}
        </div>
        <button
          type="button"
          className="text-sm underline underline-offset-2"
          style={{ color: "var(--yz-accent)" }}
          onClick={duzenlemeyeGec}
        >
          {mevcutEposta ? t("profilEpostaDegistir") : t("profilEpostaEkle")}
        </button>
        <p className="text-xs" style={{ color: "var(--yz-text-3)" }}>
          {dogrulandi ? t("profilEpostaDegistirIpucu") : t("profilEpostaBeklemede")}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {adim === "adres" ? (
        <>
          <input
            className={inputCls}
            type="email"
            value={eposta}
            onChange={(e) => setEposta(e.target.value)}
            placeholder={t("profilEpostaAdres")}
            aria-label={t("profilEpostaAdres")}
            autoComplete="email"
          />
          <div className="flex gap-2">
            <button
              className={btnPrimary}
              disabled={bekliyor || !eposta.includes("@")}
              onClick={() => void kodIste()}
            >
              {bekliyor ? t("ortakKaydediliyor") : t("profilEpostaKodGonder")}
            </button>
            <button
              type="button"
              className="text-sm"
              style={{ color: "var(--yz-text-2)" }}
              onClick={() => setAdim("goster")}
            >
              {t("ortakVazgec")}
            </button>
          </div>
        </>
      ) : (
        <>
          <input
            className={inputCls}
            inputMode="numeric"
            autoComplete="one-time-code"
            value={kod}
            onChange={(e) => setKod(e.target.value)}
            placeholder={t("profilEpostaKod")}
            aria-label={t("profilEpostaKod")}
          />
          <div className="flex gap-2">
            <button
              className={btnPrimary}
              disabled={bekliyor || kod.trim().length < 4}
              onClick={() => void dogrula()}
            >
              {bekliyor ? t("ortakKaydediliyor") : t("profilEpostaDogrula")}
            </button>
            <button
              type="button"
              className="text-sm"
              style={{ color: "var(--yz-text-2)" }}
              onClick={() => setAdim("goster")}
            >
              {t("ortakVazgec")}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
