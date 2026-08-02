# Yer tutucu / boş ekran süpürmesi (P116)

> App Store'da en sık ret gerekçelerinden biri "**özellik
> tamamlanmamış**"tır: dokunulduğunda hiçbir şey yapmayan düğme,
> "Yakında" yazan menü satırı, açıklamasız boş ekran. Bu belge, ölçümün
> **sonucunu** ve ölçümün **nasıl tekrarlanacağını** kaydeder.

## Ölçüm — 2026-08-02

Koşum: `flutter test test/yer_tutucu_supurmesi_test.dart`

| Ne arandı | Bulunan | Durum |
|---|---|---|
| Rotası olmayan gezinme kartı (`HizliErisimKart`, `OzetKutusu`) | **0** | Temiz |
| "Yakında" işaretli menü girişi (`BildirGiris.comingSoon`) | **0** | Temiz |
| Boş gövdeli `onPressed`/`onTap`/`onChanged` (ölü düğme) | **0** | Temiz |

**Yani düzeltilecek bir şey çıkmadı** — ama bu, ölçüm yapılmadan
bilinemezdi ve bundan sonra **geri gitmesi de engellendi** (test).

## "Yakında" metinleri neden duruyor?

`ortakYakinda` ve `ortakBolumYakinda` ARB anahtarları ile ana
ekranlardaki `_yakinda(...)` dalları **korunuyor**, çünkü bunlar bir
**savunmadır**: rotası eklenmeyi unutulmuş bir kart, sessizce hiçbir şey
yapmayan bir düğme yerine dürüst bir mesaj gösterir.

Bugün bu dallar **erişilemez** (yukarıdaki ölçüm) ve testler bunun böyle
kalmasını sağlıyor. Metinleri silmek, savunmayı da silmek olurdu.

## Ölçümün iki kez daraltılması (dürüstçe)

1. İlk yazımda tarama **uydurma tip adları** (`HomeKisayol`,
   `ModulKarti`) arıyordu — projede böyle tipler yok. Mutasyon denetimi
   yakaladı: tarama **hiçbir şey ölçmüyordu** ve yeşil renk yanıltıyordu.
2. Düzeltirken `HareketSatiri` de kapsama alındı ve kırmızı verdi; oysa o
   "Son Hareketler" **günlük satırıdır**, gezinme kartı değil — rotasının
   olmaması **doğrudur**. Kapsam, dokununca bir yere **gitmesi beklenen**
   iki kartla sınırlandı.

Ölçüm aracının kendisi de mutasyonla sınandı: bir karttan `rota:`
kaldırıldığında test **düşüyor**.

## Denetim tesisinde (P115) durum

Demo tesisinde görünen her şey çalışır: modül kartlarının hepsi bir
rotaya gider, "Yakında" satırı yoktur, ölü düğme yoktur. NFC gerektiren
tek akış (devriye turu) **simüle okutma** ile donanımsız gösterilebilir.

## Kapsam dışı — panel (admin-web)

Yönetim paneli App Store'a gönderilmiyor; bu süpürme **mobil uygulamayı**
kapsar. Panelin kendi boş-durum kilidi ayrıca var (P61: hata varken
"kayıt yok" gösterilmemesi).
