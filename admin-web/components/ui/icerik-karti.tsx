"use client";

/**
 * (P244 §8d) ICERIK KARTI — kapak gorselli duyuru/etkinlik/kural.
 *
 * =========================================================================
 * OLCULEN KUSUR — bu bir tasarim eksigi degil, GORUNMEYEN VERI
 * =========================================================================
 * Sozlesme `Announcement`, `Etkinlik` ve `SiteKurali` semalarinin
 * UCUNDE de `foto_url` (kisa omurlu presigned GET) ve `olusturan_ad`
 * soz veriyor. Yonetim ekranlari gorsel YUKLUYOR — kural gorseli
 * P190 §3'te ozellikle eklenmisti.
 *
 * Sakin taraftaki uc ekran (`/duyurular`, `/etkinlikler`, `/kurallar`)
 * bu alanlari YEREL TIPLERINE HIC KOYMAMISTI: yonetici bir duyuruya
 * kapak gorseli ekliyor, sakin onu HIC GORMUYORDU.
 *
 * =========================================================================
 * NEDEN TEK BILESEN
 * =========================================================================
 * Uc ekran ayni seyi gosteriyor: baslik + ust veri satiri + serbest
 * metin + opsiyonel kapak. Uc kez yazmak, gorselin oran/kirpma
 * davranisinin uc yerde ayrisması demekti (bugunku dagiiniklik).
 *
 * =========================================================================
 * KAPAK ORANI SABIT ve bu BILINCLI
 * =========================================================================
 * Gorseller kullanici yuklemesidir: dikey bir telefon fotografi
 * karti ekran boyu uzatirdi. `aspect-[16/9] object-cover` kirpar ama
 * DUZENI KORUR; liste taranabilir kalir.
 */
import type { ReactNode } from "react";

import { Foto } from "@/components/Foto";

import { Kart } from "./yuzey";

export function IcerikKarti({
  baslik,
  ustVeri,
  govde,
  fotoUrl,
  fotoAlt,
  altBilgi,
  rozet,
}: {
  baslik: string;
  /** Tarih · yazar · konum — tek satirda, ikincil renkte. */
  ustVeri?: ReactNode;
  /** Serbest metin. Satir sonlari KORUNUR (`whitespace-pre-line`). */
  govde?: string | null;
  /** Kapak gorseli (presigned GET). Yoksa alan HIC cizilmez. */
  fotoUrl?: string | null;
  fotoAlt: string;
  /** Kartin altindaki ek bilgi (katilim sayilari gibi). */
  altBilgi?: ReactNode;
  /** Basligin yanindaki durum/hedef rozeti. */
  rozet?: ReactNode;
}) {
  return (
    <Kart className="space-y-2">
      {fotoUrl ? (
        <Foto
          src={fotoUrl}
          alt={fotoAlt}
          className="aspect-[16/9] w-full rounded-lg object-cover"
        />
      ) : null}
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)", fontWeight: 600 }}>
          {baslik}
        </h2>
        {rozet}
      </div>
      {ustVeri ? (
        <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{ustVeri}</p>
      ) : null}
      {govde ? (
        <p
          className="whitespace-pre-line"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
        >
          {govde}
        </p>
      ) : null}
      {altBilgi}
    </Kart>
  );
}
