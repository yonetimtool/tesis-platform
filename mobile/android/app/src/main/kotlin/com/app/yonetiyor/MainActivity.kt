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
        const val KANAL_KRITIK = "yonetio_kritik_v1"
        const val KANAL_GENEL = "yonetio_genel_v1"
        const val KANAL_SESSIZ = "yonetio_sessiz_v1"

        /**
         * (P208 §2) GURULTU UYARISININ KENDI KANALI.
         *
         * Android'de ses KANALIN ozelligidir; "ayni kanaldan farkli ses"
         * diye bir sey yok. Ayirt edilebilir bir ses istiyorsak ayri
         * kanal SART — ve bu, kullaniciya sistem ayarlarinda ayri bir
         * satir da verir (gurultu uyarisini susturup vardiya
         * hatirlatmasini acik birakabilir).
         */
        const val KANAL_GURULTU = "yonetio_gurultu_v1"

        /**
         * Ozel ses dosyasinin adi (`res/raw/yonetio_bildirim.<uzanti>`).
         * DOSYA HENUZ YOK: bulunamazsa SISTEM VARSAYILAN sesi kullanilir
         * (bkz. [sesUri]) — "ses yok" ile "ozel ses yok" ayni sey degil.
         */
        const val OZEL_SES = "yonetio_bildirim"

        /** (P208 §2) Gurultu uyarisinin AYRI sesi (`res/raw/`). */
        const val GURULTU_SES = "yonetio_gurultu"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        kanallariKur()
    }

    /**
     * Kaynak ADIYLA aranir: dosya pakete eklendiginde kod DEGISMEDEN
     * ozel ses devreye girer. Dosya yoksa SISTEM VARSAYILANI — "ses yok"
     * ile "ozel ses yok" ayni sey degil.
     */
    private fun sesUri(ad: String = OZEL_SES): Uri? {
        val id = resources.getIdentifier(ad, "raw", packageName)
        return if (id != 0) {
            Uri.parse("android.resource://$packageName/$id")
        } else {
            android.provider.Settings.System.DEFAULT_NOTIFICATION_URI
        }
    }

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
            setSound(sesUri(), ozellikler)
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
            setSound(sesUri(GURULTU_SES), ozellikler)
            enableVibration(true)
        }

        mgr.createNotificationChannel(kritik)
        mgr.createNotificationChannel(gurultu)
        mgr.createNotificationChannel(genel)
        mgr.createNotificationChannel(sessiz)
    }
}
