"use client";

import { useState } from "react";

import { Alan, AlanSarmal, Dugme, HataDurumu } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P233 §1) TESIS KONUMU SECICI — yer adindan koordinat.
 *
 * =========================================================================
 * NEDEN ENLEM/BOYLAM ALANI DEGIL
 * =========================================================================
 * Alanlar (`konum_lat`/`konum_lon`) `PATCH /tenant/settings` ile ZATEN
 * yazilabiliyordu — eksik olan sey, yoneticinin KOORDINAT YAZMADAN
 * konumunu verebilecegi bir yoldu. Kimse tesisinin enlemini bilmez;
 * bu yuzden alan bos kaldi ve HER TESIS sunucu varsayilani olan
 * Istanbul koordinatini tasidi (olculdu).
 *
 * =========================================================================
 * NEDEN HARITA DEGIL
 * =========================================================================
 * Web'de Leaflet bileseni var (`konum-haritasi.tsx`) ama MOBILDE hic
 * harita paketi YOK; yalniz web'e yapmak kalici parite kuralini bozardi.
 * Ustelik hava durumu ILCE duzeyinde dogruluk ister, sokak degil.
 *
 * =========================================================================
 * ADAY LISTESI, TEK SONUC DEGIL
 * =========================================================================
 * "Oltu" sorgusu Erzurum'daki ilceyi de, Artvin'deki "Oltuca"yi da,
 * Belarus'taki "Oltush"u da dondurur (olculdu). Ilkini otomatik secmek,
 * yoneticinin HIC GORMEDIGI bir konumu tesise yazmak olurdu — ve yanlis
 * hava durumu fark edilmesi en zor kusurlardandir, cunku ekran
 * CALISIYOR gorunur.
 */
type Aday = { ad: string; aciklama: string; lat: number; lon: number };

export function KonumSecici({
  mevcutAd,
  onSec,
}: {
  mevcutAd: string;
  onSec: (a: Aday) => void;
}) {
  const t = useT();
  const [q, setQ] = useState("");
  const [adaylar, setAdaylar] = useState<Aday[] | null>(null);
  const [bekliyor, setBekliyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  async function ara() {
    if (q.trim().length < 2) return;
    setBekliyor(true);
    setHata(null);
    try {
      const r = await fetch(`/api/konum/ara?q=${encodeURIComponent(q.trim())}`);
      if (!r.ok) throw new Error(String(r.status));
      const v = (await r.json()) as { items: Aday[] };
      setAdaylar(v.items);
    } catch {
      // SESSIZ BOS LISTE DEGIL: bos liste "boyle bir yer yok" demektir
      // ve servis coktugunde bu YANLIS bir cumledir.
      setHata(t("konumServisiYok"));
      setAdaylar(null);
    } finally {
      setBekliyor(false);
    }
  }

  return (
    <div className="space-y-2" data-test="konum-secici">
      <AlanSarmal etiket={t("ayarKonum")} ipucu={t("ayarKonumIpucu")}>
        {(b) => (
          <div className="flex gap-2">
            <Alan
              {...b}
              value={q}
              data-test="konum-ara"
              placeholder={mevcutAd}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  void ara();
                }
              }}
            />
            <Dugme
              type="button"
              boy="kucuk"
              data-test="konum-ara-dugme"
              yukleniyor={bekliyor}
              onClick={() => void ara()}
            >
              {t("ortakAra")}
            </Dugme>
          </div>
        )}
      </AlanSarmal>

      {hata && <HataDurumu mesaj={hata} />}

      {adaylar && adaylar.length === 0 && <p>{t("konumSonucYok")}</p>}

      {adaylar && adaylar.length > 0 && (
        <ul className="space-y-1" data-test="konum-adaylar">
          {adaylar.map((a) => (
            <li key={`${a.lat},${a.lon}`}>
              <Dugme
                type="button"
                boy="kucuk"
                tur="ikincil"
                data-test={`konum-aday-${a.lat}`}
                onClick={() => {
                  onSec(a);
                  setAdaylar(null);
                  setQ("");
                }}
              >
                {a.ad} — {a.aciklama}
              </Dugme>
            </li>
          ))}
        </ul>
      )}

      {mevcutAd && (
        <p
          data-test="konum-mevcut"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
        >
          {t("ayarKonumMevcut", { ad: mevcutAd })}
        </p>
      )}
    </div>
  );
}
