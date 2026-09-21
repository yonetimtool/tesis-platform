"use client";

/**
 * (P240 §2) DIYAFON BOLUMU — "Entegrasyonlar" ekraninin ICINDE.
 *
 * =========================================================================
 * NEDEN AYRI SAYFA DEGIL
 * =========================================================================
 * §4'un istegi: "Panel'de TEK BIR 'Entegrasyonlar' ekranindan hepsi
 * gorunsun". Diyafona ayri bir menu girisi acmak, yoneticinin "bagli mi"
 * sorusunu iki ayri ekranda sormasi demekti — P232'de vardiya
 * ekranlarinda tam olarak bu kusur olculmustu.
 *
 * =========================================================================
 * YETENEK LISTESI SUNUCUDAN GELIR
 * =========================================================================
 * "Hangi yontem ne yapabiliyor" listesi `yetenekler` alanindan cizilir;
 * istemcide ikinci bir tablo tutmak iki tarafin ayrisabilmesi demekti.
 * Eylem dugmeleri de buna gore cizilir: basinca 422 alacak bir dugme
 * gostermek, olmayan bir yetenegi vaat etmek olurdu.
 */
import { useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  Kart,
  Modal,
  Rozet,
  Secim,
  useOnay,
} from "@/components/ui";
import { Tablo, TabloBasligi, Td, Th, Tr } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type Yetenek = {
  metin_anons: boolean;
  sesli_anons: boolean;
  kapi_ac: boolean;
  zil_cal: boolean;
};
type Diyafon = {
  id: string;
  ad: string;
  yontem: string;
  host: string;
  port: number | null;
  kullanici: string | null;
  sifre_set: boolean;
  hedef: string | null;
  zil_yolu: string | null;
  kapi_yolu: string | null;
  aktif: boolean;
  saglik: string;
  son_basarili_at: string | null;
  son_hata_kod: string | null;
  yetenekler: Yetenek;
};

const YONTEMLER = ["sip", "sip_kopru", "kuru_kontak"] as const;
const YONTEM_ETIKET: Record<string, SozlukAnahtari> = {
  sip: "diyafonYontemSip",
  sip_kopru: "diyafonYontemSipKopru",
  kuru_kontak: "diyafonYontemKuruKontak",
};
const SAGLIK_ETIKET: Record<string, SozlukAnahtari> = {
  bilinmiyor: "entegSaglikBilinmiyor",
  bagli: "entegSaglikBagli",
  hata: "entegSaglikHata",
};
const HATA_ETIKET: Record<string, SozlukAnahtari> = {
  diyafon_ulasilamiyor: "diyafonHataUlasilamiyor",
  diyafon_reddedildi: "diyafonHataReddedildi",
  diyafon_yapilandirma_eksik: "diyafonHataYapilandirma",
  diyafon_yontem_desteklemiyor: "diyafonHataDesteklemiyor",
};
const SAGLIK_YEDEK: SozlukAnahtari = "entegSaglikBilinmiyor";
const HATA_YEDEK: SozlukAnahtari = "diyafonHataUlasilamiyor";
const YONTEM_YEDEK: SozlukAnahtari = "diyafonYontemSip";
const KURU = "kuru_kontak";
const IKINCIL = "ikincil" as const;
const BIRINCIL = "birincil" as const;

interface FormState {
  ad: string;
  yontem: string;
  host: string;
  port: string;
  kullanici: string;
  sifre: string;
  hedef: string;
  zil_yolu: string;
  kapi_yolu: string;
}
const BOS: FormState = {
  ad: "",
  yontem: "sip",
  host: "",
  port: "",
  kullanici: "",
  sifre: "",
  hedef: "",
  zil_yolu: "",
  kapi_yolu: "",
};

