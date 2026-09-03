# P207 — Vardiya planlama genişletme + bildirim sesi

## §1 — AY BAZINDA TOPLU VARDİYA PLANLAMA

### Ölçüm: P205 nereye kadar gidiyordu

P205 §2'nin hızlı ekleme penceresi **tek kişi + tek saat aralığı + tarih
aralığı** alıyordu (`POST /vardiya-plani/toplu`). Ay ölçeğinde eksik olan
üç şey vardı: (a) düzensiz gün seçimi ("tüm pazartesiler"), (b) günü
birden çok vardiyaya bölme, (c) toplu işlemi geri alma.

### K1.1 — Gün seçimi SET, aralık değil

Seçim istemcide `Set<string>` olarak tutulur ve sunucuya **gün listesi**
gider. Aralık (başlangıç–bitiş) göndermek, "tüm pazartesiler" gibi
düzensiz bir seçimi **anlatamazdı** — ve seçimi aralıklara bölüp N istek
atmak, çakışma raporunu N parçaya bölerdi.

Üç seçim yolu: tıklama (aç/kapa), **sürükleme** (basılı tutup gezmek
aralık seçer) ve **hafta günü kalıbı** (Pazartesi… Pazar düğmeleri).
Otuz sütunluk bir şeritte pazartesileri tek tek tıklamak, dört-beş
tıklama ve her birinde yanlış sütuna basma ihtimaliydi.

Seçim **görsel olarak belirgin**: dolgu + sol kenarlık + `aria-pressed`.
Silik bir işaret, otuz sütunluk şeritte göz taramasıyla bulunamazdı.

Araç çubuğu **yalnız AY görünümünde** çizilir: gün/hafta görünümünde bir
avuç gün vardır ve toplu planlama orada anlamlı değil.

### K1.2 — Kalıp: JSONB dilimler, ayrı tablo değil (göç 0099)

`vardiya_kalibi(ad, dilimler JSONB, aktif)`. Dilimler ayrı tabloya
bölünmedi: hep **birlikte** okunup **birlikte** yazılıyorlar, bağımsız
bir yaşamları yok (kalıpsız dilim anlamsız) ve tek tek sorgulanmıyorlar;
sıra önemli ve JSONB dizisi sırayı zaten taşıyor. CHECK: 1–6 dilim (boş
kalıp uygulandığında hiçbir şey olmaz ve kullanıcı sebebini anlayamazdı;
üst sınır ise tek istekle yüzlerce vardiya üretilmesini engelliyor).

Kalıp **kaydetmek opsiyonel**: tek seferlik plan için `dilimler` doğrudan
gönderilebilir. Bir kerelik plan için kalıcı tanım üretmek, tanım
listesini şişirirdi. Aynı ad iki kez kullanılamaz (409) — ay başında
"hangisiydi" sorusu yanıtlanamaz olurdu.

Kalıp silinince **ondan oluşmuş planlar kalır**: kalıp bir şablondur,
plan satırlarının ona bağlı bir yaşamı yok (geri alma `parti_id` ile).

### K1.3 — Rotasyon: EVET, ama yalnız "haftalık" ve tek kaydırma

**Destekleniyor.** Güvenlik sektörünün standart kalıbı: A ekibi bu hafta
gündüz, gelecek hafta gece. Desteklemeseydik yönetici ya aynı ayı iki kez
planlar (önce A gündüz, sonra B gündüz) ya da her hafta elle değiştirirdi
— ve elle değiştirilen her hafta, bir haftanın atlanma ihtimalidir.

**Neden yalnız bu biçim:** üçlü/dörtlü rotasyon, ileri/geri yön, "iki gün
çalış bir gün izin" gibi desenler var ama her biri **başka** bir kural.
Hepsini tek parametreye sığdırmak, kullanıcının anlamadığı bir kutu
üretirdi. Buradaki söz net: her hafta atamalar **bir dilim ileri** kayar.
Ötekiler için kalıp iki kez uygulanır (ayrı partiler, ayrı geri alma).

