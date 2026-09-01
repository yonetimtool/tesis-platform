"use client";

// (P126.3) AİDATIM — sakinin KENDİ borcu.
//
// Paneldeki `/dues` YÖNETİM ekranıdır: tahakkuk oluşturur, sitenin bütün
// dairelerini listeler. Bu onun kendi-kaydı karşılığıdır ve AYRI BİR UÇ
// kullanır (`GET /me/dues`) — aynı ucu rol süzgeciyle paylaşmak, bir gün
// süzgeç unutulduğunda tüm sitenin borcunu sakine göstermek olurdu.
//
// Sakin birden çok daireye bağlı olabilir (malik + kiracı); sunucu liste
// döner ve ekran her daireyi ayrı kart olarak gösterir.
import useSWR from "swr";

import {
  BosDurum,
  HataDurumu,
  IskeletMetin,
} from "@/components/ui";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { jsonFetcher } from "@/lib/fetcher";
import { tarihBicimi } from "@/lib/tarih";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL } from "@/lib/money";

type Tahakkuk = {
  id: string;
  donem: string;
  tutar_kurus: number;
  son_odeme_tarihi: string | null;
  aciklama: string | null;
};
type Odeme = { id: string; tutar_kurus: number; odeme_tarihi: string };
type DaireDurum = {
  unit_id: string;
  no: string;
  toplam_tahakkuk_kurus: number;
  toplam_odenen_kurus: number;
  bakiye_kurus: number;
  assessments: Tahakkuk[];
  payments: Odeme[];
};

// (P61) HATA VARKEN "YOK" DENMEZ: liste `data?.items ?? []`den turer, yani
// istek dustugunde de BOS gorunur ve sayfa hem hatayi hem "kayit yok"u
// gosterirdi. Bos-durum kosulu bu yuzden `!error` de arar.
/** (P192 §4.4) SAKININ MAKBUZ ARSIVI.
 *
 * Makbuz uretiliyordu ama sakin ONA ULASAMIYORDU: makbuz ucu yalniz
 * yonetime acikti. Odedigi paranin belgesine erisemeyen sakin, her
 * seferinde yonetime sormak zorunda kalirdi.
 *
 * PDF baglantisi KISA OMURLUDUR (sunucu her istekte yeniden uretir) ve
 * SAKLANMAZ: kalici bir baglanti, kimlik dogrulamasi olmadan erisilebilen
 * bir mali belge demekti.
 */
function Makbuzlar() {
  const t = useT();
  const { data, error } = useSWR<{
    items: {
      id: string;
      belge_no: string;
      tutar_kurus: number;
      created_at: string;
      pdf_url: string | null;
    }[];
  }>("/api/me/makbuzlar?limit=20", jsonFetcher);
  const makbuzlar = data?.items ?? [];

  return (
    <section className="space-y-3">
      <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t("aidatimMakbuzlar")}
      </h2>
      {/* HATA METNI BOLUME OZEL: sayfanin ustunde zaten genel bir uyari
          olabilir ve iki ayni cumle, sakine ayni sorunu iki kez soylemek
          olurdu. Ozel metin hem hangi bolumun dustugunu soyler hem de
          ekranda ayirt edilebilir kalir. */}
      {error ? <HataDurumu mesaj={t("aidatimMakbuzHata")} /> : null}
      {!error && makbuzlar.length === 0 ? (
        <BosDurum baslik={t("aidatimMakbuzYok")} />
      ) : null}
      {makbuzlar.length > 0 ? (
        <div className="overflow-x-auto">
          <Tablo>
            <caption className="sr-only">{t("aidatimMakbuzlar")}</caption>
            <TabloBasligi zeminsiz className="text-xs">
              <Th dolgusuz className="py-1.5">{t("aidatimMakbuzNo")}</Th>
              <Th dolgusuz className="py-1.5">{t("aidatimTutar")}</Th>
              <Th dolgusuz className="py-1.5">{t("aidatimSonOdeme")}</Th>
              <Th dolgusuz className="py-1.5">{t("aidatimMakbuzIndir")}</Th>
            </TabloBasligi>
            <tbody>
              {makbuzlar.map((m) => (
                <tr key={m.id} className="border-t border-yuzey-divider">
                  <Td dolgusuz className="py-2 font-mono text-xs">{m.belge_no}</Td>
                  <Td dolgusuz className="py-2 tabular-nums">
                    {kurusToTL(m.tutar_kurus)}
                  </Td>
                  <Td dolgusuz className="py-2">{tarihBicimi(m.created_at)}</Td>
                  <Td dolgusuz className="py-2">
                    {m.pdf_url ? (
                      <a href={m.pdf_url} target="_blank" rel="noreferrer">
                        {t("aidatimMakbuzIndir")}
                      </a>
                    ) : (
                      "—"
                    )}
                  </Td>
                </tr>
              ))}
            </tbody>
          </Tablo>
        </div>
      ) : null}
    </section>
  );
}

export default function AidatimPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: DaireDurum[] }>(
    "/api/me/dues",
    jsonFetcher,
  );
  const daireler = data?.items ?? [];

  return (
    <div className="space-y-6">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("aidatimBaslik")}
      </h1>
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}

      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}

      {!isLoading && !error && daireler.length === 0 ? (
        <BosDurum baslik={t("aidatimYok")} />
      ) : null}

      {daireler.map((d) => (
        <section key={d.unit_id} className="space-y-4">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("aidatimDaire", { no: d.no })}</h2>
            <p
              className={`text-lg font-semibold tabular-nums ${
                d.bakiye_kurus > 0 ? "text-red-700" : "text-emerald-700"
              }`}
            >
              {kurusToTL(d.bakiye_kurus)}
            </p>
          </div>

          <dl className="grid gap-3 sm:grid-cols-2">
            <div>
              <dt style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("aidatimTahakkuk")}</dt>
              <dd className="tabular-nums">
                {kurusToTL(d.toplam_tahakkuk_kurus)}
              </dd>
            </div>
            <div>
              <dt style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("aidatimOdenen")}</dt>
              <dd className="tabular-nums">
                {kurusToTL(d.toplam_odenen_kurus)}
              </dd>
            </div>
          </dl>

          {d.assessments.length > 0 ? (
            <div className="overflow-x-auto">
              <Tablo>
                <caption className="sr-only">{t("aidatimTahakkukListe")}</caption>
                <TabloBasligi zeminsiz className="text-xs">
                    <Th dolgusuz className="py-1.5">{t("aidatimDonem")}</Th>
                    <Th dolgusuz className="py-1.5">{t("aidatimTutar")}</Th>
                    <Th dolgusuz className="py-1.5">{t("aidatimSonOdeme")}</Th>
                  </TabloBasligi>
                <tbody>
                  {d.assessments.map((a) => (
                    <tr key={a.id} className="border-t border-yuzey-divider">
                      <Td dolgusuz className="py-2">{a.donem}</Td>
                      <Td dolgusuz className="py-2 tabular-nums">
                        {kurusToTL(a.tutar_kurus)}
                      </Td>
                      <Td dolgusuz className="py-2">
                        {a.son_odeme_tarihi
                          ? tarihBicimi(a.son_odeme_tarihi)
                          : "—"}
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </Tablo>
            </div>
          ) : null}
        </section>
      ))}

      <Makbuzlar />
    </div>
  );
}
