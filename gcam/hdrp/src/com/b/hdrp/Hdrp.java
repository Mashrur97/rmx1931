package com.b.hdrp;

import android.content.Context;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.ColorSpaceTransform;
import android.hardware.camera2.params.RggbChannelVector;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.os.Build;
import android.os.SystemClock;
import android.util.Log;
import android.util.Pair;
import android.util.Range;
import android.util.Rational;
import android.util.Size;
import android.util.SizeF;

import com.b.G960H;
import com.google.googlex.gcam.BufferUtils;
import com.google.googlex.gcam.GcamModuleJNI;
import com.google.googlex.gcam.base.function.IntByteArrayConsumer;
import com.google.googlex.gcam.base.function.IntConsumer;
import com.google.googlex.gcam.base.function.IntFloatConsumer;
import com.google.googlex.gcam.base.function.IntStringConsumer;
import com.google.googlex.gcam.hdrplus.EncodedBlobCallback;
import com.google.googlex.gcam.hdrplus.HdrPlusInterface;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;

/**
 * HDR+ engine glue (Mashrur's OppoCamera port). The camera-side smali (com/b/G960H) takes the Photo-mode
 * shutter shot through OPPO's RAW route and copies the RAW_SENSOR frames; this class hands them to Google's
 * HDR+ engine (libgcastartup.so) and writes the JPEG it returns. Everything is logged under the tag GCAM.
 *
 * Engine call order (as in the GCam app, ebi.smali): StartShotCapture -> BuildPayloadBurstSpec ->
 * BeginPayloadFrames -> addPayloadFrame x N -> EndPayloadFrames -> EndShotCapture -> JPEG callback.
 * SWIG natives take (pointer, owner object); the owner is only kept for GC, so null is passed.
 */
public final class Hdrp {
    static final String TAG = "GCAM";
    static final String DEVICE = "bramble";   // what the user's GCam config (pref_model 11) reports

    private static long gcam;                 // created once, kept for the life of the process
    private static float minIso = 100f, maxAnalogIso = 3200f;
    private static volatile boolean busy;
    private static volatile long shotStart;

    static void log(String s) { Log.i(TAG, "hdrp: " + s); }

    /** Called from G960H.fmt(): only switch OPPO's shot to the RAW route when the engine is free. */
    public static boolean ready() { return !busy; }

    /** Called from G960H.shot() after the RAW frames and their results are in. Keeps hdrp.lock until done. */
    public static void afterShot() {
        final int n = G960H.n();
        if (busy) { log("engine still busy with the last shot - this shot is OPPO's only"); unlock(); return; }
        if (n < 2) { log("only " + n + " RAW frame(s) - nothing to merge"); unlock(); return; }
        busy = true;
        shotStart = SystemClock.uptimeMillis();
        new Thread(new Runnable() {
            public void run() {
                boolean waiting = false;
                try { waiting = shot(n); }
                catch (Throwable t) { log("FAILED: " + t); }
                finally { if (!waiting) finish(); }
            }
        }, "hdrp-shot").start();
    }

    /** Called from G960.run() at camera start (replaces the stage 2a test): create the engine once and keep it. */
    public static void warm() {
        try { engine(); } catch (Throwable t) { log("engine FAILED: " + t); }
    }

    static void finish() {
        busy = false;
        unlock();
    }

    static void unlock() {
        try { new File(ctx().getFilesDir(), "hdrp.lock").delete(); } catch (Throwable t) { }
    }

    static Context ctx() { return com.oppo.camera.MyApplication.d(); }

    // ---------------------------------------------------------------- engine

    static synchronized long engine() throws Exception {
        if (gcam != 0) return gcam;
        long t0 = SystemClock.uptimeMillis();
        System.loadLibrary("gcastartup");
        new HdrPlusInterface();   // registers the hdrplus natives (static init)
        CameraManager cm = (CameraManager) ctx().getSystemService(Context.CAMERA_SERVICE);
        CameraCharacteristics cc = cm.getCameraCharacteristics("0");
        CHARS = cc;
        long sm = staticMetadata(cc);
        long smv = GcamModuleJNI.new_StaticMetadataVector__SWIG_0();
        GcamModuleJNI.StaticMetadataVector_add(smv, null, sm, null);
        long ip = GcamModuleJNI.new_InitParams();
        GcamModuleJNI.InitParams_allow_unknown_devices_set(ip, null, true);
        long g = GcamModuleJNI.Gcam_Create(ip, null, smv, null);
        GcamModuleJNI.delete_InitParams(ip);
        if (g == 0) throw new IllegalStateException("Gcam_Create returned null");
        gcam = g;
        log("engine " + GcamModuleJNI.GetVersion() + " created in " + (SystemClock.uptimeMillis() - t0)
                + " ms, cameras=" + GcamModuleJNI.Gcam_GetNumCameras(g, null) + " (kept)");
        return g;
    }

    static long floatVector(float[] v) {
        long fv = GcamModuleJNI.new_FloatVector__SWIG_0();
        if (v != null) for (float f : v) GcamModuleJNI.FloatVector_add(fv, null, f);
        return fv;
    }

