"use client";

/**
 * (P240 §3) AKILLI EV — AYRI SEKME, DOKUZ BOLUM.
 *
 * =========================================================================
 * BOLUM ANAHTARLARI NEDEN VAR
 * =========================================================================
 * Dokuz bolumun HEPSINI her siteye gostermek, dokuz bolumun sekizini
 * kullanmayan yoneticiye her gun bos dokuz baslik gostermek demekti.
 * Yokluk = KAPALI (sunucu tarafi da oyle); acmak BILINCLI bir karardir.
 *
 * =========================================================================
 * SAKIN SINIRI PANELDE DEGIL SUNUCUDA
 * =========================================================================
 * Bu sayfa cihazlari `/akilli-ev/cihazlar`dan alir ve HICBIR daire
 * suzgeci UYGULAMAZ. Sakinin yalniz kendi dairesini gormesi SUNUCUDA
 * zorlanir (`resident` icin sorgu daireye kisitli, `/komut` ucunda da
 * kimlik bazinda tekrar denetlenir). Istemcide filtrelemek, "gizlenmis
 * ama gonderilmis" veri demekti — yani sizinti.
 *
 * =========================================================================
 * "CIHAZ EKLEME" ENTEGRASYON GIBI DEGIL EKLEME GIBI DURMALI
 * =========================================================================
 * Form UC alan sorar (ad, tip, nerede) + merkezdeki kimlik. Protokol,
 * kimlik dogrulama, uc nokta — hepsi MERKEZ kaydinda, bir kez.
 */
import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, BosDurum, Dugme, HataDurumu, Kart, Modal, Rozet, Secim, Sekmeler, Tablo, TabloBasligi, Td, Th, Tr, useOnay } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type Kopru = {
  id: string;
  ad: string;
  tur: string;
  host: string;
  port: number | null;
  token_set: boolean;
  aktif: boolean;
  saglik: string;
  son_kontrol_at: string | null;
};
type Cihaz = {
  id: string;
  kopru_id: string;
  ad: string;
  tip: string;
  unit_id: string | null;
  daire_no: string | null;
  alan: string | null;
  dis_kimlik: string;
  aktif: boolean;
  eylemler: string[];
};
type Bolum = { bolum: string; acik: boolean };
type Senaryo = {
  id: string;
  olay: string;
  cihaz_id: string;
  cihaz_ad: string | null;
  eylem: string;
  aktif: boolean;
};

const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;
const KUCUK = "kucuk" as const;

const BOLUM_ETIKET: Record<string, SozlukAnahtari> = {
  aydinlatma: "akilliEvBolumAydinlatma",
  iklim: "akilliEvBolumIklim",
  kilit: "akilliEvBolumKilit",
  perde: "akilliEvBolumPerde",
  kacak: "akilliEvBolumKacak",
  yangin: "akilliEvBolumYangin",
  enerji: "akilliEvBolumEnerji",
  sayac: "akilliEvBolumSayac",
  senaryo: "akilliEvBolumSenaryo",
};
const TIP_ETIKET: Record<string, SozlukAnahtari> = {
  isik: "akilliEvTipIsik",
  priz: "akilliEvTipPriz",
  kilit: "akilliEvTipKilit",
  termostat: "akilliEvTipTermostat",
  perde: "akilliEvTipPerde",
  vana: "akilliEvTipVana",
  sensor_su: "akilliEvTipSensorSu",
  sensor_duman: "akilliEvTipSensorDuman",
  sensor_gaz: "akilliEvTipSensorGaz",
  sensor_hareket: "akilliEvTipSensorHareket",
  sayac: "akilliEvTipSayac",
  diger: "akilliEvTipDiger",
};
const EYLEM_ETIKET: Record<string, SozlukAnahtari> = {
  ac: "akilliEvEylemAc",
  kapat: "akilliEvEylemKapat",
  kilit_ac: "akilliEvEylemKilitAc",
  vana_kapat: "akilliEvEylemVanaKapat",
};
const OLAY_ETIKET: Record<string, SozlukAnahtari> = {
  su_kacagi: "akilliEvOlaySuKacagi",
  yangin: "akilliEvOlayYangin",
  gaz: "akilliEvOlayGaz",
  hareket: "akilliEvOlayHareket",
  panik_anons: "akilliEvOlayPanikAnons",
  panik_kapanis: "akilliEvOlayPanikKapanis",
};
const TIPLER = Object.keys(TIP_ETIKET);
const OLAYLAR = Object.keys(OLAY_ETIKET);
const EYLEMLER = Object.keys(EYLEM_ETIKET);
/** JSX ucluda sabit dize yasak (depo kurali `sabit-metin`). */
const CIZGI = "—";
const AYRAC = " · ";
/** `??` yedegi de ucluda sabit sayilir (`sabit-metin` kilidi); adlandirilir. */
const YEDEK_BOLUM: SozlukAnahtari = "akilliEvBolumSenaryo";
const YEDEK_TIP: SozlukAnahtari = "akilliEvTipDiger";
const YEDEK_EYLEM: SozlukAnahtari = "akilliEvEylemAc";
const YEDEK_OLAY: SozlukAnahtari = "akilliEvOlayYangin";

