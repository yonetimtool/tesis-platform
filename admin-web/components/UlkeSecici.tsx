"use client";

/**
 * (P236) ÜLKE KODU SEÇİCİ — ARANABİLİR.
 *
 * =========================================================================
 * NEDEN `<select>` DEGIL
 * =========================================================================
 * P233'te yerlesik `<select>` kullaniliyordu. Elli ulkede yerlesik liste
 * YAZARAK ATLAMAYI (type-ahead) yalnizca GORUNEN METNE gore yapar ve o
 * metin artik `🇹🇷 +90` — yani kullanici "TR" yazip bulamaz, emoji
 * yazmasi gerekirdi. Mobilde P233'ten beri ARAMA KUTULU bir alt sayfa
 * var; web geride kalmisti.
 *
 * =========================================================================
 * NEDEN EMOJI BAYRAK, NEDEN GORSEL DEGIL
 * =========================================================================
 * OLCULEN GERCEK: bayrak emojisi HER YERDE CIZILMIYOR. Yaygin sanildigi
 * gibi bu oncelikle "bazi Android surumleri" meselesi DEGIL — asil yer
 * WINDOWS: Segoe UI Emoji'de bayrak YOKTUR ve panel cogunlukla masaustunde
 * kullaniliyor. Bazi Android yapimlari (ozellikle Cin pazarina cikan
 * OEM'ler) de bayraklari cikariyor.
 *
 * YINE DE EMOJI SECILDI, cunku CIZILMEDIGINDE BILGI KAYBOLMUYOR: bayrak
 * bir REGIONAL INDICATOR ciftidir (🇹🇷 = U+1F1F9 U+1F1F7) ve bayrak
 * bicimi yoksa HARFLERE duser — ekranda `TR +90` yazar. Yani en kotu
 * durumda kullanici ISO kodunu gorur; bu, gorsel bir bayragin yuklenmemesi
 * durumundan (bos kare) DAHA IYI.
 *
 * GORSEL (SVG/PNG) SECILMEDI:
 *   * elli bayrak = elli varlik; paket boyutu ve istek sayisi buyur,
 *   * CSP/cevrimdisi yuzeyi acar,
 *   * bayat kalma riski (P184'te bayat mipmap eski ikonu tasidi),
 *   * ve kazanci YALNIZCA gorseldir — okunabilirlik zaten ISO koduyla
 *     garanti altinda.
 *
 * TURKIYE LISTENIN BASINDA (`ULKELER` sirasi). VARSAYILAN OLARAK SECILI
 * DEGIL ve bu P233'un olculmus karari: onceden secili bir `+90`, kutuya
 * hic bakmadan yabanci numara yazan kullanicinin numarasini SESSIZCE Turk
 * numarasina cevirirdi — telefon GLOBAL BENZERSIZ anahtar oldugu icin
 * baskasinin numarasiyla cakisma ya da erisilemez hesap demekti.
 */
import { useEffect, useMemo, useRef, useState } from "react";

import { Alan } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import { ULKELER, ulkeBul, ulkeEslesiyor, ulkeEtiketi } from "@/lib/ulke-telefon";

export function UlkeSecici({
  deger,
  onDegisti,
  disabled,
  etiket,
  hatali,
}: {
  /** Secili ISO kodu; bos = secilmedi. */
  deger: string;
  onDegisti: (kod: string) => void;
  disabled?: boolean;
  etiket: string;
  hatali?: boolean;
}) {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const [sorgu, setSorgu] = useState("");
  const sarmal = useRef<HTMLDivElement>(null);

  const secili = ulkeBul(deger);
  const liste = useMemo(
    () => ULKELER.filter((u) => ulkeEslesiyor(u, sorgu)),
    [sorgu],
  );

  // DISARI TIKLAMA KAPATIR: acik kalan bir liste, altindaki numara
  // alanini tiklanamaz yapardi — bu turun duzelttigi kusurun ta kendisi.
  useEffect(() => {
    if (!acik) return;
    function dinle(e: MouseEvent) {
      if (!sarmal.current?.contains(e.target as Node)) setAcik(false);
    }
    document.addEventListener("mousedown", dinle);
    return () => document.removeEventListener("mousedown", dinle);
  }, [acik]);

  return (
    <div ref={sarmal} className="relative">
      <button
        type="button"
        data-test="telefon-ulke"
        aria-label={etiket}
        aria-expanded={acik}
        aria-haspopup="listbox"
        disabled={disabled}
        onClick={() => {
          setAcik((a) => !a);
          setSorgu("");
        }}
        className="odak-ic h-11 w-full px-3 text-start outline-none"
        style={{
          borderRadius: "var(--yz-radius-input)",
          background: "var(--yz-surface-sunken)",
          boxShadow: "var(--yz-sunken)",
          borderWidth: "var(--yz-border-w)",
          borderStyle: "solid",
          borderColor: hatali ? "var(--yz-danger-edge)" : "var(--yz-border)",
          color: secili ? "var(--yz-text)" : "var(--yz-text-3)",
          fontSize: "var(--yz-fs-input)",
        }}
      >
        {secili ? ulkeEtiketi(secili) : t("telefonUlkeSec")}
      </button>

      {acik && (
        <div
          data-test="telefon-ulke-liste"
          role="listbox"
          aria-label={etiket}
          className="absolute z-50 mt-1 w-full overflow-auto"
          style={{
            maxHeight: "16rem",
            borderRadius: "var(--yz-radius-input)",
            // Komut paletiyle AYNI tokenlar: o da bir acilir liste ve
            // ikisinin farkli yuzey rengi tasimasi tutarsizlik olurdu.
            background: "var(--yz-metal-1)",
            boxShadow: "var(--yz-raised-hover)",
            borderWidth: "var(--yz-border-w)",
            borderStyle: "solid",
            borderColor: "var(--yz-border)",
          }}
        >
          <div className="p-1">
            <Alan
              autoFocus
              data-test="telefon-ulke-ara"
              aria-label={t("telefonUlkeAraYerTutucu")}
              value={sorgu}
              onChange={(e) => setSorgu(e.target.value)}
              placeholder={t("telefonUlkeAraYerTutucu")}
            />
          </div>
          {liste.map((u) => (
            <button
              key={u.kod}
              type="button"
              role="option"
              aria-selected={u.kod === deger}
              data-test={`telefon-ulke-${u.kod}`}
              className="odak-ic block w-full px-3 py-2 text-start"
              style={{
                fontSize: "var(--yz-fs-sm)",
                color: "var(--yz-text)",
                background:
                  u.kod === deger ? "var(--yz-surface-2)" : undefined,
              }}
              onClick={() => {
                onDegisti(u.kod);
                setAcik(false);
              }}
            >
              {ulkeEtiketi(u)}
            </button>
          ))}
          {liste.length === 0 && (
            <p
              data-test="telefon-ulke-bos"
              className="px-3 py-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("telefonUlkeBulunamadi")}
            </p>
          )}
        </div>
      )}
    </div>
  );
}
