# Ekran görüntüsü çekim listesi (P117)

> **Çekim Kerem'de** ([KEREM]). Bu belge *ne* çekileceğini, *hangi
> hesapla* ve *hangi veriyle* çekileceğini satır satır söyler — böylece
> çekim sırasında "hangi ekrandı" diye geri dönülmez.

## Karar: ilk sürüm YALNIZ iPHONE

`TARGETED_DEVICE_FAMILY = 1` (P114). Gerekçe: iPad'i açmak,
göndermediğimiz bir cihaz için **ayrı ekran görüntüsü seti** ve **düzen
doğrulaması** istemek olurdu; denetçi iPad'de bozuk bir düzen görürse
reddeder. iPad desteği ayrı bir karar ve ayrı bir turdur.

Bu yüzden **iPad ekran görüntüsü gerekmez**.

## Gereken boyutlar

App Store Connect bugün **tek** set ister ve küçüğüne kendisi ölçekler;
yine de ikisini de çekmek en güvenlisidir:

| Set | Cihaz | Çözünürlük |
|---|---|---|
| 6.7" (zorunlu) | iPhone 15/16 Pro Max | 1290 × 2796 |
| 6.1" (önerilir) | iPhone 15/16 Pro | 1179 × 2556 |

**En fazla 10 görsel**; ilk 3'ü mağaza listesinde önce görünür — en
anlaşılır olanları başa koyun.

## Hazırlık

1. Demo tesisini tohumla (P115):
   `docker compose exec -e DEMO_PAROLA='…' api python -m scripts.demo_tenant`
2. Cihaz dilini **Türkçe** yap (TR mağaza için); İngilizce set gerekiyorsa
   aynı listeyi cihaz dili İngilizceyken tekrarla.
3. Cihazda **açık tema** kullan — koyu tema görselleri mağazada daha
   karanlık ve okunmaz görünüyor.
4. Durum çubuğunda tam saat, dolu pil, tam sinyal olsun.

## Çekim listesi (sırayla — mağazada bu sırayla görünsün)

| # | Ekran | Hesap | Nasıl gidilir | Görünmesi gereken veri |
|---|---|---|---|---|
| 1 | **Sakin ana ekran** | `sakin@demo…` | Giriş sonrası ilk ekran | Aidat kartı **dolu** (75,00 ₺), duyuru kartında "Havuz bakımı" |
| 2 | **Aidatım** | `sakin@demo…` | Ana ekran → Aidatım | Dönem + tutar + son ödeme tarihi görünür |
| 3 | **Talep/Arıza oluşturma** | `sakin@demo…` | Ana ekran → + → Talep/Arıza | Form **ortada** açılmış (P22a), başlık + açıklama dolu |
| 4 | **Duyurular** | `sakin@demo…` | Ana ekran → Duyurular | "Havuz bakımı" duyurusu açık |
| 5 | **Devriye turu / Turlarım** | `guvenlik@demo…` | Ana ekran → Turlarım | Tur penceresi + ilerleme çubuğu |
| 6 | **Kontrol noktaları** | `guvenlik@demo…` | Turlarım → Kontrol noktaları | Üç nokta listeli (Ana Kapı, Otopark, Bahçe) |
| 7 | **Görevler** | `gorevli@demo…` | Ana ekran → Görevler | En az bir görev satırı |
| 8 | **Yönetici panosu** | `yonetici@demo…` | Giriş sonrası ilk ekran | Özet kutuları **gerçek sayılarla** |
| 9 | **Talep yönetimi** | `yonetici@demo…` | Ana ekran → Talepler | En az bir talep, durum rozetiyle |
| 10 | **Ayarlar → dil** | herhangi | Ayarlar → Dil | Yedi dil listesi açık (çok dilliliği gösterir) |

## Kaçınılacaklar (ret sebebi olabilir)

* **Boş liste** görseli — "ürün çalışmıyor" izlenimi verir. Tohumlama
  bunun için var.
* Ekran görüntüsüne **Apple cihaz çerçevesi** çizip üstüne başka marka
  koymak.
* Görselde **fiyat/kampanya** vaadi ("ücretsiz", "%50 indirim").
* Gerçek kişi adı/telefonu görünen bir kayıt — demo verisi kullanın.
* Simüle okutma menüsünün göründüğü kare: bu **demo tesisine özel** bir
  geliştirme yolu; mağaza görselinde ürünün kalıcı bir özelliğiymiş gibi
  durmasın.

## Sonra

Görseller App Store Connect → **Media Manager**'a yüklenir. Metinler
(başlık, alt başlık, açıklama, anahtar kelimeler) bu turun kapsamı
dışında; hazır olduğunda ayrı bir kalem açılır.