export function DiyafonBolumu() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const { data, mutate } = useSWR<{ items: Diyafon[] }>(
    "/api/diyafon?limit=50",
    jsonFetcher,
  );
  const [acik, setAcik] = useState(false);
  const [duzenlenen, setDuzenlenen] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(BOS);
  const [mesgul, setMesgul] = useState<string | null>(null);

  const kuru = form.yontem === KURU;

  async function kaydet() {
    setMesgul("kaydet");
    try {
      const govde = {
        ad: form.ad,
        yontem: form.yontem,
        host: form.host,
        port: form.port ? Number(form.port) : null,
        kullanici: form.kullanici || null,
        // BOS SIFRE GONDERILMEZ: "degistirme" demektir, "sil" degil.
        ...(form.sifre ? { sifre: form.sifre } : {}),
        hedef: form.hedef || null,
        zil_yolu: form.zil_yolu || null,
        kapi_yolu: form.kapi_yolu || null,
      };
      if (duzenlenen) await apiSend(`/api/diyafon/${duzenlenen}`, "PATCH", govde);
      else await apiSend("/api/diyafon", "POST", govde);
      setAcik(false);
      setForm(BOS);
      setDuzenlenen(null);
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(null);
    }
  }

  async function eylem(d: Diyafon, yol: string) {
    setMesgul(`${d.id}:${yol}`);
    try {
      const y = (await apiSend(`/api/diyafon/${d.id}/${yol}`, "POST", {})) as {
        ok: boolean;
        kod: string | null;
      };
      if (y.ok) toast.success(t("diyafonEylemBasarili"));
      else toast.error(t(HATA_ETIKET[y.kod ?? ""] ?? HATA_YEDEK));
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(null);
    }
  }

  const satirlar = data?.items ?? [];

  return (
    <section className="mt-8 space-y-3" data-test="diyafon-bolumu">
      {diyalog}
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 style={{ fontSize: "var(--yz-fs-h2)", color: "var(--yz-text)" }}>
            {t("diyafonBaslik")}
          </h2>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("diyafonAlt")}
          </p>
        </div>
        <Dugme
          type="button"
          tur={BIRINCIL}
          boy="kucuk"
          data-test="diyafon-yeni"
          onClick={() => {
            setForm(BOS);
            setDuzenlenen(null);
            setAcik(true);
          }}
        >
          {t("diyafonYeni")}
        </Dugme>
      </div>

      <Kart>
        {satirlar.length === 0 ? (
          <BosDurum baslik={t("diyafonYok")} aciklama={t("diyafonYokAlt")} />
        ) : (
          <Tablo>
            <TabloBasligi>
              <Th>{t("ortakAd")}</Th>
              <Th>{t("diyafonYontem")}</Th>
              <Th>{t("diyafonYetenekler")}</Th>
              <Th>{t("entegSaglik")}</Th>
              <Th>{t("entegSonIletisim")}</Th>
              <Th aria-label={t("ortakDuzenle")} />
            </TabloBasligi>
            <tbody>
              {satirlar.map((d) => (
                <Tr key={d.id} data-test={`diyafon-satir-${d.id}`}>
                  <Td>{d.ad}</Td>
                  <Td>{t(YONTEM_ETIKET[d.yontem] ?? YONTEM_YEDEK)}</Td>
                  <Td>
                    <span
                      data-test={`diyafon-yetenek-${d.id}`}
                      style={{ fontSize: "var(--yz-fs-sm)" }}
                    >
                      {[
                        d.yetenekler.metin_anons ? t("diyafonYetenekMetin") : null,
                        d.yetenekler.zil_cal ? t("diyafonYetenekZil") : null,
                        d.yetenekler.kapi_ac ? t("diyafonYetenekKapi") : null,
                      ]
                        .filter(Boolean)
                        .join(" · ")}
                    </span>
                    {/* SESLI ANONS HICBIR YONTEMDE YOK — bunu burada
                        yazmak, "neden ses gelmiyor" sorusunu sahada
                        degil SECIM ANINDA yanitlar. */}
                    <div
                      data-test={`diyafon-sesli-yok-${d.id}`}
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                    >
                      {t("diyafonSesliAnonsYok")}
                    </div>
                  </Td>
                  <Td>
                    <span data-test={`diyafon-saglik-${d.id}`}>
                      <Rozet
                        durum={
                          d.saglik === "bagli"
                            ? "olumlu"
                            : d.saglik === "hata"
                              ? "kritik"
                              : "notr"
                        }
                      >
                        {t(SAGLIK_ETIKET[d.saglik] ?? SAGLIK_YEDEK)}
                      </Rozet>
                    </span>
                    {d.son_hata_kod && (
                      <div
                        data-test={`diyafon-hata-${d.id}`}
                        style={{
                          fontSize: "var(--yz-fs-xs)",
                          color: "var(--yz-danger-ink)",
                        }}
                      >
                        {t(HATA_ETIKET[d.son_hata_kod] ?? HATA_YEDEK)}
                      </div>
                    )}
                  </Td>
                  <Td>
                    <span data-test={`diyafon-son-iletisim-${d.id}`}>
                      {d.son_basarili_at
                        ? formatDateTime(d.son_basarili_at)
                        : t("entegHicIletisim")}
                    </span>
                  </Td>
                  <Td hizala="end">
                    <div className="flex flex-wrap justify-end gap-2">
                      <Dugme
                        type="button"
                        boy="kucuk"
                        tur={IKINCIL}
                        data-test={`diyafon-test-${d.id}`}
                        disabled={mesgul === `${d.id}:saglik`}
                        onClick={() => void eylem(d, "saglik")}
                      >
                        {t("diyafonTestEt")}
                      </Dugme>
                      {d.yetenekler.zil_cal && (
                        <Dugme
                          type="button"
                          boy="kucuk"
                          tur={IKINCIL}
                          data-test={`diyafon-zil-${d.id}`}
                          onClick={() => void eylem(d, "zil")}
                        >
                          {t("diyafonZil")}
                        </Dugme>
                      )}
                      {d.yetenekler.kapi_ac && (
                        <Dugme
                          type="button"
                          boy="kucuk"
                          tur={IKINCIL}
                          data-test={`diyafon-kapi-${d.id}`}
                          onClick={async () => {
                            // FIZIKSEL ERISIM: onay ister. Yanlislikla
                            // tiklanan bir dugme kapiyi acmamali.
                            if (
                              await onayla({
                                baslik: t("diyafonKapiAc"),
                                mesaj: t("diyafonKapiOnay", { ad: d.ad }),
                                onayMetni: t("diyafonKapiAc"),
                              })
                            ) {
                              await eylem(d, "kapi-ac");
                            }
                          }}
                        >
                          {t("diyafonKapiAc")}
                        </Dugme>
                      )}
                      <Dugme
                        type="button"
                        boy="kucuk"
                        tur={IKINCIL}
                        data-test={`diyafon-duzenle-${d.id}`}
                        onClick={() => {
                          setForm({
                            ad: d.ad,
                            yontem: d.yontem,
                            host: d.host,
                            port: d.port ? String(d.port) : "",
                            kullanici: d.kullanici ?? "",
                            sifre: "",
                            hedef: d.hedef ?? "",
                            zil_yolu: d.zil_yolu ?? "",
                            kapi_yolu: d.kapi_yolu ?? "",
                          });
                          setDuzenlenen(d.id);
                          setAcik(true);
                        }}
                      >
                        {t("ortakDuzenle")}
                      </Dugme>
                    </div>
                  </Td>
                </Tr>
              ))}
            </tbody>
          </Tablo>
        )}
      </Kart>

      <Modal
        acik={acik}
        onKapat={() => setAcik(false)}
        baslik={duzenlenen ? t("diyafonDuzenle") : t("diyafonYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setAcik(false)}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
              tur={BIRINCIL}
              data-test="diyafon-kaydet"
              yukleniyor={mesgul === "kaydet"}
              onClick={() => void kaydet()}
            >
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-3">
          <AlanSarmal etiket={t("ortakAd")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                data-test="diyafon-ad"
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("diyafonYontem")} ipucu={t("diyafonYontemIpucu")}>
            {(b) => (
              <Secim
                {...b}
                data-test="diyafon-yontem"
                value={form.yontem}
                onChange={(e) => setForm({ ...form, yontem: e.target.value })}
              >
                {YONTEMLER.map((y) => (
                  <option key={y} value={y}>
                    {t(YONTEM_ETIKET[y])}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("diyafonHost")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                data-test="diyafon-host"
                value={form.host}
                onChange={(e) => setForm({ ...form, host: e.target.value })}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("diyafonPort")} ipucu={t("diyafonPortIpucu")}>
            {(b) => (
              <Alan
                {...b}
                type="number"
                data-test="diyafon-port"
                value={form.port}
                onChange={(e) => setForm({ ...form, port: e.target.value })}
              />
            )}
          </AlanSarmal>
          {/* ALANLAR YONTEME GORE: SIP'te hedef dahili, kuru kontakta
              zil/kapi yolu. Hepsini birden gostermek, kullaniciya
              doldurmamasi gereken alanlar sunmak olurdu. */}
          {kuru ? (
            <>
              <AlanSarmal etiket={t("diyafonZilYolu")} ipucu={t("diyafonYolIpucu")}>
                {(b) => (
                  <Alan
                    {...b}
                    data-test="diyafon-zil-yolu"
                    value={form.zil_yolu}
                    onChange={(e) => setForm({ ...form, zil_yolu: e.target.value })}
                  />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("diyafonKapiYolu")} ipucu={t("diyafonYolIpucu")}>
                {(b) => (
                  <Alan
                    {...b}
                    data-test="diyafon-kapi-yolu"
                    value={form.kapi_yolu}
                    onChange={(e) => setForm({ ...form, kapi_yolu: e.target.value })}
                  />
                )}
              </AlanSarmal>
            </>
          ) : (
            <AlanSarmal etiket={t("diyafonHedef")} ipucu={t("diyafonHedefIpucu")}>
              {(b) => (
                <Alan
                  {...b}
                  data-test="diyafon-hedef"
                  value={form.hedef}
                  onChange={(e) => setForm({ ...form, hedef: e.target.value })}
                />
              )}
            </AlanSarmal>
          )}
          <AlanSarmal etiket={t("diyafonKullanici")}>
            {(b) => (
              <Alan
                {...b}
                data-test="diyafon-kullanici"
                value={form.kullanici}
                onChange={(e) => setForm({ ...form, kullanici: e.target.value })}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("diyafonSifre")} ipucu={t("diyafonSifreIpucu")}>
            {(b) => (
              <Alan
                {...b}
                type="password"
                data-test="diyafon-sifre"
                value={form.sifre}
                onChange={(e) => setForm({ ...form, sifre: e.target.value })}
              />
            )}
          </AlanSarmal>
        </div>
      </Modal>
    </section>
  );
}