    static long pixelRect(Rect r) {
        long p = GcamModuleJNI.new_PixelRect();
        GcamModuleJNI.PixelRect_x0_set(p, null, r.left);
        GcamModuleJNI.PixelRect_x1_set(p, null, r.right);
        GcamModuleJNI.PixelRect_y0_set(p, null, r.top);
        GcamModuleJNI.PixelRect_y1_set(p, null, r.bottom);
        return p;
    }

    static long fullRect() {
        long r = GcamModuleJNI.new_NormalizedRect();
        GcamModuleJNI.NormalizedRect_x0_set(r, null, 0f);
        GcamModuleJNI.NormalizedRect_y0_set(r, null, 0f);
        GcamModuleJNI.NormalizedRect_x1_set(r, null, 1f);
        GcamModuleJNI.NormalizedRect_y1_set(r, null, 1f);
        return r;
    }

    static CameraCharacteristics CHARS;
    // OPPO's RAW route delivers RAW_SENSOR frames that are already black-subtracted (darkest pixels ~6-15) while the
    // metadata still says 63. Subtracting 63 again crushed red/blue in the shadows and midtones = the green cast.
    // Measured per shot from frame 1; -1 = trust the metadata.
    static float blackOverride = -1;

    // 0.1th percentile of the green pixels of frame 1 (RAW16, before repack), from a coarse sample
    static int darkFloor(ByteBuffer b, int stride) {
        int[] hist = new int[1024];
        int n = 0;
        for (int y = 0; y < H; y += 8)              // even rows: G at even columns (GBRG)
            for (int x = 0; x < W; x += 8) {
                int o = y * stride + x * 2;
                int v = Math.min(1023, (b.get(o) & 0xff) | (b.get(o + 1) & 0xff) << 8);
                hist[v]++; n++;
            }
        int want = Math.max(1, n / 1000), acc = 0;
        for (int v = 0; v < 1024; v++) { acc += hist[v]; if (acc >= want) return v; }
        return 1023;
    }
    static final boolean DIAG_DNG = false;   // colour debugging: save input frame 1 + the engine's merged raw as DNGs

    static final boolean USE_ARNOVA = true;

    // GCam port's "Arnova" colour transform (pref_color_transform_key = 2 in RN's config): fixed CCMs by ISO,
    // used instead of OPPO's COLOR_CORRECTION_TRANSFORM. Last row is for ISO above the last threshold.
    static final int[] ARNOVA_ISO = {30, 40, 50, 60, 70, 90, 160, 200, 310, 520, 720, 820, 920, 1020, 1120, 1220, 1520, 1720, 2020, 2220, 2420, 2720, 3020, 3320, 3620, 3920, 4420, 4520, 5020, 6020, 7020, 8020, 9020, 10020, 10520};
    static final float[][] ARNOVA = {
        {1.9102f, -0.8438f, -0.0664f, -0.3438f, 1.5898f, -0.2461f, 0.0000f, -0.8203f, 1.8203f},
        {1.9141f, -0.7383f, -0.1758f, -0.3125f, 1.7578f, -0.4453f, -0.0586f, -0.8789f, 1.9375f},
        {1.9375f, -0.8672f, -0.0703f, -0.3711f, 1.6523f, -0.2812f, -0.0195f, -0.8984f, 1.9180f},
        {1.9258f, -0.8594f, -0.0703f, -0.3555f, 1.6094f, -0.2539f, -0.0078f, -0.8477f, 1.8555f},
        {1.9258f, -0.8555f, -0.0664f, -0.3477f, 1.5859f, -0.2383f, 0.0000f, -0.8164f, 1.8164f},
        {1.9219f, -0.8555f, -0.0664f, -0.3477f, 1.5859f, -0.2383f, 0.0000f, -0.8164f, 1.8164f},
        {1.9141f, -0.8477f, -0.0664f, -0.3438f, 1.5898f, -0.2422f, 0.0000f, -0.8164f, 1.8203f},
        {1.9141f, -0.8438f, -0.0664f, -0.3438f, 1.5898f, -0.2422f, 0.0000f, -0.8164f, 1.8203f},
        {1.9141f, -0.8477f, -0.0664f, -0.3438f, 1.5898f, -0.2422f, 0.0000f, -0.8164f, 1.8203f},
        {1.9141f, -0.8477f, -0.0664f, -0.3477f, 1.5859f, -0.2422f, 0.0000f, -0.8164f, 1.8164f},
        {1.9180f, -0.8516f, -0.0664f, -0.3477f, 1.5859f, -0.2422f, 0.0000f, -0.8164f, 1.8164f},
        {1.9062f, -0.8398f, -0.0664f, -0.3438f, 1.5898f, -0.2461f, 0.0000f, -0.8203f, 1.8203f},
        {1.8594f, -0.7500f, -0.1094f, -0.3125f, 1.6328f, -0.3203f, -0.0117f, -0.8008f, 1.8125f},
        {1.8984f, -0.8242f, -0.0703f, -0.3398f, 1.5977f, -0.2578f, -0.0039f, -0.8203f, 1.8203f},
        {1.8164f, -0.6484f, -0.1719f, -0.2695f, 1.6914f, -0.4219f, -0.0312f, -0.7812f, 1.8125f},
        {1.9102f, -0.8398f, -0.0664f, -0.3477f, 1.6016f, -0.2539f, -0.0039f, -0.8320f, 1.8359f},
        {1.9102f, -0.8398f, -0.0664f, -0.3477f, 1.5977f, -0.2500f, -0.0039f, -0.8320f, 1.8320f},
        {1.9062f, -0.8398f, -0.0664f, -0.3477f, 1.5977f, -0.2500f, -0.0039f, -0.8281f, 1.8281f},
        {1.9102f, -0.8398f, -0.0664f, -0.3477f, 1.5938f, -0.2500f, 0.0000f, -0.8242f, 1.8242f},
        {1.9102f, -0.8438f, -0.0664f, -0.3438f, 1.5898f, -0.2461f, 0.0000f, -0.8203f, 1.8203f},
        {1.9102f, -0.8438f, -0.0664f, -0.3438f, 1.5898f, -0.2461f, 0.0000f, -0.8203f, 1.8203f},
        {1.9023f, -0.8320f, -0.0664f, -0.3398f, 1.5820f, -0.2422f, 0.0000f, -0.8086f, 1.8086f},
        {1.8984f, -0.8320f, -0.0664f, -0.3398f, 1.5820f, -0.2422f, 0.0039f, -0.8047f, 1.8047f},
        {1.8906f, -0.8242f, -0.0664f, -0.3359f, 1.5742f, -0.2422f, 0.0039f, -0.8008f, 1.7969f},
        {1.8867f, -0.8203f, -0.0664f, -0.3320f, 1.5742f, -0.2383f, 0.0039f, -0.7969f, 1.7891f},
        {1.8867f, -0.8203f, -0.0664f, -0.3320f, 1.5742f, -0.2422f, 0.0039f, -0.7969f, 1.7930f},
        {1.8711f, -0.8086f, -0.0664f, -0.3281f, 1.5664f, -0.2383f, 0.0078f, -0.7852f, 1.7773f},
        {1.8672f, -0.8047f, -0.0664f, -0.3281f, 1.5664f, -0.2383f, 0.0078f, -0.7852f, 1.7773f},
        {1.8594f, -0.7969f, -0.0625f, -0.3242f, 1.5625f, -0.2383f, 0.0078f, -0.7812f, 1.7695f},
        {1.8438f, -0.7812f, -0.0625f, -0.3203f, 1.5586f, -0.2422f, 0.0117f, -0.7734f, 1.7617f},
        {1.8359f, -0.7734f, -0.0625f, -0.3164f, 1.5586f, -0.2422f, 0.0117f, -0.7695f, 1.7539f},
        {1.7812f, -0.7188f, -0.0625f, -0.3008f, 1.5508f, -0.2500f, 0.0195f, -0.7500f, 1.7305f},
        {1.8203f, -0.7578f, -0.0625f, -0.3125f, 1.5547f, -0.2461f, 0.0156f, -0.7656f, 1.7500f},
        {1.7500f, -0.6914f, -0.0586f, -0.2891f, 1.5469f, -0.2578f, 0.0234f, -0.7422f, 1.7188f},
        {1.7383f, -0.6797f, -0.0586f, -0.2891f, 1.5508f, -0.2617f, 0.0234f, -0.7422f, 1.7188f},
        {1.5312f, -0.4961f, -0.0391f, -0.1641f, 1.3281f, -0.1641f, 0.0938f, -0.4609f, 1.3672f}
    };

