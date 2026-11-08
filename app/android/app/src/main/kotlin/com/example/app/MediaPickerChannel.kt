package com.example.app

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ext.SdkExtensions
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Selector de fotos/vídeos que, además del fichero, devuelve los metadatos
 * que conoce la galería de Android.
 *
 * `image_picker` copia el contenido a caché con un nombre genérico
 * (`6136.jpg`) y no expone la URI, así que si el fichero no trae EXIF (fotos
 * recibidas por WhatsApp, editadas, etc.) se pierde la fecha. La URI del
 * selector sí la conoce: `datetaken` es la fecha por la que ordena la
 * galería, y `_display_name` es el nombre original (`IMG-20250214-WA0003.jpg`).
 *
 * También extrae fotogramas de vídeo (`videoFrame`) para las miniaturas, de
 * ficheros locales o de URLs (sin descargar el vídeo entero).
 */
class MediaPickerChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "baby_link/media_picker"
        const val REQUEST_CODE = 0x6D70 // "mp"
        private const val CACHE_DIR = "media_picker"
        private const val CACHE_MAX_AGE_MS = 24L * 60 * 60 * 1000
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(call, result)
            "videoFrame" -> videoFrame(call, result)
            else -> result.notImplemented()
        }
    }

    private fun videoFrame(call: MethodCall, result: MethodChannel.Result) {
        val source = call.argument<String>("source")
            ?: return result.error("bad_args", "Falta 'source'", null)
        val maxSide = call.argument<Int>("maxSide") ?: 1080
        executor.execute {
            try {
                val path = extractFrame(source, maxSide)
                main.post { result.success(path) }
            } catch (e: Exception) {
                main.post { result.error("frame_failed", e.message, null) }
            }
        }
    }

    /** Guarda un fotograma como JPEG en caché y devuelve su ruta (o null). */
    private fun extractFrame(source: String, maxSide: Int): String? {
        val r = MediaMetadataRetriever()
        try {
            if (source.startsWith("http://") || source.startsWith("https://")) {
                r.setDataSource(source, HashMap())
            } else {
                r.setDataSource(source)
            }
            // El primer fotograma suele ser negro o un fundido: tomamos el
            // del 10 % del vídeo, como mucho al segundo 1.
            val durationMs = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull() ?: 0L
            val atUs = (durationMs / 10).coerceAtMost(1000L) * 1000L
            val opt = MediaMetadataRetriever.OPTION_CLOSEST_SYNC

            val raw: Bitmap = (if (Build.VERSION.SDK_INT >= 27) {
                r.getScaledFrameAtTime(atUs, opt, maxSide, maxSide)
            } else {
                r.getFrameAtTime(atUs, opt)
            }) ?: r.getFrameAtTime() ?: return null

            val frame = scaleDown(raw, maxSide)
            val dir = File(activity.cacheDir, "video_frames").apply { mkdirs() }
            cleanOldCopies(dir)
            val out = File(dir, "${UUID.randomUUID()}.jpg")
            out.outputStream().use { frame.compress(Bitmap.CompressFormat.JPEG, 82, it) }
            if (frame !== raw) raw.recycle()
            frame.recycle()
            return out.absolutePath
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
    }

    private fun scaleDown(bmp: Bitmap, maxSide: Int): Bitmap {
        val longest = maxOf(bmp.width, bmp.height)
        if (longest <= maxSide) return bmp
        val k = maxSide.toFloat() / longest
        return Bitmap.createScaledBitmap(
            bmp, (bmp.width * k).toInt(), (bmp.height * k).toInt(), true
        )
    }

    private fun pick(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            return result.error("already_active", "Ya hay un selector abierto", null)
        }
        val mime = if (call.argument<String>("type") == "video") "video/*" else "image/*"
        pending = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(buildIntent(mime), REQUEST_CODE)
        } catch (e: Exception) {
            pending = null
            result.error("launch_failed", e.message, null)
        }
    }

    /** Devuelve `true` si el resultado era nuestro. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // cancelado
            return true
        }
        // Copiar un vídeo puede tardar: fuera del hilo principal.
        executor.execute {
            try {
                val info = readAndCopy(uri)
                main.post { result.success(info) }
            } catch (e: Exception) {
                main.post { result.error("copy_failed", e.message, null) }
            }
        }
        return true
    }

    @SuppressLint("NewApi", "InlinedApi")
    private fun buildIntent(mime: String): Intent {
        val photoPicker = when {
            Build.VERSION.SDK_INT >= 33 -> true
            Build.VERSION.SDK_INT >= 30 ->
                SdkExtensions.getExtensionVersion(Build.VERSION_CODES.R) >= 2
            else -> false
        }
        return if (photoPicker) {
            Intent(android.provider.MediaStore.ACTION_PICK_IMAGES).setType(mime)
        } else {
            Intent(Intent.ACTION_GET_CONTENT)
                .setType(mime)
                .addCategory(Intent.CATEGORY_OPENABLE)
        }
    }

    private fun readAndCopy(uri: Uri): Map<String, Any?> {
        val resolver = activity.contentResolver
        var name: String? = null
        var dateTakenMs: Long? = null
        var dateModifiedMs: Long? = null

        // Proyección nula: cada proveedor (selector de fotos, documentos…)
        // expone columnas distintas; buscamos las que haya por nombre.
        try {
            resolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    name = c.stringOrNull(OpenableColumns.DISPLAY_NAME)
                    dateTakenMs = c.longOrNull("datetaken")?.takeIf { it > 0 }
                    dateModifiedMs =
                        c.longOrNull("date_modified")?.takeIf { it > 0 }?.times(1000)
                            ?: c.longOrNull("last_modified")?.takeIf { it > 0 }
                }
            }
        } catch (_: Exception) {
            // Sin metadatos de la galería; seguimos copiando el fichero.
        }

        val ext = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(resolver.getType(uri)) ?: "bin"
        var fileName = (name ?: "media_${System.currentTimeMillis()}")
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
        if (!fileName.contains('.')) fileName += ".$ext"

        val root = File(activity.cacheDir, CACHE_DIR)
        cleanOldCopies(root)
        val dir = File(root, UUID.randomUUID().toString()).apply { mkdirs() }
        val out = File(dir, fileName)
        val input = resolver.openInputStream(uri)
            ?: throw IllegalStateException("No se pudo abrir $uri")
        input.use { src -> out.outputStream().use { src.copyTo(it) } }

        return mapOf(
            "path" to out.absolutePath,
            "name" to name,
            "dateTakenMs" to dateTakenMs,
            "dateModifiedMs" to dateModifiedMs,
        )
    }

    /** Borra copias de selecciones anteriores (> 1 día). */
    private fun cleanOldCopies(root: File) {
        val limit = System.currentTimeMillis() - CACHE_MAX_AGE_MS
        root.listFiles()?.forEach { if (it.lastModified() < limit) it.deleteRecursively() }
    }

    private fun Cursor.stringOrNull(column: String): String? {
        val i = getColumnIndex(column)
        return if (i >= 0 && !isNull(i)) getString(i) else null
    }

    private fun Cursor.longOrNull(column: String): Long? {
        val i = getColumnIndex(column)
        return if (i >= 0 && !isNull(i)) getLong(i) else null
    }
}
