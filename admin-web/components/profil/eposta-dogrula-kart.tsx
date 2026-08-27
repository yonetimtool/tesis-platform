"use client";

// (P181 Bölüm 1) E-POSTA EKLE/DOĞRULA KARTI.
//
// E-postasız ya da e-postalı-ama-doğrulanmamış kullanıcıya gösterilir. KİLİTLEME
// YOK: oturum sürer, bu yalnız "beklemede" durumunu açan bir davettir. İki adım:
// adres -> kod. Backend `/me/eposta/kod-iste` + `/me/eposta/dogrula` (hız sınırlı,
// sızıntısız). Doğrulanınca reset (Bölüm 2) ve OTP giriş (Bölüm 4) çalışır.
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
  const [eposta, setEposta] = useState(mevcutEposta ?? "");
  const [kod, setKod] = useState("");
  const [adim, setAdim] = useState<"adres" | "kod">("adres");
  const [bekliyor, setBekliyor] = useState(false);

  if (dogrulandi) {
    return (
      <p className="text-sm" style={{ color: "var(--yz-text-2)" }}>
        ✓ {t("profilEpostaDogrulandi")}
      </p>
    );
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
      onDone();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBekliyor(false);
    }
  }

  return (
    <div className="space-y-3">
      <p className="text-sm" style={{ color: "var(--yz-text-2)" }}>
        {t("profilEpostaBeklemede")}
      </p>
      {adim === "adres" ? (
        <div className="space-y-2">
          <input
            className={inputCls}
            type="email"
            value={eposta}
            onChange={(e) => setEposta(e.target.value)}
            placeholder={t("profilEpostaAdres")}
            aria-label={t("profilEpostaAdres")}
            autoComplete="email"
          />
          <button
            className={btnPrimary}
            disabled={bekliyor || !eposta.includes("@")}
            onClick={() => void kodIste()}
          >
            {bekliyor ? t("ortakKaydediliyor") : t("profilEpostaKodGonder")}
          </button>
        </div>
      ) : (
        <div className="space-y-2">
          <input
            className={inputCls}
            inputMode="numeric"
            autoComplete="one-time-code"
            value={kod}
            onChange={(e) => setKod(e.target.value)}
            placeholder={t("profilEpostaKod")}
            aria-label={t("profilEpostaKod")}
          />
          <button
            className={btnPrimary}
            disabled={bekliyor || kod.trim().length < 4}
            onClick={() => void dogrula()}
          >
            {bekliyor ? t("ortakKaydediliyor") : t("profilEpostaDogrula")}
          </button>
        </div>
      )}
    </div>
  );
}
