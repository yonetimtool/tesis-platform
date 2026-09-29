"""(P249 §2) TATBIKAT RAPORU — PDF.

Ekrandaki raporla AYNI kaynaktan (`TatbikatRaporOut`): ayni rakamlar iki
yerde farkli cikmasin. Kurumsal PDF sablonu (`rapor_ciktilari.pdf_uret`)
kullanilir — site adi, tarih damgasi, "Sayfa n / m".

SIRA: once YARDIM isteyen, sonra YANITSIZ, en son GUVENDE daireler —
raporu okuyan kisinin ilk sorusu "kime gitmemiz gerekirdi".
"""
from __future__ import annotations

from .rapor_ciktilari import pdf_uret
from .raporlar import RaporSonuc, Sutun
from .schemas import TatbikatRaporOut

#: PDF basliklari — istegin dilinde. Rapor yoneticiye aittir; sakine
#: gitmez, bu yuzden yalniz basliklar cevrilir (adlar ve daireler ozel ad).
_M: dict[str, dict[str, str]] = {
    "tr": {"blok": "Blok", "daire": "Daire", "kisi": "Kişi", "yanit": "Yanıt",
           "sure": "Yanıt süresi (sn)", "guvende": "Güvende", "yardim": "Yardım istedi",
           "yok": "Yanıt yok", "personel": "Personel", "ozet":
           "{alici} kişiye gitti · {goruldu} açtı · {guvende} güvende · {yardim} yardım istedi · {yanitsiz} yanıtsız · push kabul: {gonderildi}/{denenen}",
           "ort": "Ortalama yanıt: {n} sn"},
    "en": {"blok": "Block", "daire": "Unit", "kisi": "Person", "yanit": "Response",
           "sure": "Response time (s)", "guvende": "Safe", "yardim": "Asked for help",
           "yok": "No response", "personel": "Staff", "ozet":
           "Sent to {alici} · {goruldu} opened · {guvende} safe · {yardim} asked for help · {yanitsiz} no response · push accepted: {gonderildi}/{denenen}",
           "ort": "Average response: {n} s"},
    "de": {"blok": "Block", "daire": "Wohnung", "kisi": "Person", "yanit": "Antwort",
           "sure": "Antwortzeit (s)", "guvende": "In Sicherheit", "yardim": "Hilfe angefordert",
           "yok": "Keine Antwort", "personel": "Personal", "ozet":
           "An {alici} gesendet · {goruldu} geöffnet · {guvende} sicher · {yardim} Hilfe · {yanitsiz} ohne Antwort · Push angenommen: {gonderildi}/{denenen}",
           "ort": "Durchschnittliche Antwort: {n} s"},
    "fr": {"blok": "Bloc", "daire": "Logement", "kisi": "Personne", "yanit": "Réponse",
           "sure": "Délai de réponse (s)", "guvende": "En sécurité", "yardim": "A demandé de l’aide",
           "yok": "Pas de réponse", "personel": "Personnel", "ozet":
           "Envoyé à {alici} · {goruldu} ouverts · {guvende} en sécurité · {yardim} aide · {yanitsiz} sans réponse · push acceptés : {gonderildi}/{denenen}",
           "ort": "Réponse moyenne : {n} s"},
    "es": {"blok": "Bloque", "daire": "Vivienda", "kisi": "Persona", "yanit": "Respuesta",
           "sure": "Tiempo de respuesta (s)", "guvende": "A salvo", "yardim": "Pidió ayuda",
           "yok": "Sin respuesta", "personel": "Personal", "ozet":
           "Enviado a {alici} · {goruldu} abiertos · {guvende} a salvo · {yardim} ayuda · {yanitsiz} sin respuesta · push aceptados: {gonderildi}/{denenen}",
           "ort": "Respuesta media: {n} s"},
    "ar": {"blok": "المبنى", "daire": "الوحدة", "kisi": "الشخص", "yanit": "الرد",
           "sure": "زمن الرد (ث)", "guvende": "بأمان", "yardim": "طلب المساعدة",
           "yok": "لا رد", "personel": "الموظفون", "ozet":
           "أُرسل إلى {alici} · فتحه {goruldu} · {guvende} بأمان · {yardim} طلبوا المساعدة · {yanitsiz} بلا رد · قُبل الإشعار: {gonderildi}/{denenen}",
           "ort": "متوسط الرد: {n} ث"},
    "ru": {"blok": "Блок", "daire": "Квартира", "kisi": "Человек", "yanit": "Ответ",
           "sure": "Время ответа (с)", "guvende": "В безопасности", "yardim": "Нужна помощь",
           "yok": "Нет ответа", "personel": "Персонал", "ozet":
           "Отправлено {alici} · открыли {goruldu} · {guvende} в безопасности · {yardim} нужна помощь · {yanitsiz} без ответа · push принято: {gonderildi}/{denenen}",
           "ort": "Среднее время ответа: {n} с"},
}


def tatbikat_pdf(r: TatbikatRaporOut, site_ad: str, dil: str) -> bytes:
    m = _M.get(dil) or _M["tr"]
    t = r.tatbikat
    d = r.durum
    satirlar: list[dict] = []
    if d is not None:
        for daire in d.daireler:
            for k in daire.kisiler:
                satirlar.append({
                    "blok": daire.blok or "",
                    "daire": daire.daire_no or "",
                    "kisi": k.ad,
                    "yanit": m.get(k.yanit or "yok", m["yok"]),
                    "sure": k.yanit_suresi_sn if k.yanit_suresi_sn is not None else "",
                })
        for k in d.personel:
            satirlar.append({
                "blok": m["personel"], "daire": "", "kisi": k.ad,
                "yanit": m.get(k.yanit or "yok", m["yok"]),
                "sure": k.yanit_suresi_sn if k.yanit_suresi_sn is not None else "",
            })
    ozet = ""
    if d is not None:
        ozet = m["ozet"].format(
            alici=d.alici, goruldu=d.goruldu, guvende=d.guvende, yardim=d.yardim,
            yanitsiz=d.yanitsiz, gonderildi=r.push_gonderildi, denenen=r.push_denenen,
        )
        if d.ortalama_yanit_sn is not None:
            ozet += " · " + m["ort"].format(n=d.ortalama_yanit_sn)
    kapsam = t.blok if t.kapsam == "blok" and t.blok else site_ad
    baslik = f"{t.baslik} — {kapsam}"
    sonuc = RaporSonuc(
        kod="tatbikat",
        baslik=baslik,
        sutunlar=[
            Sutun("blok", m["blok"]),
            Sutun("daire", m["daire"]),
            Sutun("kisi", m["kisi"], genislik=2),
            Sutun("yanit", m["yanit"]),
            Sutun("sure", m["sure"], tip="sayi"),
        ],
        satirlar=satirlar,
        toplamlar={"kisi": ozet} if ozet else {},
    )
    baslangic = t.basladi_at.date() if t.basladi_at else None
    return pdf_uret(sonuc, site_ad, baslangic, baslangic)
