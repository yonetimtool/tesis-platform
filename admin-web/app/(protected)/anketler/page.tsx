"use client";

import { useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Grafik,
  Kart,
  Alan,
  AlanSarmal,
  BosDurum,
  CokSatir,
  Dugme,
  HataDurumu,
  Rozet,
  Secim,
} from "@/components/ui";
import { Tablo, TabloBasligi, Td, Th, Tr } from "@/components/tablo";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { rolAdi } from "@/lib/roles";
import type { Anket, AnketList, AnketOyKimList } from "@/lib/types";

/**
 * (P154 / Asama 7.2) ANKETLER — kendi sayfasi.
 *
 * (P237 §3) OLCULEN EKSIKLER VE NE YAPILDI
 * =========================================================================
 * Sayfa yalniz BASLIK ve MADDELER soruyordu; arka ucun zaten tasidigi
 * `aciklama`/`kapanis_at` bile formda yoktu. Gorsel, baslangic, hedef
 * kitle, anonimlik, katilim orani ve "kim neye oy verdi" HIC YOKTU.
 *
 * SONUC KAPANANA KADAR GIZLI (P38) ve bu sayfa onu DEGISTIRMEZ: sayilar
 * sunucudan geldigi gibi cizilir. Gelmiyorsa hic cizilmez — SIFIR
 * UYDURULMAZ, cunku "0 oy" ile "sonuc gizli" ayni sey degildir.
 */

/** Hedeflenebilir roller — arka uctaki `ANKET_HEDEF_ROLLER` ile ayni. */
const HEDEF_ROLLER = [
  "resident",
  "security",
  "guvenlik_amiri",
  "tesis_gorevlisi",
  "yonetici",
  "admin",
] as const;

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TIP_MALIK = "malik" as const;
const TIP_KIRACI = "kiraci" as const;

interface FormState {
  baslik: string;
  aciklama: string;
  /** SATIR BASINA BIR MADDE — en az iki. */
  maddeler: string;
  baslangic: string;
  bitis: string;
  hedefRoller: string[];
  hedefSakinTipi: string;
  anonim: boolean;
  gorselKey: string | null;
}

const BOS: FormState = {
  baslik: "",
  aciklama: "",
  maddeler: "",
  baslangic: "",
  bitis: "",
  hedefRoller: [],
  hedefSakinTipi: "",
  anonim: false,
  gorselKey: null,
};

