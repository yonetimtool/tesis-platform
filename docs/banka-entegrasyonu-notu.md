# Banka entegrasyonu — değerlendirme notu (kod yok)

> MASTER-PLAN **P29**: *"bank API integration stays a doc note, not code"*.
> Bu belge neyin **yapıldığını**, neyin **bilinçli olarak yapılmadığını** ve
> gerçek entegrasyona geçilirse hangi kararların önce verilmesi gerektiğini
> yazar.

## Şu an ne var

**Ekstre eşleştirme önerisi** (`POST /finans/banka-eslestir`). Panel bir
banka ekstresini (Excel/CSV) okur, satırları **yapılandırılmış** olarak
gönderir; sunucu açık borcu olan kişilerle eşleştirip **öneri** döner.
Kullanıcı tek tıkla tahsilata çevirir.

**Öneri, otomatik tahsilat değildir.** Banka açıklaması serbest metindir
("HAVALE", "FAST", "A. ŞAHİN ODEME") ve yanlış eşleşen bir satır
**başkasının borcunu kapatıp gerçek borçlunun borcunu açık bırakırdı** —
sonradan fark edilmesi zor, düzeltmesi (iade + yeniden tahsilat) pahalı bir
hatadır. İki aday aynı puanı alırsa **öneri hiç üretilmez**: boş bırakmak,
yanlış eşleştirmekten iyidir.

Puanlama (toplanabilir, en fazla 100): ad tam geçer **+60**, soyad geçer
**+30**, tutar borca tam eşit **+40**, tutar borcun altında **+10**. 40'ın
altı döndürülmez.

Ad karşılaştırması **aksansız ve büyük harfe** indirgenir. Türkçe'ye özgü
tuzak: `İ`nin küçüğü `i` **değil** `i̇`dir; bu yüzden önce büyük harfe
çevirip aksan ayıklanır — ters sırada "ŞAHİN" ile "Sahin" eşleşmez.

## Neden API entegrasyonu yazılmadı

1. **Tek bir "banka API'si" yok.** Her banka kendi sözleşmesi, kendi kimlik
   akışı (bazıları mTLS, bazıları OAuth, bazıları IP kısıtlı SFTP) ve kendi
   alan adlarıyla gelir. Ortak bir soyutlama, **ilk gerçek bankayı görmeden**
   yazılırsa ikinci bankada yeniden yazılır.
2. **Kurumsal sözleşme gerektirir.** Site yönetiminin bankasıyla "hesap
   hareketleri servisi" sözleşmesi olmadan test ortamı bile açılmaz. Bu bir
   **[KEREM]/[DIŞ]** işidir, kod işi değil.
3. **Kimlik bilgisi saklama kararı verilmemiş.** Banka kimlik bilgileri
   tenant başına saklanacaksa şifreleme, rotasyon ve KVKK sorumluluğu ayrı
   bir tasarım gerektirir (P36'nın rıza kapısıyla birlikte düşünülmeli).
4. **Ekstre yükleme zaten çalışıyor.** Günlük operasyonun ihtiyacı olan şey
   "hareketleri görmek ve tahsilata çevirmek"tir; bunu ekstre yüklemesi
   **bugün** karşılıyor. API yalnızca elle yüklemeyi ortadan kaldırır —
   değerli ama **engelleyici değil**.

## Dosya ayrıştırma neden sunucuda değil

XLSX ayrıştırma bir **saldırı yüzeyidir**: zip bombası, XXE, formül
enjeksiyonu. Panel dosyayı zaten okuyup kullanıcıya önizleme göstermek
zorunda; sunucuya **yapılandırılmış satır listesi** gönderir ve sunucu her
satırı doğrular. Aynı gerekçe P28'in borç içe aktarımı için de geçerlidir.

## Gerçek entegrasyona geçilirse — önce verilecek kararlar

| Karar | Neden önce |
|---|---|
| Hangi banka | Soyutlama ancak bir gerçek örnekten sonra doğru çıkar |
| Çekme mi, itme mi (polling / webhook) | Zamanlama, tekrar deneme ve mükerrer koruması tasarımı buna bağlı |
| Kimlik bilgisi nerede | Tenant başına şifreli saklama ayrı bir migration + rotasyon akışı |
| Mükerrer koruması | Banka referans no benzersiz mi; değilse (tarih, tutar, açıklama) üçlüsü |
| Otomatik tahsilat eşiği | Hangi güven puanının üstünde insan onayı atlanabilir — **varsayılan: hiçbiri** |

Son satır önemli: entegrasyon gelse bile **otomatik tahsilatı varsayılan
açmak yanlış olur**. Yanlış eşleşme sessizce yanlış kişiyi borçlu bırakır;
insan onayı bu maddede bilinçli bir güvenlik payıdır.
