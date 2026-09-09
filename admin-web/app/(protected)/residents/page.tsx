"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Rozet,
  useOnay,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useGecikmeli } from "@/lib/gecikmeli";
import { bloklaraGore } from "@/lib/sakin-gruplama";
import type { ResidentListItem } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P220 §4) SITE SAKINLERI — BLOKLARA GORE GRUPLU.
 *
 * =========================================================================
 * NEDEN `/users`I GENISLETMEK YERINE AYRI SAYFA
 * =========================================================================
 * Karar OLCUME dayaniyor, tercihe degil:
 *
 * 1. FARKLI SORU, FARKLI UC. `/users` "kimin hesabi var ve rolu ne"
 *    sorusunu yanitliyor — tum roller (admin, yonetici, guvenlik,
 *    denetci, sakin). Bu sayfa "KIM NEREDE OTURUYOR" sorusunu
 *    yanitliyor. Bloklara gore gruplama yalniz ikincisi icin anlamli.
 *
 * 2. `/users` VERIYI TASIMIYOR. `UserOut` semasinda `unit_no` da `blok`
 *    da YOK (olculdu). Eklemek, cok sayida ekranin okudugu bir semayi
 *    genisletmek demekti — etki alani ozelligin kendisinden buyuk.
 *
 * 3. GRUPLAMA `/users`IN ISINI BOZARDI. Orada bir yonetici ya da
 *    guvenlik gorevlisinin dairesi yok; onlari "Blok atanmamis"
 *    grubunda gostermek anlamsiz olurdu — onlar sakin degil.
 *
 * 4. `/users` ZATEN 1000+ SATIR ve kendi suzgecleri var. Ikinci bir
 *    gruplu kip eklemek, tek sayfayi iki farkli zihinsel modele
 *    hizmet ettirirdi.
 *
 * 5. MOBIL PARITESI. Mobilde ayri bir "Sakinler" ekrani var ve AYNI
 *    uctan besleniyor. Ayri sayfa, ayni davranisi ayni sozcuklerle
 *    veriyor.
 *
 * KARSI ARGUMAN (ve karsiligi): iki ayri kisi listesi "sakini nerede
 * bulacagim" tereddudu yaratabilir. Menude adlar ayrimi tasiyor
 * (Kullanicilar = hesaplar, Sakinler = daire sakinleri) ve bu sayfa
 * HESAP ACMIYOR — acma yolu `/users`ta.
 *
 * =========================================================================
 * GRUPLAMA ISTEMCIDE
 * =========================================================================
 * Sunucu duz liste donuyor ve o liste sayfalanmiyor (site sakini sayisi
 * binlerce degil). Sunucuda gruplamak, ayni veriyi iki bicimde donduren
 * ikinci bir uc demekti.
 */
export default function ResidentsPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();

  const [arama, setArama] = useState("");
  const [blok, setBlok] = useState<string | null>(null);
  // GECIKMELI: her tusa basista sunucuya gitmek gereksiz yuk ve titreyen
  // liste demekti. Mobil ve bildirim aramasiyla AYNI sure (300 ms).
  const aramaGecikmeli = useGecikmeli(arama, 300);
  const aramaGecerli = aramaGecikmeli.trim().length >= 2;

  const qs = new URLSearchParams();
  if (aramaGecerli) qs.set("q", aramaGecikmeli.trim());
  if (blok) qs.set("blok", blok);
  const key = `/api/residents${qs.toString() ? `?${qs.toString()}` : ""}`;
  const { data, error, isLoading, mutate } = useSWR<{
    items: ResidentListItem[];
  }>(key, jsonFetcher);

  const gruplar = useMemo(() => bloklaraGore(data?.items ?? []), [data?.items]);

  async function sakinSil(s: ResidentListItem) {
    const ok = await onayla({
      baslik: t("sakinSilBaslik"),
      mesaj: t("sakinSilMesaj", { ad: s.ad }),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      const sonuc = await apiSend<{ deleted: boolean }>(
        `/api/residents/${s.user_id}`,
        "DELETE",
      );
      // (P189) `deleted:false` BASARISIZLIK DEGIL: gecmisi olan sakin
      // silinmez, ANONIMLESTIRILIR ve satir kalir. Ikisini ayni mesajla
      // anlatmak, yoneticiye islemin yarim kaldigini dusundururdu.
      toast.success(
        sonuc?.deleted ? t("sakinSilindi") : t("sakinAnonimlestirildi"),
      );
      await mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    }
  }

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kabukSakinler")}
      </h1>
      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("sakinSayfaAciklama")}
      </p>

      <div className="flex flex-wrap items-center gap-2">
        <input
          type="search"
          value={arama}
          onChange={(e) => setArama(e.target.value)}
          placeholder={t("sakinAraIpucu")}
          aria-label={t("sakinAra")}
          className="w-full max-w-sm rounded px-3 py-2"
          style={{
            fontSize: "var(--yz-fs-sm)",
            border: "1px solid var(--yz-border)",
            background: "var(--yz-surface-1)",
            color: "var(--yz-text)",
          }}
        />
        {arama.trim().length > 0 && !aramaGecerli && (
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("sakinAraAsgari")}
          </span>
        )}
        {/* BLOK DARALTMASI ACIKSA GORUNUR — gerekce asagida. */}
        {blok !== null && (
          <Dugme boy="kucuk" tur="ikincil" onClick={() => setBlok(null)}>
            {t("sakinBlokSuzgeciKaldir", { blok })}
          </Dugme>
        )}
      </div>

      {isLoading ? (
        <IskeletMetin satir={4} />
      ) : error ? (
        <HataDurumu mesaj={t("sakinListelenemedi")} />
      ) : gruplar.length === 0 ? (
        <BosDurum
          baslik={
            aramaGecerli || blok !== null
              ? t("sakinAramaSonucYok")
              : t("sakinYok")
          }
          aciklama={aramaGecerli || blok !== null ? undefined : t("sakinYokAlt")}
        />
      ) : (
        <div className="space-y-4">
          {gruplar.map((g) => (
            <Kart key={g.blok ?? "__bloksuz__"}>
              <div className="mb-2 flex flex-wrap items-center gap-2">
                <h2 style={{ fontSize: "var(--yz-fs-body)", fontWeight: 700 }}>
                  {g.blok ?? t("sakinBloksuz")}
                </h2>
                <Rozet durum="notr">{String(g.sakinler.length)}</Rozet>
                {g.blok !== null && blok === null && (
                  <Dugme boy="kucuk" tur="sessiz" onClick={() => setBlok(g.blok)}>
                    {t("sakinBlogaDaralt")}
                  </Dugme>
                )}
              </div>
              <ul className="space-y-2">
                {g.sakinler.map((s) => (
                  <li
                    key={s.user_id}
                    className="flex flex-wrap items-center gap-2 rounded p-2"
                    style={{ border: "1px solid var(--yz-border)" }}
                  >
                    <span className="min-w-0 flex-1">
                      <strong>{s.ad}</strong>
                      <span
                        className="block"
                        style={{
                          fontSize: "var(--yz-fs-sm)",
                          color: "var(--yz-text-2)",
                        }}
                      >
                        {s.unit_no ?? t("sakinDairesiz")}
                      </span>
                    </span>
                    {!s.is_active && <Rozet durum="uyari">{t("ortakPasif")}</Rozet>}
                    <Dugme boy="kucuk" tur="tehlike" onClick={() => void sakinSil(s)}>
                      {t("ortakSil")}
                    </Dugme>
                  </li>
                ))}
              </ul>
            </Kart>
          ))}
        </div>
      )}
      {diyalog}
    </div>
  );
}
