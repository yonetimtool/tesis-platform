package com.app.yonetiyor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * (P207 §2) BILDIRIM KANALLARI — sesin YASADIGI yer.
 *
 * ==========================================================================
 * NEDEN NATIVE, NEDEN BURADA
 * ==========================================================================
 * Android 8'den (API 26) beri bildirimin SESI KANALIN ozelligidir. FCM
 * govdesindeki `android.notification.channel_id` VAR OLAN bir kanali
 * secer; kanali OLUSTURMAZ. Kanal yoksa bildirim varsayilan kanala duser
 * ve o kanalin sesi yoktur — olculen sessizligin sebebi tam olarak buydu.
 *
 * `flutter_local_notifications` bagimliligi EKLENMEDI: bu dosyanin
 * yaptigi is uc kanal olusturmak ve plugin, uygulamanin hicbir yerinde
 * yerel bildirim gostermedigimiz icin sirf kanal acmak ugruna bir
 * bagimlilik olurdu.
 *
 * ==========================================================================
 * KANALIN SESI SONRADAN DEGISTIRILEMEZ — KIMLIKLER SURUMLU
 * ==========================================================================
 * Bir kanal olusturulduktan sonra sesi PROGRAMLA degistirilemez
 * (kullanici sistem ayarlarindan degistirebilir). Ses degisirse kimlik de
 * degisir: `..._v1` -> `..._v2` ve eskisi silinir. Yoksa kullanicinin
 * telefonunda eski kanal kalir ve "sesi degistirdim ama degismedi" olur.
 *
 * KIMLIKLER SUNUCUYLA AYNI: `backend/app/push_kanal.py`. Ayrisirsa sunucu
 * var olmayan bir kanala gonderir; bildirim GORUNUR ama SESSIZ olur —
 * yani kusur ancak sahada fark edilir. `test_p207_push_kanal.py` bu
 * dosyayi okuyup kimlikleri karsilastirir.
 */
class MainActivity : FlutterActivity() {

    companion object {
        // SUNUCUYLA AYNI OLMAK ZORUNDA (backend/app/push_kanal.py).
        const val KANAL_KRITIK = "yonetio_kritik_v2"
        const val KANAL_GENEL = "yonetio_genel_v2"
        const val KANAL_SESSIZ = "yonetio_sessiz_v2"

        /**
         * (P208 §2) GURULTU UYARISININ KENDI KANALI.
         *
         * Android'de ses KANALIN ozelligidir; "ayni kanaldan farkli ses"
         * diye bir sey yok. Ayirt edilebilir bir ses istiyorsak ayri
         * kanal SART — ve bu, kullaniciya sistem ayarlarinda ayri bir
         * satir da verir (gurultu uyarisini susturup vardiya
         * hatirlatmasini acik birakabilir).
         */
        const val KANAL_GURULTU = "yonetio_gurultu_v2"

        /**
         * (P210) VARDIYA HATIRLATMASININ KENDI KANALI.
         *
         * Vardiyasi YAKLASAN gorevliye giden anons. Ayri kanal olmasinin
         * sebebi P208'dekiyle ayni: Android'de ses KANALIN ozelligidir.
         */
        const val KANAL_VARDIYA = "yonetio_vardiya_v2"

        /**
         * (P210) ESKI KUSAK KANALLAR — silinecek.
         *
         * `_v1` kanallari SESSIZ (sistem sesi) donemden kalma. Silinmezse
         * kullanici sistem ayarlarinda IKI KUSAK kanal gorur ("Onemli
         * uyarilar" iki kez) ve hangisinin gecerli oldugunu anlayamaz.
         * Silme, kullanicinin O KANALDA yaptigi ayari da siler — ama
         * kanal zaten sessizdi ve yenisi ayri bir kanaldir; tasinabilecek
         * bir tercih yok.
         */
        val ESKI_KANALLAR = listOf(
            "yonetio_kritik_v1",
            "yonetio_genel_v1",
            "yonetio_sessiz_v1",
            "yonetio_gurultu_v1",
        )

        // ==================================================================
        // (P210) SES DOSYALARI STATIK REFERANSLA — `getIdentifier` DEGIL
        // ==================================================================
        // OLCULEN KUSUR: dosyalar `res/raw/`e konuldu, `flutter build apk
        // --release` sorunsuz gecti, AMA APK'DA YOKTULAR. Sebep: release
        // yapiminda KAYNAK KUCULTUCU (resource shrinker) calisiyor ve
        // `resources.getIdentifier(...)` bir CALISMA ZAMANI dizgi
        // aramasidir — kucultucu onu GOREMEZ, dosyalari "kullanilmiyor"
        // sayip ATAR.
        //
        // Kanit: `aapt2 dump resources app-release.apk` ciktisinda `raw`
        // TIPI HIC YOKTU; ara dizinlerde (`packaged_res`) dosyalar
        // duruyordu — yani kucultme adiminda dusuyorlardi.
        //
        // Bu sessiz bir kusurdur: kod calisir, kanal olusur, bildirim
        // gelir — yalnizca SES SISTEM SESIDIR. Ancak cihazda, kulakla
        // fark edilir.
        //
        // `R.raw.*` ise DERLEME ZAMANI referanstir: kucultucu gorur ve
        // dosya silinirse KOD DERLENMEZ. Sessiz kusur, derleme hatasina
        // donusur.
        val SES_BILDIRIM = R.raw.yonetio_bildirim
        val SES_GURULTU = R.raw.yonetio_gurultu
        val SES_VARDIYA = R.raw.yonetio_vardiya

        // Ad sabitleri SUNUCUYLA ESITLIK KILIDI icin duruyor
        // (`p207_kanal_kimlik_test.dart` bu dizgileri `push_kanal.py` ile
        // karsilastirir).
        const val OZEL_SES = "yonetio_bildirim"
        const val GURULTU_SES = "yonetio_gurultu"
        const val VARDIYA_SES = "yonetio_vardiya"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        kanallariKur()
    }