    static long arnova(int iso) {
        int i = 0;
        while (i < ARNOVA_ISO.length && iso > ARNOVA_ISO[i]) i++;
        long a = GcamModuleJNI.new_FloatArray9__SWIG_0();
        for (int k = 0; k < 9; k++) GcamModuleJNI.FloatArray9_set(a, null, k, ARNOVA[i][k]);
        return a;
    }

    static long floatArray9(ColorSpaceTransform t) {
        long a = GcamModuleJNI.new_FloatArray9__SWIG_0();
        for (int i = 0; i < 9; i++) {
            Rational r = t.getElement(i % 3, i / 3);
            GcamModuleJNI.FloatArray9_set(a, null, i, r.floatValue());
        }
        return a;
    }

    /** Same fields and conversions as GCam's pkr.v() (stage 2a, now in Java). */
    static long staticMetadata(CameraCharacteristics cc) {
        long sm = GcamModuleJNI.new_StaticMetadata__SWIG_0();
        GcamModuleJNI.StaticMetadata_make_set(sm, null, "Google");
        GcamModuleJNI.StaticMetadata_model_set(sm, null, Build.MODEL);
        GcamModuleJNI.StaticMetadata_device_set(sm, null, DEVICE);
        GcamModuleJNI.StaticMetadata_software_set(sm, null, "HDR+ " + GcamModuleJNI.GetVersion());
        GcamModuleJNI.StaticMetadata_device_os_version_set(sm, null, Build.FINGERPRINT);
        GcamModuleJNI.StaticMetadata_device_os_unix_ms_set(sm, null, Build.TIME);
        GcamModuleJNI.StaticMetadata_sensor_id_set(sm, null, 0);
        GcamModuleJNI.StaticMetadata_lens_facing_set(sm, null, 0);
        Boolean flash = cc.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
        GcamModuleJNI.StaticMetadata_has_flash_set(sm, null, flash != null && flash);
        GcamModuleJNI.StaticMetadata_available_focal_lengths_mm_set(sm, null,
                floatVector(cc.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)), null);
        GcamModuleJNI.StaticMetadata_available_f_numbers_set(sm, null,
                floatVector(cc.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)), null);
        GcamModuleJNI.StaticMetadata_white_level_set(sm, null, cc.get(CameraCharacteristics.SENSOR_INFO_WHITE_LEVEL));
        long obv = GcamModuleJNI.new_PixelRectVector__SWIG_0();
        Rect[] ob = cc.get(CameraCharacteristics.SENSOR_OPTICAL_BLACK_REGIONS);
        if (ob != null) for (Rect r : ob) GcamModuleJNI.PixelRectVector_add(obv, null, pixelRect(r), null);
        GcamModuleJNI.StaticMetadata_optically_black_regions_set(sm, null, obv, null);
        int cfa = cc.get(CameraCharacteristics.SENSOR_INFO_COLOR_FILTER_ARRANGEMENT);
        int[] bayer = {1, 3, 4, 2};   // RGGB, GRBG, GBRG, BGGR -> gcam
        GcamModuleJNI.StaticMetadata_bayer_pattern_set(sm, null, cfa >= 0 && cfa < 4 ? bayer[cfa] : 0);
        Range<Long> exp = cc.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE);
        GcamModuleJNI.StaticMetadata_exposure_time_range_ms_set(sm, null,
                new float[]{exp.getLower() / 1e6f, exp.getUpper() / 1e6f});
        Range<Integer> iso = cc.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE);
        minIso = iso.getLower();
        GcamModuleJNI.StaticMetadata_iso_range_set(sm, null, new float[]{iso.getLower(), iso.getUpper()});
        Integer maxA = cc.get(CameraCharacteristics.SENSOR_MAX_ANALOG_SENSITIVITY);
        maxAnalogIso = maxA != null ? maxA : 800;
        GcamModuleJNI.StaticMetadata_max_analog_iso_set(sm, null, maxAnalogIso);
        long dcv = GcamModuleJNI.new_DngColorCalibrationVector__SWIG_0();
        addDng(dcv, cc.get(CameraCharacteristics.SENSOR_REFERENCE_ILLUMINANT1),
                cc.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM1), cc.get(CameraCharacteristics.SENSOR_CALIBRATION_TRANSFORM1));
        Byte il2 = cc.get(CameraCharacteristics.SENSOR_REFERENCE_ILLUMINANT2);
        addDng(dcv, il2 == null ? null : (int) il2,
                cc.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM2), cc.get(CameraCharacteristics.SENSOR_CALIBRATION_TRANSFORM2));
        GcamModuleJNI.StaticMetadata_dng_color_calibration_set(sm, null, dcv, null);
        SizeF phys = cc.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE);
        GcamModuleJNI.StaticMetadata_sensor_physical_width_mm_set(sm, null, phys.getWidth());
        GcamModuleJNI.StaticMetadata_sensor_physical_height_mm_set(sm, null, phys.getHeight());
        Size pa = cc.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE);
        GcamModuleJNI.StaticMetadata_pixel_array_width_set(sm, null, pa.getWidth());
        GcamModuleJNI.StaticMetadata_pixel_array_height_set(sm, null, pa.getHeight());
        GcamModuleJNI.StaticMetadata_active_area_set(sm, null,
                pixelRect(cc.get(CameraCharacteristics.SENSOR_INFO_PRE_CORRECTION_ACTIVE_ARRAY_SIZE)), null);
        // RAW_SENSOR is what the shutter shot delivers (OPPO's RAW route)
        StreamConfigurationMap map = cc.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
        Size best = null;
        for (Size s : map.getOutputSizes(ImageFormat.RAW_SENSOR))
            if (best == null || (long) s.getWidth() * s.getHeight() > (long) best.getWidth() * best.getHeight()) best = s;
        GcamModuleJNI.StaticMetadata_frame_raw_max_width_set(sm, null, best.getWidth());
        GcamModuleJNI.StaticMetadata_frame_raw_max_height_set(sm, null, best.getHeight());
        // frames are repacked to RAW10 before the shot (see packRaw10), as GCam uses RAW10 on this phone
        GcamModuleJNI.StaticMetadata_raw_bits_per_pixel_set(sm, null, 10);
        long dur = map.getOutputMinFrameDuration(ImageFormat.RAW_SENSOR, best);
        GcamModuleJNI.StaticMetadata_frame_readout_time_ms_set(sm, null, dur > 0 ? dur / 1e6f : 50f);
        boolean ois = false;
        int[] om = cc.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION);
        if (om != null) for (int m : om) if (m == 1) ois = true;
        GcamModuleJNI.StaticMetadata_has_ois_set(sm, null, ois);
        log("static metadata: raw " + best + " iso " + iso + " max analog " + maxAnalogIso + " cfa " + cfa);
        return sm;
    }

    static void addDng(long vec, Integer illum, ColorSpaceTransform color, ColorSpaceTransform calib) {
        if (illum == null || color == null || calib == null) return;
        long d = GcamModuleJNI.new_DngColorCalibration();
        GcamModuleJNI.DngColorCalibration_illuminant_set(d, null, illum);
        GcamModuleJNI.DngColorCalibration_xyz_to_model_rgb_set(d, null, floatArray9(color), null);
        GcamModuleJNI.DngColorCalibration_model_rgb_to_device_rgb_set(d, null, floatArray9(calib), null);
        GcamModuleJNI.DngColorCalibrationVector_add(vec, null, d, null);
    }

    // ---------------------------------------------------------------- per frame

    /** Same conversions as GCam's pkr.m() for the fields HDR+ needs. */
    static long frameMetadata(TotalCaptureResult r) {
        long fm = GcamModuleJNI.new_FrameMetadata();
        GcamModuleJNI.FrameMetadata_sensor_id_set(fm, null, 0);
        GcamModuleJNI.FrameMetadata_timestamp_ns_set(fm, null, r.get(CaptureResult.SENSOR_TIMESTAMP));
        GcamModuleJNI.FrameMetadata_actual_exposure_time_ms_set(fm, null, r.get(CaptureResult.SENSOR_EXPOSURE_TIME) / 1e6f);
        float iso = r.get(CaptureResult.SENSOR_SENSITIVITY);
        GcamModuleJNI.FrameMetadata_actual_analog_gain_set(fm, null, Math.min(iso, maxAnalogIso) / minIso);
        GcamModuleJNI.FrameMetadata_applied_digital_gain_set(fm, null, Math.max(iso / maxAnalogIso, 1f));
        Integer boost = r.get(CaptureResult.CONTROL_POST_RAW_SENSITIVITY_BOOST);
        GcamModuleJNI.FrameMetadata_post_raw_digital_gain_set(fm, null, boost == null ? 1f : boost / 100f);
        // white balance: RGGB gains + colour correction matrix
        long awb = GcamModuleJNI.new_AwbInfo__SWIG_0();
        RggbChannelVector g = r.get(CaptureResult.COLOR_CORRECTION_GAINS);
        long g4 = GcamModuleJNI.new_FloatArray4__SWIG_0();
        GcamModuleJNI.FloatArray4_set(g4, null, 0, g.getRed());
        GcamModuleJNI.FloatArray4_set(g4, null, 1, g.getGreenEven());
        GcamModuleJNI.FloatArray4_set(g4, null, 2, g.getGreenOdd());
        GcamModuleJNI.FloatArray4_set(g4, null, 3, g.getBlue());
        GcamModuleJNI.AwbInfo_rggb_gains_set(awb, null, g4, null);
        // colour matrix: OPPO's COLOR_CORRECTION_TRANSFORM gave a green JPEG; use the GCam port's Arnova table instead
        GcamModuleJNI.AwbInfo_rgb2rgb_set(awb, null, USE_ARNOVA ? arnova((int) iso)
                : floatArray9(r.get(CaptureResult.COLOR_CORRECTION_TRANSFORM)), null);
        GcamModuleJNI.FrameMetadata_wb_set(fm, null, awb, null);
        // black levels in CFA-position order
        float[] bl = r.get(CaptureResult.SENSOR_DYNAMIC_BLACK_LEVEL);
        if (blackOverride >= 0) bl = new float[]{blackOverride, blackOverride, blackOverride, blackOverride};
        if (bl != null) {
            long b4 = GcamModuleJNI.new_FloatArray4__SWIG_0();
            for (int i = 0; i < 4; i++) GcamModuleJNI.FloatArray4_set(b4, null, i, bl[i]);
            GcamModuleJNI.FrameMetadata_black_levels_bayer_set(fm, null, b4, null);
        }
        GcamModuleJNI.FrameMetadata_was_black_level_locked_set(fm, null, false);
        // noise: shot (S) and read (O) noise per CFA channel
        Pair<Double, Double>[] np = r.get(CaptureResult.SENSOR_NOISE_PROFILE);
        if (np != null) {
            float[] s = new float[4], o = new float[4];
            for (int i = 0; i < 4; i++) { Pair<Double, Double> p = np[Math.min(i, np.length - 1)]; s[i] = p.first.floatValue(); o[i] = p.second.floatValue(); }
            long nm = GcamModuleJNI.NoiseModel_FromShotReadNoise__SWIG_0(floatVector(s), null, floatVector(o), null);
            GcamModuleJNI.FrameMetadata_dng_noise_model_bayer_set(fm, null, nm, null);
        }
        Float f;
        if ((f = r.get(CaptureResult.LENS_FOCUS_DISTANCE)) != null) GcamModuleJNI.FrameMetadata_focus_distance_diopters_set(fm, null, f);
        if ((f = r.get(CaptureResult.LENS_FOCAL_LENGTH)) != null) GcamModuleJNI.FrameMetadata_focal_length_mm_set(fm, null, f);
        if ((f = r.get(CaptureResult.LENS_APERTURE)) != null) GcamModuleJNI.FrameMetadata_f_number_set(fm, null, f);
        Integer cm = r.get(CaptureResult.CONTROL_MODE);
        if (cm != null) GcamModuleJNI.FrameMetadata_control_mode_set(fm, null, cm);
        return fm;
    }

    // ---------------------------------------------------------------- shot

    /** Returns true when the engine accepted the shot and the JPEG callback will call finish(). */
    static final int W = 4608, H = 3456;

    // RAW_SENSOR (16-bit little-endian, 10-bit values) -> MIPI RAW10 (4 pixels in 5 bytes), in place: packed row r
    // (r*W*5/4 .. +W*5/4) never reaches past the start of source row r+1, and row r is read before it is written.
    static void packRaw10(ByteBuffer b, int srcStride, int w, int h) {
        ByteBuffer d = b.duplicate();
        int dstStride = w * 5 / 4;
        byte[] in = new byte[w * 2], out = new byte[dstStride];
        for (int r = 0; r < h; r++) {
            d.position(r * srcStride);
            d.get(in, 0, w * 2);
            for (int x = 0, o = 0; x < w * 2; x += 8, o += 5) {
                int p0 = Math.min(1023, (in[x] & 0xff) | (in[x + 1] & 0xff) << 8);
                int p1 = Math.min(1023, (in[x + 2] & 0xff) | (in[x + 3] & 0xff) << 8);
                int p2 = Math.min(1023, (in[x + 4] & 0xff) | (in[x + 5] & 0xff) << 8);
                int p3 = Math.min(1023, (in[x + 6] & 0xff) | (in[x + 7] & 0xff) << 8);
                out[o] = (byte) (p0 >> 2);
                out[o + 1] = (byte) (p1 >> 2);
                out[o + 2] = (byte) (p2 >> 2);
                out[o + 3] = (byte) (p3 >> 2);
                out[o + 4] = (byte) ((p0 & 3) | (p1 & 3) << 2 | (p2 & 3) << 4 | (p3 & 3) << 6);
            }
            d.position(r * dstStride);
            d.put(out);
        }
    }

    static boolean shot(int n) throws Exception {
        long g = engine();
        final int invalid = GcamModuleJNI.kInvalidShotId_get();

        HdrPlusInterface hi = new HdrPlusInterface();
        long cb = GcamModuleJNI.new_ShotCallbacks();
        if (DIAG_DNG) hi.setMergedDngCallback(cb, new EncodedBlobCallback() {
            public void onDataAvailable(int shotId, ByteBuffer data, int a, int b) { saveBlob(data, "_MERGED.dng", "merged DNG"); }
        });
        hi.setJpegCallback(cb, new EncodedBlobCallback() {
            public void onDataAvailable(int shotId, ByteBuffer data, int a, int b) { saveJpeg(shotId, data, a, b); }
        });
        hi.setShotStatusCallbacks(cb,
                new IntByteArrayConsumer() { public void accept(int id, byte[] d) { log("shot " + id + " status data " + (d == null ? 0 : d.length) + " bytes"); } },
                new IntStringConsumer() { public void accept(int id, String s) { log("shot " + id + " ERROR from engine: " + s); finish(); } },
                new IntConsumer() { public void accept(int id) { log("shot " + id + " finished (engine status)"); } });
        hi.setProgressCallback(cb, new IntFloatConsumer() {
            int last = -1;
            public void accept(int id, float p) { int q = (int) (p * 4); if (q != last) { last = q; log("shot " + id + " progress " + (int) (p * 100) + "%"); } }
        });

        long[] fm = new long[n], raw = new long[n];
        long gm = GcamModuleJNI.new_SpatialGainMap__SWIG_0();   // no lens shading map on OPPO's request: empty map, as GCam does
        for (int i = 0; i < n; i++)
            if (G960H.res(i) == null) { log("frame " + (i + 1) + " has no capture result - not starting the shot"); return false; }
        // RAW16 merge is broken in this engine build (the GCam port ships a "fixraw16merge" lib patch, and GCam itself
        // asks the HAL for RAW10 first), so repack OPPO's RAW_SENSOR frames to RAW10 in place, one thread per frame.
        if (DIAG_DNG) saveInputDng();
        {
            float[] mb = G960H.res(0).get(CaptureResult.SENSOR_DYNAMIC_BLACK_LEVEL);
            float meta = mb == null ? 63f : mb[0];
            int floor = darkFloor(G960H.buf(0), G960H.str(0));
            blackOverride = floor < meta - 16 ? 0f : -1f;
            log("black level: metadata " + meta + ", darkest green pixels " + floor
                    + (blackOverride == 0 ? " -> data is already black-subtracted, using 0" : " -> using the metadata"));
        }
        long t0 = SystemClock.uptimeMillis();
        Thread[] th = new Thread[n];
        for (int i = 0; i < n; i++) {
            final ByteBuffer b = G960H.buf(i);
            final int s = G960H.str(i);
            th[i] = new Thread(new Runnable() { public void run() { packRaw10(b, s, W, H); } }, "hdrp-pack" + i);
            th[i].start();
        }
        for (Thread t : th) t.join();
        log("frames repacked to RAW10 in " + (SystemClock.uptimeMillis() - t0) + " ms");
        for (int i = 0; i < n; i++) {
            fm[i] = frameMetadata(G960H.res(i));
            // RAW10: stride in bytes, layout 0 (as GCam's pko does)
            raw[i] = GcamModuleJNI.new_RawWriteView__SWIG_1(W, H, W * 5 / 4, 0, BufferUtils.a(G960H.buf(i)));
        }
        long sp = GcamModuleJNI.new_ShotParams__SWIG_0();
        long ae = GcamModuleJNI.new_AeShotParams__SWIG_0();
        // as GCam's ebi.F(): REGULAR HDR+ = ux_mode 1, target = output picture size
        GcamModuleJNI.AeShotParams_ux_mode_set(ae, null, 1);
        GcamModuleJNI.AeShotParams_target_width_set(ae, null, 4608);
        GcamModuleJNI.AeShotParams_target_height_set(ae, null, 3456);
        // crop (AE) and merged crop: full frame. Left unset they are empty, and the merge produced an empty raw
        // (merge_raw.cc:638 "Check failed: !merged.raw.empty()").
        GcamModuleJNI.AeShotParams_crop_set(ae, null, fullRect(), null);
        GcamModuleJNI.AeShotParams_merged_crop_set(ae, null, fullRect(), null);
        GcamModuleJNI.ShotParams_ae_set(sp, null, ae, null);
        // what the viewfinder was doing just before the shot: here the captured frame's exposure and white balance
        float tet = GcamModuleJNI.FrameMetadata_actual_exposure_time_ms_get(fm[0], null)
                * GcamModuleJNI.FrameMetadata_actual_analog_gain_get(fm[0], null)
                * GcamModuleJNI.FrameMetadata_applied_digital_gain_get(fm[0], null);
        GcamModuleJNI.ShotParams_previous_viewfinder_tet_set(sp, null, tet);
        GcamModuleJNI.ShotParams_previous_viewfinder_wb_set(sp, null, GcamModuleJNI.FrameMetadata_wb_get(fm[0], null), null);
        // merge path: GCam turns Sabre (super-res merge) on only for zoom shots. The ShotParams defaults are logged
        // Sabre/spatial-RGB on RAW16 input is the suspect for the empty merged raw (merge_raw.cc:638).
        // (The getters are not declared in the APK's GcamModuleJNI, so the defaults can't be logged.)
        log("merge: allow_sabre=false allow_spatial_rgb=false");
        GcamModuleJNI.ShotParams_allow_sabre_set(sp, null, false);
        GcamModuleJNI.ShotParams_allow_spatial_rgb_set(sp, null, false);
        // white balance: first JPEG came out green. GCam sets recompute_wb_on_base_frame from pref_awbrec_key (0 in
        // RN's config), so keep OPPO's per-frame AWB and also force it (engine logs "Using the value of force_wb").
        // wb_mode: GCam passes 0 for AUTO (engine AWB, which needs the GCam port's QcColorCalibration we don't set yet)
        // and 1 for any fixed preset, where the frame's own gains are used. 1 = keep OPPO's AWB.
        GcamModuleJNI.ShotParams_wb_mode_set(sp, null, 1);
        if (DIAG_DNG) { GcamModuleJNI.ShotParams_save_merged_dng_set(sp, null, true); GcamModuleJNI.ShotParams_compress_merged_dng_set(sp, null, false); }
        GcamModuleJNI.ShotParams_recompute_wb_on_base_frame_set(sp, null, false);
        GcamModuleJNI.ShotParams_force_wb_set(sp, null, GcamModuleJNI.FrameMetadata_wb_get(fm[0], null), null);
        // flash: GCam maps AUTO->0, ON->1, OFF->2; the shutter path never fires the flash
        GcamModuleJNI.ShotParams_flash_mode_set(sp, null, 2);
        // rotation from OPPO's own request (JPEG_ORIENTATION), as GCam does with DegreesToImageRotation
        Integer jo = G960H.res(0).get(CaptureResult.JPEG_ORIENTATION);
        GcamModuleJNI.ShotParams_image_rotation_set(sp, null, GcamModuleJNI.DegreesToImageRotation(jo == null ? 0 : jo));
        log("wb: mode 1 (fixed), recompute off, forced to frame 1 gains; flash off; rotation " + jo);
        long pv = GcamModuleJNI.new_PostviewParams();
        log("StartShotCapture (" + n + " frames)");
        int shot = GcamModuleJNI.Gcam_StartShotCapture(g, null, 0, sp, null, cb, null, 0, pv, null, 0, null);
        if (shot == invalid) { log("StartShotCapture REJECTED (invalid shot id)"); return false; }
        log("shot id " + shot);

        long opts = GcamModuleJNI.new_BuildPayloadBurstSpecOptions__SWIG_0();
        GcamModuleJNI.BuildPayloadBurstSpecOptions_max_frame_count_set(opts, null, n);
        long bs = GcamModuleJNI.Gcam_BuildPayloadBurstSpec(g, null, 0, GcamModuleJNI.RawWriteView_SWIGUpcast(raw[0]), null,
                fm[0], null, gm, null, opts, null);
        log("BuildPayloadBurstSpec -> " + (bs != 0 ? "ok" : "null"));
        if (bs == 0) bs = GcamModuleJNI.new_BurstSpec();
        // The engine planned its own exposures (its AE), but OPPO already shot the burst. Replace the plan with what was
        // actually captured, so CheckRequestConsistency accepts the frames instead of invalidating them.
        long frv = GcamModuleJNI.new_FrameRequestVector__SWIG_0();
        for (int i = 0; i < n; i++) {
            long fr = GcamModuleJNI.new_FrameRequest__SWIG_0();
            GcamModuleJNI.FrameRequest_desired_exposure_time_ms_set(fr, null,
                    GcamModuleJNI.FrameMetadata_actual_exposure_time_ms_get(fm[i], null));
            GcamModuleJNI.FrameRequest_desired_analog_gain_set(fr, null,
                    GcamModuleJNI.FrameMetadata_actual_analog_gain_get(fm[i], null));
            GcamModuleJNI.FrameRequestVector_add(frv, null, fr, null);
        }
        GcamModuleJNI.BurstSpec_frame_requests_set(bs, null, frv, null);
        log("burst plan replaced with the " + n + " captured frames (" + GcamModuleJNI.FrameMetadata_actual_exposure_time_ms_get(fm[0], null)
                + " ms, analog x" + GcamModuleJNI.FrameMetadata_actual_analog_gain_get(fm[0], null) + ")");
        GcamModuleJNI.Gcam_BeginPayloadFrames(g, null, shot, bs, null);
        log("BeginPayloadFrames ok, adding frames");
        for (int i = 0; i < n; i++) {
            final int k = i + 1;
            // as GCam's ebi.q(): (gcam, shot, metadata, gain map, raw view, release, PD view (empty object, never 0),
            // release, AHardwareBuffer (0 = none), release); the engine may call every release callback, so none are null
            Runnable noop = new Runnable() { public void run() { } };
            boolean ok = hi.addPayloadFrame(g, shot, fm[i], gm, raw[i],
                    new Runnable() { public void run() { log("frame " + k + " released by the engine"); } },
                    GcamModuleJNI.new_RawWriteView__SWIG_0(), noop, 0, noop);
            log("addPayloadFrame " + k + " -> " + ok);
        }
        boolean e1 = GcamModuleJNI.Gcam_EndPayloadFrames(g, null, shot, 0, null);
        log("EndPayloadFrames -> " + e1);
        boolean e2 = GcamModuleJNI.Gcam_EndShotCapture(g, null, shot);
        log("EndShotCapture -> " + e2 + " (" + (SystemClock.uptimeMillis() - shotStart) + " ms since shutter); waiting for the JPEG");
        // safety net: never keep the lock forever
        new Thread(new Runnable() {
            public void run() {
                try { Thread.sleep(60000); } catch (InterruptedException e) { }
                if (busy) { log("no JPEG after 60 s - giving up on this shot"); finish(); }
            }
        }, "hdrp-timeout").start();
        return true;
    }

    static File diagFile(String suffix) {
        File dir = new File(ctx().getExternalFilesDir(null), "HDRP");
        dir.mkdirs();
        return new File(dir, "IMG_" + new java.text.SimpleDateFormat("yyyyMMdd_HHmmss").format(new java.util.Date()) + suffix);
    }

    // input frame 1 (still RAW16, before the RAW10 repack) through Android's DngCreator, with OPPO's own metadata
    static void saveInputDng() {
        try {
            File out = diagFile("_IN1.dng");
            ByteBuffer b = G960H.buf(0).duplicate();
            b.position(0);
            FileOutputStream fo = new FileOutputStream(out);
            new android.hardware.camera2.DngCreator(CHARS, G960H.res(0)).writeByteBuffer(fo, new Size(W, H), b, 0);
            fo.close();
            log("input frame 1 DNG saved: " + out + " (" + out.length() + " bytes)");
        } catch (Throwable t) {
            log("input DNG FAILED: " + t);
        }
    }

    static void saveBlob(ByteBuffer data, String suffix, String what) {
        try {
            File out = diagFile(suffix);
            ByteBuffer d = data.duplicate();
            FileOutputStream fo = new FileOutputStream(out);
            FileChannel ch = fo.getChannel();
            while (d.hasRemaining()) ch.write(d);
            fo.close();
            log(what + " saved: " + out + " (" + out.length() + " bytes)");
        } catch (Throwable t) {
            log(what + " FAILED: " + t);
        }
    }

    // HDR+ JPEG -> DCIM/Camera through MediaStore, next to OPPO's own photos (IMG<date>_HDRP.jpg). If MediaStore
    // refuses, fall back to the app's files/HDRP folder so the shot is never lost.
    static void saveJpeg(int shotId, ByteBuffer data, int a, int b) {
        String name = "IMG" + new java.text.SimpleDateFormat("yyyyMMddHHmmss").format(new java.util.Date()) + "_HDRP.jpg";
        try {
            android.content.ContentValues cv = new android.content.ContentValues();
            cv.put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, name);
            cv.put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "image/jpeg");
            cv.put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, "DCIM/Camera");
            cv.put(android.provider.MediaStore.MediaColumns.IS_PENDING, 1);
            android.content.ContentResolver cr = ctx().getContentResolver();
            android.net.Uri uri = cr.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cv);
            if (uri == null) throw new java.io.IOException("MediaStore insert returned null");
            java.io.OutputStream os = cr.openOutputStream(uri);
            ByteBuffer d = data.duplicate();
            byte[] buf = new byte[1 << 16];
            long n = 0;
            while (d.hasRemaining()) { int k = Math.min(buf.length, d.remaining()); d.get(buf, 0, k); os.write(buf, 0, k); n += k; }
            os.close();
            cv.clear();
            cv.put(android.provider.MediaStore.MediaColumns.IS_PENDING, 0);
            cr.update(uri, cv, null, null);
            log("JPEG for shot " + shotId + " saved to DCIM/Camera/" + name + " (" + n + " bytes, "
                    + (SystemClock.uptimeMillis() - shotStart) + " ms after the shutter)");
        } catch (Throwable t) {
            log("DCIM save FAILED (" + t + "), saving to files/HDRP instead");
            saveBlob(data, "_HDRP.jpg", "JPEG for shot " + shotId);
        } finally {
            finish();
        }
    }
}
