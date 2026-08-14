"use client";

// (P126.5) YÖNETİM İLETİŞİM — salt okuma kartı.
//
// Sunucu yalnız GET sunuyor: kart, yöneticilerin kendi profillerinden ve
// tesisin `yonetim_email`inden TÜRETİLİR. Buraya bir düzenleme formu
// koymak, aynı veriyi iki yerden yönetilebilir gösterirdi.
import useSWR from "swr";

import {
  BosDurum,
  HataDurumu,
  IskeletMetin,
  Kart,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris } from "@/lib/telefon";

type Yonetici = {
  user_id: string;
  ad_soyad: string;
  telefon: string | null;
  avatar_url: string | null;
};
type Kart = { yoneticiler: Yonetici[]; yonetim_email: string | null };

export default function YonetimIletisimPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<Kart>(
    "/api/yonetici-iletisim",
    jsonFetcher,
  );
  const yoneticiler = data?.yoneticiler ?? [];

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("yonetimIletisimBaslik")}
      </h1>
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}

      {data?.yonetim_email ? (
        <Kart className="space-y-1">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("yonetimIletisimEposta")}</h2>
          <a className="underline" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }} href={`mailto:${data.yonetim_email}`}>
            {data.yonetim_email}
          </a>
        </Kart>
      ) : null}

      {!isLoading && !error && yoneticiler.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("yonetimIletisimYok")} />
        </Kart>
      ) : null}

      {yoneticiler.map((y) => (
        <Kart key={y.user_id} className="space-y-1">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{y.ad_soyad}</h2>
          {/* NUMARA `aranabilir` RIZASINA BAKMAZ — ve bu BILINCLIDIR:
              `yonetici` bir HIZMET rolu; numarayi tesis kurulurken admin
              girer ve sakinin yonetime ulasabilmesi urun geregidir. Kapiyi
              SUNUCU koyar (routers/yonetici_iletisim.py; contracts/auth.md
              C1a istisnasi) — istemcide ikinci bir riza suzgeci eklemek,
              sunucunun bilerek dondurdugu numarayi sessizce gizlerdi. */}
          {y.telefon ? (
            <a className="underline" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }} href={`tel:${y.telefon}`}>
              {telefonGiris(y.telefon)}
            </a>
          ) : (
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("yonetimIletisimTelefonYok")}</p>
          )}
        </Kart>
      ))}
    </div>
  );
}
