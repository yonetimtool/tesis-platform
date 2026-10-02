# Açık iş — `test_rapor_kuyruk` tam koşuda kilitleniyor

**Durum:** KAPANDI 2026-10-02 (P252 §4). Ölçüm ve düzeltme aşağıda, en altta.

## Belirti

`tests/test_rapor_kuyruk.py::test_ISLERIM_yalniz_KENDI_islerimi_gosterir`
tam backend koşusunda **teardown'da** düşüyor:

```
ERROR at teardown of test_ISLERIM_yalniz_KENDI_islerimi_gosterir
E   psycopg.errors.DeadlockDetected: deadlock detected
```

* **P250'den beri her tam koşuda aynı test.** Ölçülen koşular: P250 sonu,
  P251 (2 kez), 1.9.0 paket öncesi.
* **Test gövdesi geçiyor**; düşen şey temizlik.
* Dosya tek başına **22/22 geçiyor**.

## Neden ayrı iş (ve neden ertelenmemeli)

Her tam koşu "1 hata" ile bitiyor ve bu hata artık bekleniyor. Bir gün aynı
satırda **gerçek** bir kırmızı belirirse "bilinen kilitlenme" sanılıp
geçilir; bu hata gerçek bir hatayı gizler. Ayrıca `EXITCODE=1` her koşuda
geldiği için tam koşu sonucu otomatik olarak "yeşil" diye
değerlendirilemiyor.

## Bilinenler ve kök neden adayı (DOĞRULANMADI)

* Temizlik `tests/conftest.py` `world` fikstüründe (`_sil`): admin rolünü
  düşürüp `DELETE FROM tenant WHERE id IN (a, b)` çalıştırıyor. Cascade
  ile tesisin bütün satırları siliniyor.
* Bu test (ve dosyadaki kuyruk testleri) rapor üretimini **Celery
  işçisine** kuyruklar (`202` + iş kimliği). Test bitince işçi o tesisin
  `rapor_is` satırını (ve raporun okuduğu tabloları) hâlâ işliyor
  olabilir.
* **Aday:** işçinin işi güncellemesi/okuması ile fikstürün cascade
  silmesi farklı sırayla satır kilidi alıyor → Postgres kilitlenmeyi
  tespit edip birini öldürüyor; ölen fikstür oluyor.
* Yalnız tam koşuda görülmesi, işçinin başka testlerden kalan işlerle
  yüklü ve yavaş olmasıyla uyumlu. Tek başına koşuda iş test bitmeden
  tamamlanıyor.

## Önerilen ölçüm ve çözüm sırası

1. **Ölç:** kilitlenme anında `pg_locks` + `pg_stat_activity` dökümü (ya da
   `log_lock_waits = on`, `deadlock_timeout` logu). İkinci işlemin işçi
   olduğu ve hangi tabloda çakıştığı doğrulanmalı.
2. **Test tarafı çözüm (tercih):** kuyruk testlerinde test bitmeden işin
   bitmesini bekle (iş durumunu `tamam/hata` olana kadar yokla). Ya da
   fikstür silmeden önce o tesisin bekleyen/çalışan işlerini iptal edip
   bitmesini beklesin.
3. **Ürün tarafı kontrol:** işçi silinmiş bir tesisin işini alırsa sessizce
   bırakıyor mu? Prod'da tesis silme nadir ama aynı yarış orada da var.
   Ölçülmeli.
4. **Kilit:** düzeltmeden sonra tam koşunun `EXITCODE=0` bitmesi. Gerekirse
   bu dosyayı 3 kez art arda tam koşuda doğrula.

## Yapılmayacak olan

Testi `skip`/`xfail` yapmak ya da teardown hatasını yutmak. Belirti
kaybolur, kök neden (ve olası ürün yarışı) kalır.


## Kapanış (P252 §4)

### Ölçüm

Postgres kilitlenme günlüğü (db konteyneri), beş tam koşunun beşinde aynı:

```
Process A: DELETE FROM tenant WHERE id IN ($1,$2)
Process B: UPDATE rapor_isi SET durum=..., dosya_key=..., dosya_adi=..., biten_at=... WHERE id=...
CONTEXT:  while deleting tuple (0,45) in relation "rapor_isi"
```

### Kök neden

Aday doğruydu, mekanizma daha ince:

* İşçi tek işlemde `uretiliyor` yazıyor, raporu üretiyor, MinIO'ya
  yüklüyor ve aynı satırı `hazir` yapıyordu.
* Satırın son sürümü aynı işleme ait olduğundan Postgres ikinci UPDATE'te
  yabancı anahtar denetimini **yeniden** çalıştırır (anahtar değişmese de)
  ve tenant/app_user satırında KEY SHARE kilidi ister.
* Fikstürün cascade silmesi o satırları tutarken işçinin kilitlediği
  `rapor_isi` satırını bekliyordu. İki işlem birbirini bekledi.

### Prod değerlendirmesi

Evet, aynı yarış prod'da da var:

* Tesis silme ve saklama temizliği sırasında üretimdeki bir iş kilitlenme
  verir.
* İkinci ve daha olası bir risk: üretim ve yükleme sırasında oturum
  "idle in transaction" kalıyordu. Göç 0074'ün 60 sn sınırı, ağır bir
  raporda oturumu keser ve iş anlamsız bir hatayla düşerdi.

### Düzeltme (`app/rapor_kuyruk.py`)

* Üç kısa işlem: `uretiliyor` yaz ve bitir; veriyi oku ve bitir; dosyayı
  işlem dışında üret ve yükle; sonucu ayrı işlemde yaz. Satır arada
  silindiyse iş sessizce `bulunamadi` döner.
* İlk adımda `FOR UPDATE`: eşzamanlı ikinci teslim bekler ve atlanır.
* **Yetim iş:** `uretiliyor` artık commit'li, işçi öldürülürse geri
  alınmaz. 30 dakikadan eski `uretiliyor` iş, yeniden teslimde yeniden
  üretilir (`task_acks_late`).

### Kilit

`tests/test_p252_rapor_isci_kilit.py`, eski koda karşı 2/3 düşer, yeni
kodla 3/3 geçer:

* Yükleme anında iş satırı başka bir işlemin `FOR UPDATE NOWAIT` alabileceği
  kadar kilitsiz olmalı.
* Üretim sırasında silinen iş sessizce bırakılmalı.
* Yetim iş yeniden üretilmeli, taze iş atlanmalı.

Tam koşu sonucu P252 doğrulama kaydında.
