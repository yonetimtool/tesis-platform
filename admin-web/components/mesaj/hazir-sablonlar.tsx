"use client";

// (P250 §8) HAZIR SABLON KUTUPHANESI + KANAL DURUMU.
//
// Kutuphane PLATFORMUN metnidir (backend `hazir_sablonlar.py`, 7 dil).
// Yonetici bir sablonu SECER, yeni-sablon formuna duser, duzenler ve
// KENDI sablonu olarak kaydeder; kutuphane metni dogrudan GONDERILMEZ.
// Boylece "su kesintisi [TARİH]" gibi doldurulmamis bir yer tutucu
// sakine gitmez (kayitta ayrica uyarilir: `yerTutuculari`).

import useSWR from "swr";

import { Dugme, Kart, Modal, Rozet } from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useI18n } from "@/lib/i18n/kullan";

export interface HazirSablon {
  kod: string;
  kanal: "sms" | "eposta";
  ad: string;
  konu: string | null;
  govde: string;
}

interface MesajDurumu {
  sms_hazir: boolean;
  eposta_hazir: boolean;
  bugun_gonderilen: number;
  gunluk_kota: number | null;
}

const ROZET_OLUMLU = "olumlu" as const;
const ROZET_UYARI = "uyari" as const;

/** Doldurulmamis `[YER TUTUCU]`lar (sirali, tekrarsiz). Etiketler `{..}`
 *  bu kapsamda DEGIL: onlar gonderimde kisi basina dolar. */
export function yerTutuculari(metin: string): string[] {
  const bulunan: string[] = [];
  for (const m of metin.matchAll(/\[[^\]\n]{1,40}\]/g)) {
    if (!bulunan.includes(m[0])) bulunan.push(m[0]);
  }
  return bulunan;
}

/** Hazir e-posta govdesi DUZ METINDIR; zengin metin editoru HTML bekler.
 *  Bos satir = paragraf, tek satir sonu = `<br>`. Kacis ONCE yapilir. */
export function duzMetniHtmlYap(metin: string): string {
  const kac = (s: string) =>
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  return metin
    .split(/\n{2,}/)
    .map((p) => `<p>${kac(p).replace(/\n/g, "<br>")}</p>`)
    .join("");
}

/** Yoneticinin ekraninda kanal DURUMU — teknik ayar YOK (platformda). */
export function MesajDurumKarti() {
  const { t } = useI18n();
  const { data } = useSWR<MesajDurumu>("/api/panel/mesaj-durumu", jsonFetcher);
  if (!data) return null;
  return (
    <div data-test="mesaj-durumu">
    <Kart className="space-y-2">
      <div className="flex flex-wrap items-center gap-3">
        <Rozet durum={data.sms_hazir ? ROZET_OLUMLU : ROZET_UYARI}>
          {t("mesajSmsDurum")}: {data.sms_hazir ? t("mesajHazir") : t("mesajYapilandirilmadi")}
        </Rozet>
        <Rozet durum={data.eposta_hazir ? ROZET_OLUMLU : ROZET_UYARI}>
          {t("mesajEpostaDurum")}:{" "}
          {data.eposta_hazir ? t("mesajHazir") : t("mesajYapilandirilmadi")}
        </Rozet>
        <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("mesajBugunGonderilen")}: {data.bugun_gonderilen}
          {data.gunluk_kota ? ` / ${data.gunluk_kota}` : ""}
        </span>
      </div>
      <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {t("mesajDurumAciklama")}
      </p>
    </Kart>
    </div>
  );
}

export function HazirSablonPenceresi({
  kanal,
  onSec,
  onKapat,
}: {
  kanal: "sms" | "eposta";
  onSec: (s: HazirSablon) => void;
  onKapat: () => void;
}) {
  const { t, dil } = useI18n();
  const { data } = useSWR<{ items: HazirSablon[] }>(
    `/api/panel/mesaj-sablonlari-hazir?kanal=${kanal}&dil=${dil}`,
    jsonFetcher,
  );
  return (
    <Modal acik onKapat={onKapat} baslik={t("mesajHazirSablonlar")}>
      <p className="mb-3" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("mesajHazirSablonAlt")}
      </p>
      <ul className="space-y-2" data-test="hazir-sablonlar">
        {(data?.items ?? []).map((s) => (
          <li
            key={s.kod}
            className="flex items-start justify-between gap-3 rounded p-2"
            style={{ border: "var(--yz-border-w) solid var(--yz-border)" }}
            data-test={`hazir-${s.kod}`}
          >
            <div className="min-w-0">
              <div style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 600, color: "var(--yz-text)" }}>
                {s.ad}
              </div>
              <p
                className="line-clamp-2 whitespace-pre-line"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {s.govde}
              </p>
            </div>
            <Dugme boy="kucuk" onClick={() => onSec(s)}>
              {t("mesajHazirSablonKullan")}
            </Dugme>
          </li>
        ))}
      </ul>
    </Modal>
  );
}
