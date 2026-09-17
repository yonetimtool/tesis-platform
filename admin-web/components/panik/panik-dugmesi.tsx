"use client";

/**
 * (P240 §1) PANIK DUGMESI — KORUMALI ALANIN HER SAYFASINDA.
 *
 * =========================================================================
 * NEDEN DUZENDE (layout), SAYFADA DEGIL
 * =========================================================================
 * Istek: "web'de de her sayfadan erisilebilsin". Acil durumda kullanici
 * hangi sayfadaysa oradadir; onu once bir menuye, sonra bir sayfaya
 * goturmek, alarmin geç kalmasidir. Duzende TEK KEZ cizilir.
 *
 * =========================================================================
 * NEDEN SABIT (fixed) BIR DUGME
 * =========================================================================
 * Ust bara koymak, dar ekranda menuye katlanmasi demekti (P240 §5a'da
 * olculen kusurun aynisi). Sag ALT kose: fare ve bassparmak icin en
 * yakin kose, ve sayfa iceriginin uzerinde kalir.
 *
 * KIRMIZI ve KOSESIZ DEGIL: `tehlike` tonu tasarim sisteminden gelir —
 * "acil" rengi burada UYDURULMAZ, token'dan okunur.
 *
 * =========================================================================
 * GERI SAYIM ISTEMCIDE, KARAR SUNUCUDA
 * =========================================================================
 * Dugmeye basilinca alarm SUNUCUDA hemen yazilir (`beklemede`) ve
 * istemci `iptal_penceresi_sn` boyunca geri sayar. Sayim bitince
 * ISTEMCI HICBIR SEY YAPMAZ — yayini sunucudaki gecikmeli gorev yapar.
 *
 * Bu ayrim onemli: istemcinin sekmesi kapansa, ag kopsa ya da tarayici
 * uyusa bile alarm GIDER. Yayini "sayim bitince ikinci bir istek at"
 * diye kurmak, tam da acil durumda en kirilgan yere (istemcinin ayakta
 * kalmasina) bagimli olurdu.
 */
import { useCallback, useEffect, useRef, useState } from "react";

import { Dugme, Modal } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/** Rol -> tetikleyebilecegi tipler. Sunucudaki `TETIKLEYEBILIR` AYNASI. */
const TIPLER: { tip: string; roller: string[]; anahtar: SozlukAnahtari }[] = [
  { tip: "sakin", roller: ["resident"], anahtar: "panikTipSakin" },
  {
    tip: "guvenlik",
    roller: ["security", "guvenlik_amiri", "tesis_gorevlisi", "yonetici", "admin"],
    anahtar: "panikTipGuvenlik",
  },
  {
    tip: "yonetici_anons",
    roller: ["yonetici", "admin"],
    anahtar: "panikTipAnons",
  },
];

const TEHLIKE = "tehlike" as const;
const IKINCIL = "ikincil" as const;

type Alarm = { id: string; durum: string; iptal_penceresi_sn: number };

export function PanikDugmesi({ rol }: { rol: string | null }) {
  const t = useT();
  const toast = useToast();
  const [acik, setAcik] = useState(false);
  const [alarm, setAlarm] = useState<Alarm | null>(null);
  const [kalan, setKalan] = useState(0);
  const [bekliyor, setBekliyor] = useState(false);
  const sayacRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const izinli = TIPLER.filter((x) => rol !== null && x.roller.includes(rol));

  const sayaciDurdur = useCallback(() => {
    if (sayacRef.current !== null) {
      clearInterval(sayacRef.current);
      sayacRef.current = null;
    }
  }, []);

  useEffect(() => sayaciDurdur, [sayaciDurdur]);

  async function tetikle(tip: string) {
    setBekliyor(true);
    try {
      const y = (await apiSend("/api/panik", "POST", { tip })) as Alarm;
      setAlarm(y);
      setKalan(y.iptal_penceresi_sn);
      sayaciDurdur();
      sayacRef.current = setInterval(() => {
        setKalan((k) => {
          if (k <= 1) sayaciDurdur();
          return Math.max(0, k - 1);
        });
      }, 1000);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  async function iptal() {
    if (!alarm) return;
    setBekliyor(true);
    try {
      const y = (await apiSend(`/api/panik/${alarm.id}/iptal`, "POST", {})) as Alarm;
      // `iptal` (kimse rahatsiz edilmedi) ile `yanlis_alarm` (edildi)
      // AYRI mesaj alir: kullanici ne olduğunu bilmeli.
      toast.success(
        y.durum === "iptal" ? t("panikIptalEdildi") : t("panikYanlisAlarmGonderildi"),
      );
      setAlarm(null);
      setAcik(false);
      sayaciDurdur();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  if (izinli.length === 0) return null;

  return (
    <>
      <div className="fixed bottom-4 end-4 z-40 print:hidden">
        <Dugme
          type="button"
          tur={TEHLIKE}
          data-test="panik-ac"
          aria-label={t("panikBaslik")}
          onClick={() => setAcik(true)}
        >
          {t("panikKisa")}
        </Dugme>
      </div>

      <Modal
        acik={acik}
        onKapat={() => {
          // ALARM BASLAMISSA MODAL KAPANMAZ: geri sayimi gizlemek,
          // kullanicinin iptal edemeden alarmin gitmesi demekti.
          if (alarm) return;
          setAcik(false);
        }}
        baslik={t("panikBaslik")}
      >
        {alarm ? (
          <div className="space-y-3" data-test="panik-geri-sayim">
            <p style={{ fontSize: "var(--yz-fs-h2)" }}>
              {kalan > 0
                ? t("panikGonderiliyor", { n: kalan })
                : t("panikGonderildi")}
            </p>
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
              {t("panikIptalAciklama")}
            </p>
            <Dugme
              type="button"
              tur={IKINCIL}
              data-test="panik-iptal"
              disabled={bekliyor}
              onClick={() => void iptal()}
            >
              {t("panikIptalEt")}
            </Dugme>
          </div>
        ) : (
          <div className="space-y-3">
            {/* YASAL SINIR — DUGMEYE BASMADAN ONCE, her seferinde.
                Kucuk yazi degil, birinci satir: "bu sistem 112/155
                yerine gecmez" cumlesi alarmi BASTIKTAN SONRA
                gosterilseydi, en kritik anda okunmazdi. */}
            <p
              data-test="panik-yasal"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {t("panikYasalUyari")}
            </p>
            {izinli.map((x) => (
              <Dugme
                key={x.tip}
                type="button"
                tur={TEHLIKE}
                tamGenislik
                disabled={bekliyor}
                data-test={`panik-tip-${x.tip}`}
                onClick={() => void tetikle(x.tip)}
              >
                {t(x.anahtar)}
              </Dugme>
            ))}
          </div>
        )}
      </Modal>
    </>
  );
}
