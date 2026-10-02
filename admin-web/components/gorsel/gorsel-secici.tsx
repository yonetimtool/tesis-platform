"use client";

// (P251 §5) ORTAK GORSEL SECICI — yukle, onizle, kaldir.
//
// Duyuru ve site kurali sayfalarinda AYNI mantik kopyalanmisti (P190 §3);
// etkinlik ve rezervasyon alani da gorsel alinca ucuncu/dorduncu kopya
// olacakti. Desen ayni kalir: dosya secilir secilmez presign + dogrudan
// depoya PUT; kaydette yalniz `foto_key` gider. `kaldirildi` mevcut
// gorselin ACIKCA kaldirilmasi (PATCH null) — dokunulmamis gorselle
// karismasin diye ayri bayrak.
import { useRef, useState } from "react";

import { IcerikGorseli, type GorselTuru } from "@/components/gorsel/icerik-gorseli";
import { Dugme, HataDurumu, IskeletMetin } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";
import type { PresignTicket } from "@/lib/types";

export interface GorselDurumu {
  yukleniyor: boolean;
  hata: string | null;
  fotoKey: string | null;
  onizleme: string | null;
  kaldirildi: boolean;
}
export const GORSEL_BOS: GorselDurumu = {
  yukleniyor: false,
  hata: null,
  fotoKey: null,
  onizleme: null,
  kaldirildi: false,
};

/** Kaydetmeden once: yukleme suruyorsa ya da dustuyse kullaniciya soylenecek
 *  sozluk anahtari; sorun yoksa null. */
export function gorselEngeli(d: GorselDurumu): SozlukAnahtari | null {
  if (d.yukleniyor) return "duyuruGorselBekleyin";
  if (d.onizleme && !d.fotoKey) return "duyuruGorselTekrarSecin";
  return null;
}

/** Govdeye `foto_key`: yeni yukleme -> anahtar, kaldir -> null, dokunulmadi
 *  -> alan HIC yazilmaz (sunucu mevcudu korur). */
export function gorselGovdeye(d: GorselDurumu, govde: Record<string, unknown>): void {
  if (d.fotoKey) govde.foto_key = d.fotoKey;
  else if (d.kaldirildi) govde.foto_key = null;
}

export function useGorselSecimi() {
  const [durum, setDurum] = useState<GorselDurumu>(GORSEL_BOS);
  const sifirla = () =>
    setDurum((p) => {
      if (p.onizleme) URL.revokeObjectURL(p.onizleme);
      return GORSEL_BOS;
    });
  return { durum, setDurum, sifirla };
}

export function GorselSecici({
  durum,
  setDurum,
  mevcutUrl,
  mevcutVar,
  tur,
  devreDisi,
}: {
  durum: GorselDurumu;
  setDurum: React.Dispatch<React.SetStateAction<GorselDurumu>>;
  /** Duzenlenen kaydin mevcut gorseli (imzali adres). */
  mevcutUrl?: string | null;
  mevcutVar?: boolean;
  tur: GorselTuru;
  devreDisi?: boolean;
}) {
  const t = useT();
  const dosyaRef = useRef<HTMLInputElement>(null);

  async function sec(e: React.ChangeEvent<HTMLInputElement>) {
    const dosya = e.target.files?.[0];
    if (!dosya) return;
    setDurum((p) => {
      if (p.onizleme) URL.revokeObjectURL(p.onizleme);
      return { ...GORSEL_BOS, yukleniyor: true, onizleme: URL.createObjectURL(dosya) };
    });
    try {
      const bilet = await apiSend<PresignTicket>("/api/uploads/presign", "POST", {
        content_type: dosya.type || "image/jpeg",
        dosya_adi: dosya.name,
      });
      const put = await fetch(bilet.upload_url, {
        method: "PUT",
        headers: { "Content-Type": dosya.type || "image/jpeg" },
        body: dosya,
      });
      if (!put.ok) throw new Error(t("yuklemeBasarisiz", { kod: put.status }));
      setDurum((p) => ({ ...p, yukleniyor: false, fotoKey: bilet.foto_key }));
    } catch (err) {
      setDurum((p) => ({
        ...p,
        yukleniyor: false,
        hata: err instanceof Error ? err.message : t("duyuruGorselYuklenemedi"),
      }));
    }
  }

  const gosterilen = durum.onizleme ?? (durum.kaldirildi ? null : mevcutUrl ?? null);
  const kaldirilabilir = Boolean(durum.fotoKey) || (Boolean(mevcutVar) && !durum.kaldirildi);

  return (
    <div className="space-y-2" data-test="gorsel-secici">
      <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
        {t("duyuruGorselOpsiyonel")}
      </span>
      <IcerikGorseli url={gosterilen} alt={t("duyuruGorselOpsiyonel")} boy="buyuk" tur={tur} />
      {durum.yukleniyor && <IskeletMetin satir={2} />}
      {durum.hata && <HataDurumu mesaj={durum.hata} />}
      <div className="flex flex-wrap items-center gap-2">
        <input
          ref={dosyaRef}
          aria-label={t("duyuruGorselOpsiyonel")}
          type="file"
          accept="image/*"
          onChange={(e) => void sec(e)}
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
          disabled={durum.yukleniyor || devreDisi}
        />
        {kaldirilabilir && (
          <Dugme
            type="button"
            boy="kucuk"
            disabled={durum.yukleniyor || devreDisi}
            onClick={() => {
              if (dosyaRef.current) dosyaRef.current.value = "";
              setDurum((p) => {
                if (p.onizleme) URL.revokeObjectURL(p.onizleme);
                return { ...GORSEL_BOS, kaldirildi: true };
              });
            }}
          >
            {t("duyuruGorseliKaldir")}
          </Dugme>
        )}
      </div>
    </div>
  );
}
