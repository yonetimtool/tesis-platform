"use client";

/**
 * (P243 §3) ICE AKTARIM TABLOSU — SUTUNLARI HAZIR, YAPISTIRILABILIR.
 *
 * =========================================================================
 * OLCULEN SURTUNME
 * =========================================================================
 * Onceki akis: yonetici kendi Excel'ini alip bizim sablonumuza uyduruyor,
 * yukluyor, sonra KOLON ESLEMESI yapiyordu. Yani once dosyasini
 * degistiriyor, sonra da hangi sutunun ne oldugunu bize anlatiyordu.
 *
 * Bu ekranda sutunlar ZATEN BIZIM: kullanici kendi tablosundan kopyalayip
 * yapistiriyor, hucreler sirayla doluyor. Esleme adimi YOK.
 *
 * =========================================================================
 * YAPISTIRMA EN KRITIK OZELLIK
 * =========================================================================
 * Excel'den kopyalanan blok TSV'dir (sutun = sekme, satir = yeni satir).
 * Yapistirma ODAKLANAN HUCREDEN baslar ve saga/asagi yayilir — Excel'in
 * kendi davranisi. Satir yetmezse TABLO BUYUR: "once 50 satir ekleyin"
 * demek, isi kullaniciya geri vermekti.
 *
 * =========================================================================
 * MOBILDE YOK (P204 karari)
 * =========================================================================
 * Bu bilesen yalniz web'de. 200 satirlik bir onizlemeyi telefonda
 * dogrulamak mumkun degil; mobilde ekran "toplu aktarim bilgisayardan
 * yapilir" der.
 */
import { useMemo } from "react";

import { Tablo, TabloBasligi, Td, Th, Tr } from "@/components/ui";
import { Dugme } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";

export type AktarimAlani = { kod: string; zorunlu: boolean; ornek: string };
export type SatirHatasi = { satir_no: number; alan: string | null; hata: string };

const IKINCIL = "ikincil" as const;
const KUCUK = "kucuk" as const;
/** Ilk acilista gosterilen bos satir sayisi. */
const BASLANGIC_SATIR = 5;
const AYRAC = " · ";
const IKI_NOKTA = ": ";

function bosSatir(alanlar: AktarimAlani[]): Record<string, string> {
  return Object.fromEntries(alanlar.map((a) => [a.kod, ""]));
}

/** Excel blogu: sutun = sekme, satir = yeni satir. */
function panoyuCoz(metin: string): string[][] {
  const satirlar = metin.replace(/\r\n/g, "\n").split("\n");
  // SON BOS SATIR ATILIR: Excel secimin sonuna bir yeni satir koyar ve
  // her yapistirmada tabloya bos bir satir eklenirdi.
  if (satirlar.length > 1 && satirlar[satirlar.length - 1].trim() === "") {
    satirlar.pop();
  }
  return satirlar.map((s) => s.split("\t"));
}

export function bosTablo(alanlar: AktarimAlani[]): Record<string, string>[] {
  return Array.from({ length: BASLANGIC_SATIR }, () => bosSatir(alanlar));
}