function toIso(yerel: string): string | null {
  if (!yerel) return null;
  const d = new Date(yerel);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

export default function AnketlerPage() {
  const t = useT();
  const toast = useToast();
  const [hata, setHata] = useState<string | null>(null);
  const [modalAcik, setModalAcik] = useState(false);
  const [form, setForm] = useState<FormState>(BOS);
  const [yukleniyor, setYukleniyor] = useState(false);
  const [secili, setSecili] = useState<Anket | null>(null);

  const {
    data: anketler,
    error: aErr,
    mutate: tazele,
  } = useSWR<AnketList>("/api/panel/anketler?limit=50", jsonFetcher);

  // OY DOKUMU yalniz SECILI ve ADLI ankette istenir: anonimde arka uc 409
  // doner ve istegi hic atmamak, kullaniciya bir hata gostermemek demek.
  const { data: dokum } = useSWR<AnketOyKimList>(
    secili && !secili.anonim
      ? `/api/panel/anketler/${secili.id}/oylar?limit=200`
      : null,
    jsonFetcher,
  );

  async function gorselSec(dosya: File): Promise<void> {
    setYukleniyor(true);
    try {
      const bilet = await apiSend<{ foto_key: string; upload_url: string }>(
        "/api/uploads/presign",
        "POST",
        { content_type: dosya.type || "image/jpeg", dosya_adi: dosya.name },
      );
      const put = await fetch(bilet.upload_url, {
        method: "PUT",
        headers: { "Content-Type": dosya.type || "image/jpeg" },
        body: dosya,
      });
      if (!put.ok) throw new Error(t("yuklemeBasarisiz", { kod: put.status }));
      setForm((f) => ({ ...f, gorselKey: bilet.foto_key }));
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setYukleniyor(false);
    }
  }

  async function ekle(): Promise<void> {
    setHata(null);
    const secenekler = form.maddeler
      .split("\n")
      .map((x) => x.trim())
      .filter(Boolean)
      .map((metin, i) => ({ metin, sira: i }));
    if (!form.baslik.trim() || secenekler.length < 2) {
      // EN AZ IKI madde (P38): tek maddeli anket oy toplamaz, ONAY
      // toplar — bunu sunucuya sorup 422 almak yerine burada soyluyoruz.
      setHata(t("anketEnAzIki"));
      return;
    }
    try {
      await apiSend("/api/panel/anketler", "POST", {
        baslik: form.baslik,
        aciklama: form.aciklama || null,
        gorsel_key: form.gorselKey,
        baslangic_at: toIso(form.baslangic),
        kapanis_at: toIso(form.bitis),
        secenekler,
        hedef_roller: form.hedefRoller,
        hedef_sakin_tipi: form.hedefSakinTipi || null,
        anonim: form.anonim,
      });
      setForm(BOS);
      setModalAcik(false);
      toast.success(t("anketEklendi"));
      await tazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function kapat(id: string): Promise<void> {
    try {
      await apiSend(`/api/panel/anketler/${id}`, "PATCH", { aktif: false });
      toast.success(t("anketKapatildi"));
      await tazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  function rolDegis(rol: string, secildi: boolean): void {
    setForm((f) => ({
      ...f,
      hedefRoller: secildi
        ? [...f.hedefRoller, rol]
        : f.hedefRoller.filter((r) => r !== rol),
    }));
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("kabukAnketler")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("anketAlt")}
          </p>
        </div>
        <Dugme
          tur="birincil"
          boy="kucuk"
          data-test="anket-ekle-ac"
          onClick={() => {
            // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR.
            setHata(null);
            setForm(BOS);
            setModalAcik(true);
          }}
        >
          {t("anketEkle")}
        </Dugme>
      </div>
      <HataDurumu mesaj={hata ?? (aErr ? t("anketHata") : null)} />

      <Kart>
        {anketler && anketler.items.length === 0 ? (
          <BosDurum baslik={t("anketYok")} aciklama={t("anketYokAlt")} />
        ) : null}

        <div className="space-y-3">
          {(anketler?.items ?? []).map((a) => (
            <div
              key={a.id}
              data-test={`anket-${a.id}`}
              className="p-3"
              style={{
                borderRadius: "var(--yz-radius-btn)",
                border: "1px solid var(--yz-border)",
                fontSize: "var(--yz-fs-sm)",
                color: "var(--yz-text)",
              }}
            >
              <div className="flex flex-wrap items-center justify-between gap-3">
                <span className="flex items-center gap-2" style={{ fontSize: "var(--yz-fs-h3)" }}>
                  {a.baslik}
                  {a.anonim ? (
                    <Rozet durum="bilgi">{t("anketAnonimRozet")}</Rozet>
                  ) : null}
                </span>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {a.acik ? t("anketAcik") : t("anketKapali")}
                  {a.toplam_oy != null ? ` · ${a.toplam_oy}` : ""}
                </span>
              </div>

              {a.gorsel_url ? (
                /* eslint-disable-next-line @next/next/no-img-element */
                <img
                  src={a.gorsel_url}
                  alt={a.baslik}
                  loading="lazy"
                  decoding="async"
                  className="mt-2 max-h-40 rounded object-cover"
                />
              ) : null}
              {a.aciklama ? <p className="mt-1">{a.aciklama}</p> : null}

              <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {a.hedef_roller.length === 0
                  ? t("anketHedefHerkes")
                  : a.hedef_roller.map((r) => rolAdi(t, r)).join(", ")}
                {a.baslangic_at ? ` · ${formatDateTime(a.baslangic_at)}` : ""}
                {a.kapanis_at ? ` — ${formatDateTime(a.kapanis_at)}` : ""}
              </p>

              {/* KATILIM ORANI: payda sunucudan gelir ("kac kisiye gitti").
                  Payda YOKSA oran cizilmez — uydurma bir yuzde, katilimi
                  oldugundan iyi ya da kotu gosterirdi. */}
              {a.hedef_kisi != null && a.hedef_kisi > 0 && a.toplam_oy != null ? (
                <p className="mt-1" data-test={`anket-katilim-${a.id}`}>
                  {t("anketKatilim", {
                    oy: String(a.toplam_oy),
                    hedef: String(a.hedef_kisi),
                    oran: String(Math.round((a.toplam_oy / a.hedef_kisi) * 100)),
                  })}
                </p>
              ) : null}

              <ul className="mt-2 space-y-1 text-xs">
                {a.secenekler.map((s) => (
                  <li key={s.id} className="flex justify-between">
                    <span>{s.metin}</span>
                    {/* Yonetim sonucu HER ZAMAN gorur (P38) — sayi sunucudan
                        gelmiyorsa hic cizilmez, sifir UYDURULMAZ. */}
                    {s.oy != null ? (
                      <span className="tabular-nums">{s.oy}</span>
                    ) : null}
                  </li>
                ))}
              </ul>

              <div className="mt-2 flex flex-wrap gap-2">
                <Dugme
                  boy="kucuk"
                  tur="ikincil"
                  data-test={`anket-sonuc-${a.id}`}
                  onClick={() => setSecili(secili?.id === a.id ? null : a)}
                >
                  {t("anketSonuclar")}
                </Dugme>
                {a.aktif ? (
                  <Dugme
                    tur="tehlike"
                    boy="kucuk"
                    data-test={`anket-kapat-${a.id}`}
                    onClick={() => void kapat(a.id)}
                  >
                    {t("anketKapat")}
                  </Dugme>
                ) : null}
              </div>
            </div>
          ))}
        </div>
      </Kart>

      {secili ? (
        <Kart className="space-y-4">
          <h2 className="text-lg font-medium" data-test="anket-sonuc-panosu">
            {secili.baslik}
          </h2>
          {/* (P223) GRAFIK TURU TEK KURALDAN: 6 dilime kadar pasta,
              fazlasinda cubuk. Anket maddeleri BUTUNUN PARCALARIDIR —
              pasta dogru gosterimdir; cok maddeli ankette kural cubuga
              cevirir. */}
          <Grafik
            baslik={t("anketSonuclar")}
            bosBaslik={t("anketSonucGizli")}
            dilimler={secili.secenekler
              .filter((s) => s.oy != null)
              .map((s) => ({ ad: s.metin, deger: s.oy as number }))}
          />
          <h3 className="text-base font-medium">{t("anketOyDokumu")}</h3>
          {secili.anonim ? (
            /* ANONIMDE ISTEK HIC ATILMAZ: veri YOK, "yetkiniz yok" degil. */
            <BosDurum baslik={t("anketOyDokumuAnonim")} />
          ) : (
            <div className="overflow-hidden rounded-lg border kart-kenar">
              <div className="odak-ic overflow-x-auto" tabIndex={0}>
                <Tablo>
                  <TabloBasligi>
                    <Th>{t("raporTabloZaman")}</Th>
                    <Th>{t("ortakAd")}</Th>
                    <Th>{t("anketSonuclar")}</Th>
                  </TabloBasligi>
                  <tbody>
                    {(dokum?.items ?? []).map((o) => (
                      <Tr key={`${o.user_id}-${o.secenek_id}`}>
                        <Td className="text-metin-body">
                          {formatDateTime(o.created_at)}
                        </Td>
                        <Td>{o.ad ?? "—"}</Td>
                        <Td>{o.secenek_metin}</Td>
                      </Tr>
                    ))}
                    {dokum && dokum.items.length === 0 ? (
                      <tr>
                        <Td colSpan={3}>
                          <BosDurum baslik={t("denetimKayitYok")} />
                        </Td>
                      </tr>
                    ) : null}
                  </tbody>
                </Tablo>
              </div>
            </div>
          )}
        </Kart>
      ) : null}

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("anketEkle")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
              tur="birincil"
              disabled={yukleniyor}
              data-test="anket-kaydet"
              onClick={() => void ekle()}
            >
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <AlanSarmal etiket={t("anketBaslik")}>
              {(b) => (
                <Alan
                  {...b}
                  data-test="anket-baslik"
                  value={form.baslik}
                  onChange={(e) => setForm({ ...form, baslik: e.target.value })}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("anketAciklamaOpsiyonel")}>
              {(b) => (
                <Alan
                  {...b}
                  value={form.aciklama}
                  onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("anketBaslangic")}>
              {(b) => (
                <Alan
                  {...b}
                  type="datetime-local"
                  value={form.baslangic}
                  onChange={(e) => setForm({ ...form, baslangic: e.target.value })}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("anketBitis")}>
              {(b) => (
                <Alan
                  {...b}
                  type="datetime-local"
                  value={form.bitis}
                  onChange={(e) => setForm({ ...form, bitis: e.target.value })}
                />
              )}
            </AlanSarmal>
          </div>

          <AlanSarmal etiket={t("anketSecenekler")} ipucu={t("anketSecenekIpucu")}>
            {(b) => (
              <CokSatir
                {...b}
                rows={3}
                data-test="anket-maddeler"
                value={form.maddeler}
                onChange={(e) => setForm({ ...form, maddeler: e.target.value })}
              />
            )}
          </AlanSarmal>

          <AlanSarmal etiket={t("anketGorselOpsiyonel")}>
            {(b) => (
              <Alan
                {...b}
                type="file"
                accept="image/*"
                data-test="anket-gorsel"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) void gorselSec(f);
                }}
              />
            )}
          </AlanSarmal>

          {/* HEDEF KITLE — COKLU SECIM. Bos birakmak "herkes" demektir ve
              bu en sik kullanilan haldir; bu yuzden "Herkes" diye AYRI bir
              kutu KONMADI: isaretlenince digerleriyle celisen bir kutu
              olurdu ("Herkes + yalniz guvenlik" ne demek?). */}
          <fieldset className="space-y-1">
            <legend style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
              {t("anketHedefKitle")}
            </legend>
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {t("anketHedefHerkes")}
            </p>
            <div className="flex flex-wrap gap-3">
              {HEDEF_ROLLER.map((r) => (
                <label key={r} className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    data-test={`anket-hedef-${r}`}
                    checked={form.hedefRoller.includes(r)}
                    onChange={(e) => rolDegis(r, e.target.checked)}
                  />
                  {rolAdi(t, r)}
                </label>
              ))}
            </div>
          </fieldset>

          <AlanSarmal etiket={t("anketHedefSakinTipi")}>
            {(b) => (
              <Secim
                {...b}
                data-test="anket-sakin-tipi"
                value={form.hedefSakinTipi}
                onChange={(e) =>
                  setForm({ ...form, hedefSakinTipi: e.target.value })
                }
              >
                <option value="">{t("ortakSecimYok")}</option>
                <option value={TIP_MALIK}>{t("anketMalik")}</option>
                <option value={TIP_KIRACI}>{t("anketKiraci")}</option>
              </Secim>
            )}
          </AlanSarmal>

          {/* ANONIMLIK — KAYDEDILDIKTEN SONRA DEGISTIRILEMEZ.
              Uyari BURADA, kaydetmeden ONCE: sonradan gosterilen bir
              uyarinin degeri yok. Kilit veritabaninda (goc 0137). */}
          <div>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                data-test="anket-anonim"
                checked={form.anonim}
                onChange={(e) => setForm({ ...form, anonim: e.target.checked })}
              />
              {t("anketAnonim")}
            </label>
            <p
              className="mt-1"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {t("anketAnonimUyari")}
            </p>
          </div>
        </div>
      </Modal>
    </div>
  );
}
