"use client";

// (P126.5) YÖNETİM İLETİŞİM — salt okuma kartı.
//
// Sunucu yalnız GET sunuyor: kart, yöneticilerin kendi profillerinden ve
// tesisin `yonetim_email`inden TÜRETİLİR. Buraya bir düzenleme formu
// koymak, aynı veriyi iki yerden yönetilebilir gösterirdi.
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, cardCls } from "@/components/form";
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
      <PageHeader title={t("yonetimIletisimBaslik")} />
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
      ) : null}

      {data?.yonetim_email ? (
        <section className={`${cardCls} space-y-1 p-4`}>
          <h2 className="font-medium">{t("yonetimIletisimEposta")}</h2>
          <a className="text-sm underline" href={`mailto:${data.yonetim_email}`}>
            {data.yonetim_email}
          </a>
        </section>
      ) : null}

      {!isLoading && !error && yoneticiler.length === 0 ? (
        <EmptyState title={t("yonetimIletisimYok")} />
      ) : null}

      {yoneticiler.map((y) => (
        <article key={y.user_id} className={`${cardCls} space-y-1 p-4`}>
          <h2 className="font-medium">{y.ad_soyad}</h2>
          {/* NUMARA `aranabilir` RIZASINA BAKMAZ — ve bu BILINCLIDIR:
              `yonetici` bir HIZMET rolu; numarayi tesis kurulurken admin
              girer ve sakinin yonetime ulasabilmesi urun geregidir. Kapiyi
              SUNUCU koyar (routers/yonetici_iletisim.py; contracts/auth.md
              C1a istisnasi) — istemcide ikinci bir riza suzgeci eklemek,
              sunucunun bilerek dondurdugu numarayi sessizce gizlerdi. */}
          {y.telefon ? (
            <a className="text-sm underline" href={`tel:${y.telefon}`}>
              {telefonGiris(y.telefon)}
            </a>
          ) : (
            <p className="text-sm text-muted">{t("yonetimIletisimTelefonYok")}</p>
          )}
        </article>
      ))}
    </div>
  );
}
