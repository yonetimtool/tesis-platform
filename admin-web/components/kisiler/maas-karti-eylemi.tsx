"use client";

/**
 * (P251 §8) PERSONEL SATIRINDA MAAS KARTI.
 *
 * Maas karti (`personel_kayit`) ile uygulama hesabi (`app_user`) AYRI
 * kayitlardir ve oyle kalir: her personelin hesabi yoktur (temizlik,
 * bahcivan), kartta da hesapta olmamasi gereken bilgiler (TC, ucret)
 * durur. Ama ikisi ayni kisi oldugunda BAGLANIRLAR (`app_user_id`) ve
 * fazla mesai ucreti bu bagdan okunur (P203 §5).
 *
 * OLCULEN KUSUR: bag sunucuda vardi ama hicbir ekran onu KURAMIYORDU.
 * Yonetici ayni kisiyi iki kez yaziyor ve mesai ekrani "ucret tanimsiz"
 * diyordu. Bu eylem:
 *   * bagli kart VARSA: "Maas karti" -> Finans › Maas kartlari,
 *   * YOKSA: "Maas karti olustur" -> hesabin adi, e-postasi ve telefonu
 *     ile DOLU ve BAGLI bir kart acar; yonetici yalniz ucreti girer.
 *
 * Tum satirlar TEK SWR anahtarini paylasir (kart listesi bir kez gelir).
 */
import { useRouter } from "next/navigation";
import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Dugme } from "@/components/ui";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { rolAdi } from "@/lib/roles";
import type { UserDetail, UserRow } from "@/lib/types";

export const MAAS_KARTLARI_UCU = "/api/tanimlar/personel-kayitlari?limit=200";
export const MAAS_KARTLARI_YOLU = "/finans/maas-kartlari";
const KUCUK = "kucuk" as const;

interface Kart {
  id: string;
  app_user_id: string | null;
}

export function MaasKartiEylemi({ kullanici }: { kullanici: UserRow }) {
  const t = useT();
  const router = useRouter();
  const toast = useToast();
  const [mesgul, setMesgul] = useState(false);
  const { data, mutate } = useSWR<{ items: Kart[] }>(MAAS_KARTLARI_UCU, jsonFetcher);
  if (!data) return null;
  const kart = data.items.find((k) => k.app_user_id === kullanici.id);

  if (kart) {
    return (
      <Dugme boy={KUCUK} onClick={() => router.push(`${MAAS_KARTLARI_YOLU}?kart=${kart.id}`)}>
        {t("maasKartiAc")}
      </Dugme>
    );
  }

  async function olustur() {
    setMesgul(true);
    try {
      // Telefon liste satirinda YOK (KVKK: numaralar toplu listelenmez);
      // tek kayit gorunumunden alinir.
      const ayrinti = await jsonFetcher<UserDetail>(`/api/users/${kullanici.id}`);
      const yeni = await apiSend<Kart>("/api/tanimlar/personel-kayitlari", "POST", {
        // `ad` TAM gorunen addir (soyad dahil).
        ad: kullanici.ad,
        email: kullanici.email || null,
        telefon: ayrinti.telefon ?? null,
        gorev: rolAdi(t, kullanici.role),
        app_user_id: kullanici.id,
      });
      await mutate();
      toast.success(t("maasKartiOlusturuldu"));
      router.push(`${MAAS_KARTLARI_YOLU}?kart=${yeni.id}`);
    } catch (e) {
      toast.error(alanliHataMetni(e, t("ortakHataOlustu")));
    } finally {
      setMesgul(false);
    }
  }

  return (
    <Dugme boy={KUCUK} disabled={mesgul} onClick={() => void olustur()}>
      {t("maasKartiOlustur")}
    </Dugme>
  );
}