### K1.4 — Önizleme ayrı uç DEĞİL

`kuru=true` hiçbir şey yazmaz ve **aynı** hesabı döner. Ayrı bir
"önizleme" ucu yazmak, iki kod yolunun ayrışma riskiydi: sonuç
önizlemede başka, kaydetmede başka çıkardı — ve kullanıcı buna ancak
yazdıktan sonra güvenmeyi bırakırdı. Ekranda "Önizle" ve "Uygula" ayrı
düğmeler; önizleme kaç vardiya oluşacağını söyler (kabul kriteri 4).

### K1.5 — Çakışma sessizce atlanmaz (P205 kuralı korundu)

Çakışma varsa ve `cakisanlari_atla=false` ise **hiçbir şey yazılmaz**;
yanıt hangi **gün/dilim/kişi** çakıştığını satır satır söyler. Ekran ilk
on satırı listeler ve "çakışanlar hariç uygula" düğmesi sunar.

`zaten_var` ayrı bir durum: kalıbı ikinci kez uygulamak (bir gün ekleyip
yeniden çalıştırmak) mevcut satırları **hata gibi göstermemeli**.

### K1.6 — Geri alma: `parti_id` (istekteki KRİTİK şart)

Aynı istekte yazılan satırlar aynı `parti_id`yi taşır (göç 0099, kısmi
indeks: `parti_id IS NOT NULL`). Geri alma o kimliğe bakar.

**Neden `created_at` aralığı değil:** iki yönetici aynı dakika içinde iki
ayrı toplu işlem yapabilir ve zaman aralığıyla geri almak, ötekinin
satırlarını da iptal ederdi.

**Silmez, `iptal` işaretler** (P203 kuralı) ve **yalnız hâlâ `planli`
olan** satırlara dokunur: parti sonrası elle çıkarılmış satırları geri
getirmek, yöneticinin aradaki kararını sessizce ezmek olurdu. İkinci kez
geri alma 404.

Ekranda "Son toplu işlemi geri al" düğmesi yalnız son parti varken
görünür ve geri alındıktan sonra kaybolur.

### Ölçüm

Backend `test_p207_kalip.py` **15 test**: kalıp tanımı/tekrar kullanım,
kalıpsız uygulama, önizlemenin yazmaması, gün×dilim sayısı, gün aşırı
dilimin ertesi güne taşması (P205 korundu), düzensiz gün seçimi, çakışma
+ "hariç uygula", `zaten_var`, haftalık rotasyonun kaydırması, rotasyonsuz
sabitlik, geri alma, partiler arası bağımsızlık, saha rolünün 403 alması,
başka tesisin personelinin atanamaması.

Web `p207-kalip.dom.test.ts` **10 test**: araç çubuğunun yalnız ay
görünümünde çıkması, tıklama/hafta günü kalıbı/temizleme, seçim yokken
düğmenin pasifliği, `kuru=true` önizleme, uygulama gövdesi (günler +
atamalar + rotasyon), çakışma listesi + hariç uygula, geri alma.

**Kilit kanıtı:** (a) çakışma dalı kaldırıldı → `CAKISMA_SESSIZCE_ATLANMAZ`
düştü; (b) rotasyon kaydırması sıfırlandı → `HAFTALIK_ROTASYON` düştü;
(c) web'de "Önizle" doğrudan yazacak şekilde bozuldu → önizleme testi
düştü. Üçü de geri alındı.

Göç 0099 downgrade→upgrade doğrulandı. Rol matrisine 5 satır eklendi
(kalıp okuma sahaya da açık — "bir sonraki vardiyada kim var" sorusu
sahanın sorusu; yazma yalnız admin+yönetici).

**Ölçemediğim:** gerçek tarayıcıda fare sürükleme hissi (jsdom'da
`mousedown`/`mouseenter` olayları tetikleniyor ama gerçek sürükleme
eşiği/ivmesi ölçülmedi).
