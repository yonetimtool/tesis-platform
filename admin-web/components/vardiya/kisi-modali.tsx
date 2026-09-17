"use client";

/**
 * (P239 §5) KISI PANELI — "su an gorevde" listesinden acilir.
 *
 * =========================================================================
 * OLCULEN KUSUR
 * =========================================================================
 * Gorevdekiler DUZ METINDI: `gorevdekiler.map(k => k.ad).join(", ")`.
 * Yonetici "su an kim gorevde"yi goruyor ama ona ULASAMIYORDU — numara
 * icin kullanicilar sayfasina gidip adi aramak gerekiyordu.
 *
 * =========================================================================
 * NUMARA NEREDEN GELIYOR — ve NEDEN /call-target DEGIL
 * =========================================================================
 * `/call-target` C1a arama kapisidir ve YALNIZ `security` + `resident`
 * rollerine aciktir (CALL_DIRECTIONS). Yonetici/admin oradan 403 alir.
 * Bu bilincli bir KVKK tasarimi ve BU TUR ONU GENISLETMEZ.
 *
 * Yonetimin numarayi gorme yolu ZATEN VAR: `GET /users/{id}` tek-kayit
 * yonetim gorunumu telefonu doner (liste UCU dondurmez — toplu numara
 * yok). Kullanicilar sayfasi da aynisini cizer. Yani bu panel YENI bir
 * ifsa acmiyor, VAR OLANI kisinin yanina getiriyor.
 *
 * Numara YOKSA satir "numara yok" der — bos birakmak, "yuklenmedi mi,
 * yok mu" sorusunu dogururdu.
 */
import useSWR from "swr";

import { Dugme, Modal } from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { rolAdi } from "@/lib/roles";

export type KisiOzeti = {
  user_id: string;
  ad: string;
  rol: string;
  /** Orn. vardiya saat araligi — kisinin SU AN neden burada oldugu. */
  altSatir?: string | null;
};

export function KisiModali({
  kisi,
  onKapat,
}: {
  kisi: KisiOzeti | null;
  onKapat: () => void;
}) {
  const t = useT();
  const { data, isLoading } = useSWR<{ telefon?: string | null }>(
    kisi ? `/api/users/${kisi.user_id}` : null,
    jsonFetcher,
  );
  const telefon = (data?.telefon ?? "").trim();

  return (
    <Modal
      acik={kisi !== null}
      onKapat={onKapat}
      baslik={kisi?.ad ?? ""}
      eylemler={
        <Dugme tur="ikincil" data-test="kisi-kapat" onClick={onKapat}>
          {t("ortakKapat")}
        </Dugme>
      }
    >
      {kisi && (
        <div className="space-y-2">
          <p data-test="kisi-rol" style={{ fontSize: "var(--yz-fs-sm)" }}>
            {rolAdi(t, kisi.rol)}
          </p>
          {kisi.altSatir && (
            <p
              data-test="kisi-alt-satir"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {kisi.altSatir}
            </p>
          )}
          {isLoading ? (
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
              {t("ortakYukleniyor")}
            </p>
          ) : telefon ? (
            // DOKUNULABILIR: telefonda ceviriciyi, masaustunde varsa
            // yazilim telefonunu acar. Duz metin olsaydi kullanici
            // numarayi elle kopyalardi.
            <a
              href={`tel:${telefon}`}
              data-test="kisi-telefon"
              className="odak-ic underline"
              style={{ color: "var(--yz-accent-ink)" }}
            >
              {telefon}
            </a>
          ) : (
            <p
              data-test="kisi-telefon-yok"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}
            >
              {t("kisiNumaraYok")}
            </p>
          )}
        </div>
      )}
    </Modal>
  );
}