    /** Kaynak KIMLIGINDEN ses adresi (bkz. yukaridaki kucultucu notu). */
    private fun sesUri(kaynak: Int): Uri =
        Uri.parse("android.resource://$packageName/$kaynak")

    private fun kanallariKur() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        val ozellikler = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        // KRITIK: sikayet ve vardiya hatirlatmalari. IMPORTANCE_HIGH —
        // ekranin ustunde belirir ve SES CIKARIR; duyulmayan bir vardiya
        // hatirlatmasi hic gonderilmemis gibidir.
        val kritik = NotificationChannel(
            KANAL_KRITIK,
            getString(R.string.kanal_kritik_ad),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.kanal_kritik_aciklama)
            setSound(sesUri(SES_BILDIRIM), ozellikler)
            enableVibration(true)
        }

        // GENEL: duyuru, kargo, rezervasyon... Sistem sesi, normal onem.
        val genel = NotificationChannel(
            KANAL_GENEL,
            getString(R.string.kanal_genel_ad),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = getString(R.string.kanal_genel_aciklama)
            setSound(
                android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                ozellikler,
            )
        }

        // SESSIZ: kullanici sesli uyarilari KAPATTIGINDA sunucu buraya
        // gonderir. Kanalin sesi uygulama tarafindan sonradan
        // degistirilemedigi icin "sesi kapat" ancak BASKA BIR KANALA
        // gecerek yapilabilir.
        val sessiz = NotificationChannel(
            KANAL_SESSIZ,
            getString(R.string.kanal_sessiz_ad),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.kanal_sessiz_aciklama)
            setSound(null, null)
            enableVibration(false)
        }

        // (P208 §2) GURULTU: kendi sesi, yuksek onem. Sakin bildirimi
        // GORMEDEN ne oldugunu anlayabilmeli.
        val gurultu = NotificationChannel(
            KANAL_GURULTU,
            getString(R.string.kanal_gurultu_ad),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.kanal_gurultu_aciklama)
            setSound(sesUri(SES_GURULTU), ozellikler)
            enableVibration(true)
        }

        // (P210) VARDIYA: vardiyasi yaklasan gorevliye anons. HIGH —
        // gecikmis bir "vardiyan basliyor" bildirimi ANLAMSIZ olur.
        val vardiya = NotificationChannel(
            KANAL_VARDIYA,
            getString(R.string.kanal_vardiya_ad),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.kanal_vardiya_aciklama)
            setSound(sesUri(SES_VARDIYA), ozellikler)
            enableVibration(true)
        }

        mgr.createNotificationChannel(kritik)
        mgr.createNotificationChannel(gurultu)
        mgr.createNotificationChannel(vardiya)
        mgr.createNotificationChannel(genel)
        mgr.createNotificationChannel(sessiz)

        // ESKI KUSAGI TEMIZLE: iki kusak kanal, ayar ekraninda ayni ada
        // sahip iki satir demek.
        ESKI_KANALLAR.forEach { mgr.deleteNotificationChannel(it) }
    }
}
