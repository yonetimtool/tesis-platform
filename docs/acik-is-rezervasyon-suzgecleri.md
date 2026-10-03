# Açık iş — mobil rezervasyon süzgeçleri cihazda

**Durum:** AÇIK. Karar (P253 Aşama 2, kullanıcı): şimdilik cihazda kalsın,
sunucuya taşınması bu belgede not olarak durur.

## Bugünkü durum

* P253 Aşama 1'de mobil rezervasyon yönetimine **alan**, **durum** ve
  **tarih** süzgeçleri eklendi
  (`mobile/lib/src/features/rezervasyon/presentation/rezervasyon_screen.dart`,
  `_suzgecSeridi`).
* Süzgeç, sunucudan gelen listeye **cihazda** uygulanıyor.
* Web rezervasyon yönetimi aynı süzgeçleri gösteriyor.

## Neden sorun olabilir

* **Sayfalama:** liste tek sayfa geliyorsa sorun yok. Kayıt sayısı sayfa
  sınırını aşarsa cihazdaki süzgeç yalnız ilk sayfayı süzer. Kullanıcı "bu
  alanda rezervasyon yok" görür ama sonraki sayfada vardır. Ses çıkarmayan
  bir yanlış sonuç olur.
* **Veri:** kullanıcının görmeyeceği satırlar da telefona iner.

## Taşıma notu (yapılacağında)

1. **Sunucu hazır:** liste ucu (`backend/app/routers/reservations.py`
   `list_reservations`) `durum`, `alan_id` ve `tarih` parametrelerini
   ZATEN alıyor (ölçüldü). İş yalnız mobil tarafta.
2. Mobil bu parametreleri göndersin; cihazdaki süzgeç kalksın (web ne gönderiyorsa aynısı).
3. Kilit: süzgeçli istek gövdesi/sorgusu taklit HTTP adaptöründe ölçülsün.
   Sunucu tarafında "sayfa sınırını aşan listede süzgeç doğru" testi yazılsın.

**Tetik:** bir tesiste rezervasyon listesi sayfa sınırına yaklaşırsa, ya da
Aşama 3'te rezervasyon ekranına yeniden dokunulursa.