export default function AkilliEvPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();

  const koprular = useSWR<{ items: Kopru[] }>(
    "/api/akilli-ev/koprular?limit=50",
    jsonFetcher,
  );
  const cihazlar = useSWR<{ items: Cihaz[] }>(
    "/api/akilli-ev/cihazlar?limit=200",
    jsonFetcher,
  );
  const bolumler = useSWR<Bolum[]>("/api/akilli-ev/bolumler", jsonFetcher);
  const senaryolar = useSWR<{ items: Senaryo[] }>(
    "/api/akilli-ev/senaryolar?limit=100",
    jsonFetcher,
  );

  const [kopruForm, setKopruForm] = useState(false);
  const [kopruAd, setKopruAd] = useState("");
  const [kopruHost, setKopruHost] = useState("");
  const [kopruPort, setKopruPort] = useState("");
  const [kopruToken, setKopruToken] = useState("");
  const [jeton, setJeton] = useState<string | null>(null);

  const [cihazForm, setCihazForm] = useState(false);
  const [cAd, setCAd] = useState("");
  const [cTip, setCTip] = useState(TIPLER[0]);
  const [cKimlik, setCKimlik] = useState("");
  const [cAlan, setCAlan] = useState("");

  const [senForm, setSenForm] = useState(false);
  const [sOlay, setSOlay] = useState(OLAYLAR[0]);
  const [sCihaz, setSCihaz] = useState("");
  const [sEylem, setSEylem] = useState(EYLEMLER[0]);

  const kopruListe = koprular.data?.items ?? [];
  const cihazListe = cihazlar.data?.items ?? [];
  const senaryoListe = senaryolar.data?.items ?? [];

  function hata(e: unknown) {
    toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
  }

  async function kopruKaydet() {
    try {
      await apiSend("/api/akilli-ev/koprular", "POST", {
        ad: kopruAd,
        tur: "home_assistant",
        host: kopruHost,
        port: kopruPort ? Number(kopruPort) : null,
        token: kopruToken || null,
      });
      setKopruForm(false);
      setKopruAd("");
      setKopruHost("");
      setKopruPort("");
      setKopruToken("");
      await koprular.mutate();
    } catch (e) {
      hata(e);
    }
  }

  async function kopruTest(id: string) {
    try {
      const r = (await apiSend(
        `/api/akilli-ev/koprular/${id}/saglik`,
        "POST",
        {},
      )) as { ok: boolean };
      toast.success(r.ok ? t("entegSaglikBagli") : t("entegSaglikHata"));
      await koprular.mutate();
    } catch (e) {
      hata(e);
    }
  }

  async function jetonUret(id: string) {
    try {
      const r = (await apiSend(
        `/api/akilli-ev/koprular/${id}/olay-jetonu`,
        "POST",
        {},
      )) as { olay_jetonu: string };
      setJeton(r.olay_jetonu);
    } catch (e) {
      hata(e);
    }
  }

  async function cihazKaydet() {
    try {
      await apiSend("/api/akilli-ev/cihazlar", "POST", {
        kopru_id: kopruListe[0]?.id,
        ad: cAd,
        tip: cTip,
        alan: cAlan || null,
        dis_kimlik: cKimlik,
      });
      setCihazForm(false);
      setCAd("");
      setCKimlik("");
      setCAlan("");
      await cihazlar.mutate();
    } catch (e) {
      hata(e);
    }
  }

  async function komut(c: Cihaz, eylem: string) {
    try {
      await apiSend(`/api/akilli-ev/cihazlar/${c.id}/komut`, "POST", { eylem });
      toast.success(t("akilliEvKomutGonderildi"));
    } catch (e) {
      hata(e);
    }
  }

  async function cihazSil(c: Cihaz) {
    if (!(await onayla({ baslik: t("ortakSil"), mesaj: c.ad, onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/akilli-ev/cihazlar/${c.id}`, "DELETE");
      await cihazlar.mutate();
    } catch (e) {
      hata(e);
    }
  }

  async function bolumDegis(b: Bolum, acik: boolean) {
    const yeni = (bolumler.data ?? []).map((x) =>
      x.bolum === b.bolum ? { ...x, acik } : x,
    );
    try {
      // JENERIK YAZIM YOK (`apiSend<Bolum[]>`): `sabit-metin` tarayicisi
      // `>(` ... `("` arasini JSX metni saniyor. Donus tipi cikarimla
      // yazilir.
      const yaz = async (): Promise<Bolum[]> =>
        (await apiSend("/api/akilli-ev/bolumler", "PUT", {
          bolumler: yeni.map((x) => ({ bolum: x.bolum, acik: x.acik })),
        })) as Bolum[];
      await bolumler.mutate(yaz, {
        optimisticData: yeni,
        revalidate: false,
      });
    } catch (e) {
      hata(e);
    }
  }

  async function senaryoKaydet() {
    try {
      await apiSend("/api/akilli-ev/senaryolar", "POST", {
        olay: sOlay,
        cihaz_id: sCihaz,
        eylem: sEylem,
      });
      setSenForm(false);
      await senaryolar.mutate();
    } catch (e) {
      hata(e);
    }
  }

  async function senaryoSil(s: Senaryo) {
    if (!(await onayla({
      baslik: t("ortakSil"),
      mesaj: s.cihaz_ad ?? CIZGI,
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    })))
      return;
    try {
      await apiSend(`/api/akilli-ev/senaryolar/${s.id}`, "DELETE");
      await senaryolar.mutate();
    } catch (e) {
      hata(e);
    }
  }

  const bolumIcerik = (
    <Kart>
      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("akilliEvBolumAciklama")}
      </p>
      <div className="mt-3 grid gap-2 sm:grid-cols-3">
        {(bolumler.data ?? []).map((b) => (
          <label
            key={b.bolum}
            className="flex items-center gap-2"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
          >
            <input
              type="checkbox"
              className="h-4 w-4"
              data-test={`akilli-ev-bolum-${b.bolum}`}
              checked={b.acik}
              onChange={(e) => bolumDegis(b, e.target.checked)}
            />
            {t(BOLUM_ETIKET[b.bolum] ?? YEDEK_BOLUM)}
          </label>
        ))}
      </div>
    </Kart>
  );

  const kopruIcerik = (
    <Kart>
      <div className="mb-3 flex justify-end">
        <Dugme
          type="button"
          boy={KUCUK}
          tur={BIRINCIL}
          data-test="akilli-ev-kopru-ekle"
          onClick={() => setKopruForm(true)}
        >
          {t("akilliEvKopruEkle")}
        </Dugme>
      </div>
      {kopruListe.length === 0 ? (
        <BosDurum baslik={t("akilliEvKopruYok")} aciklama={t("akilliEvKopruYokAlt")} />
      ) : (
        <Tablo>
          <TabloBasligi>
            <Tr>
              <Th>{t("ortakAd")}</Th>
              <Th>{t("entegSaglik")}</Th>
              <Th>{t("akilliEvJeton")}</Th>
              <Th aria-label={t("ortakSil")} />
            </Tr>
          </TabloBasligi>
          <tbody>
            {kopruListe.map((k) => (
              <Tr key={k.id} data-test={`akilli-ev-kopru-${k.id}`}>
                <Td>
                  <span>
                    {k.ad}
                    {AYRAC}
                    {k.host}
                  </span>
                </Td>
                <Td>
                  <Rozet durum={k.saglik === "saglikli" ? "olumlu" : "notr"}>
                    {k.saglik === "saglikli"
                      ? t("entegSaglikBagli")
                      : t("entegSaglikBilinmiyor")}
                  </Rozet>
                </Td>
                <Td>
                  <span>{k.token_set ? t("akilliEvJetonYazili") : CIZGI}</span>
                </Td>
                <Td>
                  <div className="flex gap-2">
                    <Dugme
                      type="button"
                      boy={KUCUK}
                      tur={IKINCIL}
                      data-test={`akilli-ev-test-${k.id}`}
                      onClick={() => kopruTest(k.id)}
                    >
                      {t("entegKontrolEt")}
                    </Dugme>
                    <Dugme
                      type="button"
                      boy={KUCUK}
                      tur={IKINCIL}
                      data-test={`akilli-ev-jeton-${k.id}`}
                      onClick={() => jetonUret(k.id)}
                    >
                      {t("akilliEvOlayJetonu")}
                    </Dugme>
                  </div>
                </Td>
              </Tr>
            ))}
          </tbody>
        </Tablo>
      )}
    </Kart>
  );

  const cihazIcerik = (
    <Kart>
      <div className="mb-3 flex items-center justify-between">
        <span />
        {kopruListe.length > 0 && (
          <Dugme
            type="button"
            boy={KUCUK}
            tur={BIRINCIL}
            data-test="akilli-ev-cihaz-ekle"
            onClick={() => setCihazForm(true)}
          >
            {t("akilliEvCihazEkle")}
          </Dugme>
        )}
      </div>
      {cihazListe.length === 0 ? (
        <BosDurum baslik={t("akilliEvCihazYok")} aciklama={t("akilliEvCihazYokAlt")} />
      ) : (
        <Tablo>
          <TabloBasligi>
            <Tr>
              <Th>{t("ortakAd")}</Th>
              <Th>{t("akilliEvTur")}</Th>
              <Th>{t("akilliEvKonum")}</Th>
              <Th aria-label={t("ortakSil")} />
            </Tr>
          </TabloBasligi>
          <tbody>
            {cihazListe.map((c) => (
              <Tr key={c.id} data-test={`akilli-ev-cihaz-${c.id}`}>
                <Td>{c.ad}</Td>
                <Td>{t(TIP_ETIKET[c.tip] ?? YEDEK_TIP)}</Td>
                <Td>
                  <span>
                    {c.daire_no ?? c.alan ?? t("akilliEvOrtakAlan")}
                  </span>
                </Td>
                <Td>
                  <div className="flex gap-2">
                    {/* SENSORDE HIC DUGME YOK: sunucu zaten 422 doner,
                        ama calismayacak bir dugme gostermek kullaniciya
                        "denedim olmadi" yasatirdi. */}
                    {c.eylemler.map((e) => (
                      <Dugme
                        key={e}
                        type="button"
                        boy={KUCUK}
                        tur={IKINCIL}
                        data-test={`akilli-ev-komut-${c.id}-${e}`}
                        onClick={() => komut(c, e)}
                      >
                        {t(EYLEM_ETIKET[e] ?? YEDEK_EYLEM)}
                      </Dugme>
                    ))}
                    <Dugme
                      type="button"
                      boy={KUCUK}
                      tur={IKINCIL}
                      data-test={`akilli-ev-cihaz-sil-${c.id}`}
                      onClick={() => cihazSil(c)}
                    >
                      {t("ortakSil")}
                    </Dugme>
                  </div>
                </Td>
              </Tr>
            ))}
          </tbody>
        </Tablo>
      )}
    </Kart>
  );

  const senaryoIcerik = (
    <Kart>
      <div className="mb-3 flex items-center justify-between">
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("akilliEvSenaryoAciklama")}
        </p>
        {cihazListe.length > 0 && (
          <Dugme
            type="button"
            boy={KUCUK}
            tur={BIRINCIL}
            data-test="akilli-ev-senaryo-ekle"
            onClick={() => {
              setSCihaz(cihazListe[0].id);
              setSenForm(true);
            }}
          >
            {t("akilliEvSenaryoEkle")}
          </Dugme>
        )}
      </div>
      {senaryoListe.length === 0 ? (
        <BosDurum baslik={t("akilliEvSenaryoYok")} aciklama={t("akilliEvSenaryoYokAlt")} />
      ) : (
        <Tablo>
          <TabloBasligi>
            <Tr>
              <Th>{t("akilliEvOlay")}</Th>
              <Th>{t("ortakAd")}</Th>
              <Th>{t("akilliEvEylem")}</Th>
              <Th aria-label={t("ortakSil")} />
            </Tr>
          </TabloBasligi>
          <tbody>
            {senaryoListe.map((s) => (
              <Tr key={s.id} data-test={`akilli-ev-senaryo-${s.id}`}>
                <Td>{t(OLAY_ETIKET[s.olay] ?? YEDEK_OLAY)}</Td>
                <Td>
                  <span>{s.cihaz_ad ?? CIZGI}</span>
                </Td>
                <Td>{t(EYLEM_ETIKET[s.eylem] ?? YEDEK_EYLEM)}</Td>
                <Td>
                  <Dugme
                    type="button"
                    boy={KUCUK}
                    tur={IKINCIL}
                    data-test={`akilli-ev-senaryo-sil-${s.id}`}
                    onClick={() => senaryoSil(s)}
                  >
                    {t("ortakSil")}
                  </Dugme>
                </Td>
              </Tr>
            ))}
          </tbody>
        </Tablo>
      )}
    </Kart>
  );

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("akilliEvBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("akilliEvAciklama")}
        </p>
      </div>

      <HataDurumu
        mesaj={
          koprular.error || cihazlar.error || bolumler.error
            ? t("ortakHataOlustu")
            : null
        }
      />

      <Sekmeler
        sekmeler={[
          { id: "bolumler", baslik: t("akilliEvSekmeBolumler"), icerik: bolumIcerik },
          { id: "koprular", baslik: t("akilliEvSekmeKopruler"), icerik: kopruIcerik },
          { id: "cihazlar", baslik: t("akilliEvSekmeCihazlar"), icerik: cihazIcerik },
          {
            id: "senaryolar",
            baslik: t("akilliEvSekmeSenaryolar"),
            icerik: senaryoIcerik,
          },
        ]}
      />

      <Modal
        acik={kopruForm}
        baslik={t("akilliEvKopruEkle")}
        onKapat={() => setKopruForm(false)}
      >
        <div className="space-y-3">
          <AlanSarmal etiket={t("ortakAd")}>
            {(alanProps) => (
              <Alan
                {...alanProps}
                data-test="akilli-ev-kopru-ad"
                value={kopruAd}
                onChange={(e) => setKopruAd(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("diyafonHost")}>
            {(alanProps) => (
              <Alan
                {...alanProps}
                data-test="akilli-ev-kopru-host"
                value={kopruHost}
                onChange={(e) => setKopruHost(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("diyafonPort")}>
            {(alanProps) => (
              <Alan
                {...alanProps}
                inputMode="numeric"
                data-test="akilli-ev-kopru-port"
                value={kopruPort}
                onChange={(e) => setKopruPort(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("akilliEvJeton")}>
            {(alanProps) => (
              <Alan
                {...alanProps}
                type="password"
                data-test="akilli-ev-kopru-token"
                value={kopruToken}
                onChange={(e) => setKopruToken(e.target.value)}
              />
            )}
          </AlanSarmal>
          <Dugme
            type="button"
            tur={BIRINCIL}
            data-test="akilli-ev-kopru-kaydet"
            onClick={kopruKaydet}
          >
            {t("ortakKaydet")}
          </Dugme>
        </div>
      </Modal>

      <Modal
        acik={jeton !== null}
        baslik={t("akilliEvOlayJetonu")}
        onKapat={() => setJeton(null)}
      >
        <div className="space-y-3">
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("akilliEvOlayJetonuUyari")}
          </p>
          <code data-test="akilli-ev-jeton-degeri">{jeton}</code>
        </div>
      </Modal>

      <Modal
        acik={cihazForm}
        baslik={t("akilliEvCihazEkle")}
        onKapat={() => setCihazForm(false)}
      >
        <div className="space-y-3">
          <AlanSarmal etiket={t("ortakAd")}>
            {(alanProps) => (
              <Alan
                {...alanProps}
                data-test="akilli-ev-cihaz-ad"
                value={cAd}
                onChange={(e) => setCAd(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("akilliEvTur")}>
            {(alanProps) => (
              <Secim
                {...alanProps}
                data-test="akilli-ev-cihaz-tip"
                value={cTip}
                onChange={(e) => setCTip(e.target.value)}
              >
                {TIPLER.map((tip) => (
                  <option key={tip} value={tip}>
                    {t(TIP_ETIKET[tip])}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("akilliEvKonum")}>
            {(alanProps) => (
              <Alan
                {...alanProps}
                data-test="akilli-ev-cihaz-alan"
                value={cAlan}
                onChange={(e) => setCAlan(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("akilliEvDisKimlik")}>
            {(alanProps) => (
              <Alan
                {...alanProps}
                data-test="akilli-ev-cihaz-kimlik"
                value={cKimlik}
                onChange={(e) => setCKimlik(e.target.value)}
              />
            )}
          </AlanSarmal>
          <Dugme
            type="button"
            tur={BIRINCIL}
            data-test="akilli-ev-cihaz-kaydet"
            onClick={cihazKaydet}
          >
            {t("ortakKaydet")}
          </Dugme>
        </div>
      </Modal>

      <Modal
        acik={senForm}
        baslik={t("akilliEvSenaryoEkle")}
        onKapat={() => setSenForm(false)}
      >
        <div className="space-y-3">
          <AlanSarmal etiket={t("akilliEvOlay")}>
            {(alanProps) => (
              <Secim
                {...alanProps}
                data-test="akilli-ev-senaryo-olay"
                value={sOlay}
                onChange={(e) => setSOlay(e.target.value)}
              >
                {OLAYLAR.map((o) => (
                  <option key={o} value={o}>
                    {t(OLAY_ETIKET[o])}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("ortakAd")}>
            {(alanProps) => (
              <Secim
                {...alanProps}
                data-test="akilli-ev-senaryo-cihaz"
                value={sCihaz}
                onChange={(e) => setSCihaz(e.target.value)}
              >
                {cihazListe.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.ad}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("akilliEvEylem")}>
            {(alanProps) => (
              <Secim
                {...alanProps}
                data-test="akilli-ev-senaryo-eylem"
                value={sEylem}
                onChange={(e) => setSEylem(e.target.value)}
              >
                {EYLEMLER.map((e) => (
                  <option key={e} value={e}>
                    {t(EYLEM_ETIKET[e])}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <Dugme
            type="button"
            tur={BIRINCIL}
            data-test="akilli-ev-senaryo-kaydet"
            onClick={senaryoKaydet}
          >
            {t("ortakKaydet")}
          </Dugme>
        </div>
      </Modal>

      {diyalog}
    </div>
  );
}