export function AktarimTablosu({
  alanlar,
  satirlar,
  onDegis,
  hatalar,
}: {
  alanlar: AktarimAlani[];
  satirlar: Record<string, string>[];
  onDegis: (yeni: Record<string, string>[]) => void;
  hatalar: SatirHatasi[];
}) {
  const t = useT();

  /** satir_no (2'den baslar) -> o satirin hatalari. */
  const hataHaritasi = useMemo(() => {
    const h = new Map<number, SatirHatasi[]>();
    for (const x of hatalar) {
      const liste = h.get(x.satir_no) ?? [];
      liste.push(x);
      h.set(x.satir_no, liste);
    }
    return h;
  }, [hatalar]);

  function hucreYaz(satir: number, kod: string, deger: string) {
    onDegis(
      satirlar.map((s, i) => (i === satir ? { ...s, [kod]: deger } : s)),
    );
  }

  function yapistir(
    olay: React.ClipboardEvent<HTMLInputElement>,
    satir: number,
    kolon: number,
  ) {
    const metin = olay.clipboardData.getData("text/plain");
    // TEK HUCRELIK YAPISTIRMA: tarayicinin kendi davranisi kalsin.
    if (!metin.includes("\t") && !metin.includes("\n")) return;
    olay.preventDefault();
    const blok = panoyuCoz(metin);
    const yeni = satirlar.map((s) => ({ ...s }));
    blok.forEach((hucreler, i) => {
      const hedef = satir + i;
      while (yeni.length <= hedef) yeni.push(bosSatir(alanlar));
      hucreler.forEach((deger, j) => {
        const alan = alanlar[kolon + j];
        if (alan) yeni[hedef][alan.kod] = deger.trim();
      });
    });
    onDegis(yeni);
  }

  return (
    <div className="space-y-2" data-test="aktarim-tablosu">
      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("iceAktarimTabloIpucu")}
      </p>
      <div className="overflow-x-auto">
        <Tablo>
          <TabloBasligi>
            <Th>{t("iceAktarimSatirNo")}</Th>
            {alanlar.map((a) => (
              <Th key={a.kod}>
                {/* SUTUNUN NE OLDUGU ve ZORUNLULUGU BASLIKTA: altta
                    bir aciklama satiri, kaydirinca ekrandan cikardi. */}
                <span>
                  {a.kod}
                  {a.zorunlu ? ` (${t("iceAktarimZorunluSutun")})` : ""}
                </span>
              </Th>
            ))}
            <Th aria-label={t("iceAktarimSatirSil")} />
          </TabloBasligi>
          <tbody>
            {satirlar.map((satir, i) => {
              const satirHatalari = hataHaritasi.get(i + 2) ?? [];
              return (
                <Tr key={i}>
                  {/* `Tr` `data-test` GECIRMIYOR (P239'da `Td` icin de
                      olculmustu): kanca SATIR NUMARASI hucresindeki
                      `span`a konuyor. */}
                  <Td>
                    <span
                      data-test={`aktarim-satir-${i}`}
                      style={{
                        fontSize: "var(--yz-fs-xs)",
                        color:
                          satirHatalari.length > 0
                            ? "var(--yz-danger)"
                            : "var(--yz-text-3)",
                      }}
                    >
                      {i + 2}
                    </span>
                  </Td>
                  {alanlar.map((a, j) => {
                    const hatali = satirHatalari.some(
                      (h) => h.alan === a.kod || h.alan === null,
                    );
                    return (
                      <Td key={a.kod}>
                        <input
                          className="odak-ic h-10 w-full px-2 outline-none"
                          data-test={`aktarim-hucre-${i}-${a.kod}`}
                          aria-label={`${a.kod} ${i + 2}`}
                          aria-invalid={hatali || undefined}
                          style={{
                            background: "var(--yz-surface-1)",
                            color: "var(--yz-text)",
                            // HATALI HUCRE ANINDA BELIRGIN — renk TEK
                            // BASINA degil: satir numarasi da kirmizi ve
                            // altta cumlesi yazili.
                            border: hatali
                              ? "2px solid var(--yz-danger-edge)"
                              : "var(--yz-border-w) solid var(--yz-border)",
                          }}
                          value={satir[a.kod] ?? ""}
                          placeholder={a.ornek}
                          onPaste={(e) => yapistir(e, i, j)}
                          onChange={(e) => hucreYaz(i, a.kod, e.target.value)}
                        />
                      </Td>
                    );
                  })}
                  <Td>
                    <Dugme
                      type="button"
                      boy={KUCUK}
                      tur={IKINCIL}
                      data-test={`aktarim-satir-sil-${i}`}
                      onClick={() => onDegis(satirlar.filter((_, x) => x !== i))}
                    >
                      {t("ortakSil")}
                    </Dugme>
                  </Td>
                </Tr>
              );
            })}
          </tbody>
        </Tablo>
      </div>

      {/* HATALAR SATIR NUMARASIYLA: "bir yerde sorun var" demek,
          kullaniciyi 200 satirda aramaya gondermekti. */}
      {hatalar.length > 0 && (
        <ul data-test="aktarim-hata-listesi" className="max-h-40 overflow-y-auto">
          {hatalar.map((h, i) => (
            <li
              key={`${h.satir_no}-${h.alan}-${i}`}
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-danger)" }}
            >
              {t("iceAktarimSatirNo")} {h.satir_no}
              {h.alan ? `${AYRAC}${h.alan}` : ""}
              {IKI_NOKTA}
              {h.hata}
            </li>
          ))}
        </ul>
      )}

      <div className="flex flex-wrap gap-2">
        <Dugme
          type="button"
          boy={KUCUK}
          tur={IKINCIL}
          data-test="aktarim-satir-ekle"
          onClick={() => onDegis([...satirlar, bosSatir(alanlar)])}
        >
          {t("iceAktarimSatirEkle")}
        </Dugme>
        <Dugme
          type="button"
          boy={KUCUK}
          tur={IKINCIL}
          data-test="aktarim-tablo-temizle"
          onClick={() => onDegis(bosTablo(alanlar))}
        >
          {t("iceAktarimTabloTemizle")}
        </Dugme>
      </div>
    </div>
  );
}
