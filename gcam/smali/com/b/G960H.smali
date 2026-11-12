.class public Lcom/b/G960H;
.super Ljava/lang/Object;
.source "G960H.java"

# implements
.implements Ljava/lang/Runnable;

# HDR+ step 1c: RAW10 stream in the Photo session + one self-fired test burst of 8 (ring/ZSL of step 1 failed on this HAL) (Mods > HDR+ Enhanced, pref_gcam_hdrp).
# outputs(): called at the end of CameraManager$u.a(LinkedHashMap,int) (session surface list) - adds our
#   own RAW10 ImageReader as "type_gcam_raw" when the toggle is on, mode is exactly CommonCapMode
#   (com/oppo/camera/e/e); the session's role is kept and rep() only touches that role (main = 1). reset() at the start of that method clears the flag.
# rep(): called from OneCameraImpl.requestRepeating - adds our surface to PREVIEW repeating requests,
#   turns the lens shading map on, and wraps the callback (G960H$W) to keep TotalCaptureResults.
# Images are kept in a ring of 6; every 2 s the ring is checked against results by timestamp. Tag GCAM.
# Guard: files/hdrp.lock is made when the stream is added and removed at the 5th frame; if it is still
#   there at the next session, the toggle is switched off (the stream broke the camera last time).

.field public static volatile ON:Z
.field private static ROLE:I
.field private static FIRED:Z
.field private static SESS:Landroid/hardware/camera2/CameraCaptureSession;
.field private static PC:I
.field private static PC0:I
.field private static TF:J
.field private static BR:I
.field private static BF:I
.field private m:I
.field private static R:Landroid/media/ImageReader;
.field private static OR:Landroid/media/ImageReader;
.field private static CAM:Ljava/lang/Object;
.field private static MODE:Ljava/lang/Object;
.field private static volatile CAP:Z
.field private static NC:I
.field private static LASTT:J
.field private static BUF:[Ljava/nio/ByteBuffer;
.field private static TSA:[J
.field private static STR:[I
.field private static SR:I
.field private static SRT:J
.field private static volatile BURST:Z
.field private static TH:Landroid/os/HandlerThread;
.field private static HD:Landroid/os/Handler;
.field private static Q:Ljava/util/ArrayDeque;
.field private static TS:[J
.field private static RS:[Ljava/lang/Object;
.field private static RI:I
.field private static FR:I
.field private static FR0:I
.field private static LOST:I
.field private static T0:J
.field private static SAMPLED:Z

.method static constructor <clinit>()V
    .locals 1
    new-instance v0, Ljava/util/ArrayDeque;
    invoke-direct {v0}, Ljava/util/ArrayDeque;-><init>()V
    sput-object v0, Lcom/b/G960H;->Q:Ljava/util/ArrayDeque;
    const/16 v0, 0x20
    new-array v0, v0, [J
    sput-object v0, Lcom/b/G960H;->TS:[J
    const/16 v0, 0x20
    new-array v0, v0, [Ljava/lang/Object;
    sput-object v0, Lcom/b/G960H;->RS:[Ljava/lang/Object;
    return-void
.end method

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public constructor <init>(I)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput p1, p0, Lcom/b/G960H;->m:I
    return-void
.end method

.method private static log(Ljava/lang/String;)V
    .locals 1
    const-string v0, "GCAM"
    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

.method private static lockFile()Ljava/io/File;
    .locals 3
    new-instance v0, Ljava/io/File;
    invoke-static {}, Lcom/oppo/camera/MyApplication;->d()Landroid/content/Context;
    move-result-object v1
    invoke-virtual {v1}, Landroid/content/Context;->getFilesDir()Ljava/io/File;
    move-result-object v1
    const-string v2, "hdrp.lock"
    invoke-direct {v0, v1, v2}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V
    return-object v0
.end method

.method public static reset()V
    .locals 1
    const/4 v0, 0x0
    sput-boolean v0, Lcom/b/G960H;->ON:Z
    return-void
.end method

.method public static outputs(Ljava/util/LinkedHashMap;Ljava/lang/Object;Ljava/lang/Object;I)V
    .locals 12
    const/4 v0, 0x0
    sput-boolean v0, Lcom/b/G960H;->ON:Z
    :try_start
    invoke-static {}, Lcom/oppo/camera/MyApplication;->d()Landroid/content/Context;
    move-result-object v0
    const-string v1, "pref_gcam_hdrp"
    const/4 v2, 0x0
    invoke-static {v0, v1, v2}, Lcom/b/S960S;->bool(Landroid/content/Context;Ljava/lang/String;Z)Z
    move-result v1
    if-eqz v1, :off

    # mode / role line
    const-string v3, "null"
    if-eqz p1, :named
    invoke-virtual {p1}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v3
    invoke-virtual {v3}, Ljava/lang/Class;->getName()Ljava/lang/String;
    move-result-object v3
    :named
    new-instance v2, Ljava/lang/StringBuilder;
    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V
    const-string v4, "raw: session mode="
    invoke-virtual {v2, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v4, " role="
    invoke-virtual {v2, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2, p3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v4, " outputs="
    invoke-virtual {v2, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {p0}, Ljava/util/LinkedHashMap;->keySet()Ljava/util/Set;
    move-result-object v4
    invoke-virtual {v2, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;
    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v2
    invoke-static {v2}, Lcom/b/G960H;->log(Ljava/lang/String;)V

    if-eqz p1, :off
    invoke-virtual {p1}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v2
    const-class v3, Lcom/oppo/camera/e/e;
    if-ne v2, v3, :off

    # guard: last stream never delivered 5 frames -> switch the toggle off
    invoke-static {}, Lcom/b/G960H;->lockFile()Ljava/io/File;
    move-result-object v2
    invoke-virtual {v2}, Ljava/io/File;->exists()Z
    move-result v3
    if-eqz v3, :guard_ok
    invoke-virtual {v2}, Ljava/io/File;->delete()Z
    invoke-static {v0}, Lcom/b/S960S;->prefs(Landroid/content/Context;)Landroid/content/SharedPreferences;
    move-result-object v3
    invoke-interface {v3}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;
    move-result-object v3
    const-string v4, "pref_gcam_hdrp"
    const/4 v5, 0x0
    invoke-interface {v3, v4, v5}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;
    move-result-object v3
    invoke-interface {v3}, Landroid/content/SharedPreferences$Editor;->commit()Z
    const-string v3, "raw: HDR+ switched OFF - last time the RAW stream never delivered frames"
    invoke-static {v3}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    goto :off
    :guard_ok
    # plan B: no stream of our own - use OPPO's RAW reader of this session (kept by wrap())
    const-string v3, "type_still_capture_raw"
    invoke-virtual {p0, v3}, Ljava/util/LinkedHashMap;->containsKey(Ljava/lang/Object;)Z
    move-result v3
    sget-object v4, Lcom/b/G960H;->OR:Landroid/media/ImageReader;
    if-eqz v3, :no_raw
    if-nez v4, :have_raw
    :no_raw
    const-string v3, "raw: this session has no OPPO RAW stream - HDR+ test not possible here"
    invoke-static {v3}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    goto :off
    :have_raw
    sput-object v4, Lcom/b/G960H;->R:Landroid/media/ImageReader;
    invoke-virtual {v4}, Landroid/media/ImageReader;->getWidth()I
    move-result v6
    invoke-virtual {v4}, Landroid/media/ImageReader;->getHeight()I
    move-result v7
    new-instance v2, Ljava/lang/StringBuilder;
    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V
    const-string v3, "raw: OPPO RAW reader format="
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v4}, Landroid/media/ImageReader;->getImageFormat()I
    move-result v3
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v3, " maxImages="
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v4}, Landroid/media/ImageReader;->getMaxImages()I
    move-result v3
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v2
    invoke-static {v2}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    invoke-static {}, Lcom/b/G960H;->drain()V

    # handler thread
    sget-object v3, Lcom/b/G960H;->HD:Landroid/os/Handler;
    if-nez v3, :have_thread
    new-instance v3, Landroid/os/HandlerThread;
    const-string v4, "gcam-raw"
    invoke-direct {v3, v4}, Landroid/os/HandlerThread;-><init>(Ljava/lang/String;)V
    invoke-virtual {v3}, Landroid/os/HandlerThread;->start()V
    sput-object v3, Lcom/b/G960H;->TH:Landroid/os/HandlerThread;
    new-instance v4, Landroid/os/Handler;
    invoke-virtual {v3}, Landroid/os/HandlerThread;->getLooper()Landroid/os/Looper;
    move-result-object v3
    invoke-direct {v4, v3}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V
    sput-object v4, Lcom/b/G960H;->HD:Landroid/os/Handler;
    :have_thread

    const/4 v2, 0x0
    sput v2, Lcom/b/G960H;->FR:I
    sput v2, Lcom/b/G960H;->FR0:I
    sput v2, Lcom/b/G960H;->LOST:I
    sput-boolean v2, Lcom/b/G960H;->SAMPLED:Z
    sput-boolean v2, Lcom/b/G960H;->FIRED:Z
    sput-boolean v2, Lcom/b/G960H;->BURST:Z
    sput v2, Lcom/b/G960H;->PC:I
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v2
    sput-wide v2, Lcom/b/G960H;->T0:J
    sput p3, Lcom/b/G960H;->ROLE:I
    const/4 v2, 0x1
    sput-boolean v2, Lcom/b/G960H;->ON:Z

    new-instance v2, Ljava/lang/StringBuilder;
    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V
    const-string v4, "raw: HDR+ test will use OPPO's own RAW stream "
    invoke-virtual {v2, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v4, "x"
    invoke-virtual {v2, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2, v7}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v2
    invoke-static {v2}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    :off
    return-void
    :err
    move-exception v0
    const/4 v1, 0x0
    sput-boolean v1, Lcom/b/G960H;->ON:Z
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const-string v1, "raw: outputs FAILED "
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method

# close and forget every image in the ring
.method private static declared-synchronized drain()V
    .locals 2
    :loop
    sget-object v0, Lcom/b/G960H;->Q:Ljava/util/ArrayDeque;
    invoke-virtual {v0}, Ljava/util/ArrayDeque;->pollFirst()Ljava/lang/Object;
    move-result-object v0
    if-eqz v0, :done
    check-cast v0, Landroid/media/Image;
    :try_start
    invoke-virtual {v0}, Landroid/media/Image;->close()V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :loop
    goto :loop
    :done
    return-void
.end method

.method public static rep(Landroid/hardware/camera2/CaptureRequest$Builder;Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;I)Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    .locals 3
    sget-boolean v0, Lcom/b/G960H;->ON:Z
    if-eqz v0, :ret
    sget v0, Lcom/b/G960H;->ROLE:I
    if-ne p2, v0, :ret
    sget-object v0, Lcom/b/G960H;->R:Landroid/media/ImageReader;
    if-eqz v0, :ret
    :try_start
    sget-object v1, Landroid/hardware/camera2/CaptureRequest;->CONTROL_CAPTURE_INTENT:Landroid/hardware/camera2/CaptureRequest$Key;
    invoke-virtual {p0, v1}, Landroid/hardware/camera2/CaptureRequest$Builder;->get(Landroid/hardware/camera2/CaptureRequest$Key;)Ljava/lang/Object;
    move-result-object v1
    if-eqz v1, :intent_ok
    check-cast v1, Ljava/lang/Integer;
    invoke-virtual {v1}, Ljava/lang/Integer;->intValue()I
    move-result v1
    const/4 v2, 0x1
    if-ne v1, v2, :ret
    :intent_ok
    # step 1c: the RAW surface is NOT added to the preview request; the wrapper only tells us the preview runs
    new-instance v0, Lcom/b/G960H$W;
    invoke-direct {v0, p1}, Lcom/b/G960H$W;-><init>(Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;)V
    return-object v0
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :ret
    :ret
    return-object p1
.end method

.method public static declared-synchronized put(Landroid/hardware/camera2/TotalCaptureResult;)V
    .locals 4
    :try_start
    sget-object v0, Landroid/hardware/camera2/CaptureResult;->SENSOR_TIMESTAMP:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-virtual {p0, v0}, Landroid/hardware/camera2/TotalCaptureResult;->get(Landroid/hardware/camera2/CaptureResult$Key;)Ljava/lang/Object;
    move-result-object v0
    if-eqz v0, :done
    check-cast v0, Ljava/lang/Long;
    invoke-virtual {v0}, Ljava/lang/Long;->longValue()J
    move-result-wide v0
    sget v2, Lcom/b/G960H;->RI:I
    sget-object v3, Lcom/b/G960H;->TS:[J
    aput-wide v0, v3, v2
    sget-object v3, Lcom/b/G960H;->RS:[Ljava/lang/Object;
    aput-object p0, v3, v2
    add-int/lit8 v2, v2, 0x1
    and-int/lit8 v2, v2, 0x1f
    sput v2, Lcom/b/G960H;->RI:I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

.method public static declared-synchronized find(J)Landroid/hardware/camera2/TotalCaptureResult;
    .locals 5
    const/4 v0, 0x0
    :loop
    const/16 v1, 0x20
    if-ge v0, v1, :none
    sget-object v1, Lcom/b/G960H;->TS:[J
    aget-wide v2, v1, v0
    cmp-long v4, v2, p0
    if-nez v4, :next
    sget-object v1, Lcom/b/G960H;->RS:[Ljava/lang/Object;
    aget-object v1, v1, v0
    if-eqz v1, :next
    check-cast v1, Landroid/hardware/camera2/TotalCaptureResult;
    return-object v1
    :next
    add-int/lit8 v0, v0, 0x1
    goto :loop
    :none
    const/4 v0, 0x0
    return-object v0
.end method

.method public static lost(Landroid/view/Surface;)V
    .locals 2
    sget-object v0, Lcom/b/G960H;->R:Landroid/media/ImageReader;
    if-eqz v0, :done
    :try_start
    invoke-virtual {v0}, Landroid/media/ImageReader;->getSurface()Landroid/view/Surface;
    move-result-object v0
    if-ne v0, p0, :done
    sget v1, Lcom/b/G960H;->LOST:I
    add-int/lit8 v1, v1, 0x1
    sput v1, Lcom/b/G960H;->LOST:I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

.method private static declared-synchronized keep(Landroid/media/Image;)I
    .locals 2
    sget-object v0, Lcom/b/G960H;->Q:Ljava/util/ArrayDeque;
    invoke-virtual {v0, p0}, Ljava/util/ArrayDeque;->addLast(Ljava/lang/Object;)V
    :loop
    invoke-virtual {v0}, Ljava/util/ArrayDeque;->size()I
    move-result v1
    const/16 p0, 0x8
    if-le v1, p0, :done
    invoke-virtual {v0}, Ljava/util/ArrayDeque;->pollFirst()Ljava/lang/Object;
    move-result-object v1
    check-cast v1, Landroid/media/Image;
    invoke-virtual {v1}, Landroid/media/Image;->close()V
    goto :loop
    :done
    invoke-virtual {v0}, Ljava/util/ArrayDeque;->size()I
    move-result v1
    return v1
.end method

.method public static cam(Ljava/lang/Object;)V
    .locals 0
    sput-object p0, Lcom/b/G960H;->CAM:Ljava/lang/Object;
    return-void
.end method

# --- read access for com.b.hdrp.Hdrp (Java engine glue in classes5.dex)
.method public static n()I
    .locals 1
    sget v0, Lcom/b/G960H;->NC:I
    return v0
.end method

.method public static buf(I)Ljava/nio/ByteBuffer;
    .locals 1
    sget-object v0, Lcom/b/G960H;->BUF:[Ljava/nio/ByteBuffer;
    aget-object v0, v0, p0
    return-object v0
.end method

.method public static ts(I)J
    .locals 2
    sget-object v0, Lcom/b/G960H;->TSA:[J
    aget-wide v0, v0, p0
    return-wide v0
.end method

.method public static str(I)I
    .locals 1
    sget-object v0, Lcom/b/G960H;->STR:[I
    aget v0, v0, p0
    return v0
.end method

.method public static res(I)Landroid/hardware/camera2/TotalCaptureResult;
    .locals 2
    sget-object v0, Lcom/b/G960H;->TSA:[J
    aget-wide v0, v0, p0
    invoke-static {v0, v1}, Lcom/b/G960H;->find(J)Landroid/hardware/camera2/TotalCaptureResult;
    move-result-object v0
    return-object v0
.end method

.method public static mode(Ljava/lang/Object;)V
    .locals 0
    sput-object p0, Lcom/b/G960H;->MODE:Ljava/lang/Object;
    return-void
.end method

# OPPO's capture decision: request format 35 (YUV route) -> 32 (RAW route) when HDR+ is armed in Photo mode
.method public static fmt(I)I
    .locals 3
    sget-boolean v0, Lcom/b/G960H;->ON:Z
    if-eqz v0, :keep
    const/16 v0, 0x23
    if-ne p0, v0, :keep
    invoke-static {}, Lcom/b/hdrp/Hdrp;->ready()Z
    move-result v0
    if-eqz v0, :keep
    sget-object v0, Lcom/b/G960H;->MODE:Ljava/lang/Object;
    if-eqz v0, :keep
    invoke-virtual {v0}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v0
    const-class v1, Lcom/oppo/camera/e/e;
    if-ne v0, v1, :keep
    :try_start
    invoke-static {}, Lcom/b/G960H;->lockFile()Ljava/io/File;
    move-result-object v0
    invoke-virtual {v0}, Ljava/io/File;->createNewFile()Z
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :locked
    :locked
    const/4 v0, 0x0
    sput v0, Lcom/b/G960H;->NC:I
    sput v0, Lcom/b/G960H;->SR:I
    const-wide/16 v1, 0x0
    sput-wide v1, Lcom/b/G960H;->SRT:J
    const/4 v0, 0x1
    sput-boolean v0, Lcom/b/G960H;->CAP:Z
    const-string v0, "hdrp: shutter - OPPO's capture switched from the YUV route (35) to its RAW route (32)"
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    const/16 v0, 0x20
    return v0
    :keep
    return p0
.end method

.method public static wrapc(Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;)Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    .locals 1
    sget-boolean v0, Lcom/b/G960H;->CAP:Z
    if-eqz v0, :ret
    if-eqz p0, :ret
    new-instance v0, Lcom/b/G960H$W;
    invoke-direct {v0, p0}, Lcom/b/G960H$W;-><init>(Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;)V
    const/4 p0, 0x1
    iput-boolean p0, v0, Lcom/b/G960H$W;->s:Z
    return-object v0
    :ret
    return-object p0
.end method

# result of a shutter-shot request (preview results no longer go into the table, they flooded it)
.method public static declared-synchronized sres(Landroid/hardware/camera2/TotalCaptureResult;)V
    .locals 2
    invoke-static {p0}, Lcom/b/G960H;->put(Landroid/hardware/camera2/TotalCaptureResult;)V
    sget v0, Lcom/b/G960H;->SR:I
    add-int/lit8 v0, v0, 0x1
    sput v0, Lcom/b/G960H;->SR:I
    const/4 v1, 0x1
    if-ne v0, v1, :done
    :try_start
    sget-object v0, Landroid/hardware/camera2/CaptureResult;->SENSOR_TIMESTAMP:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-virtual {p0, v0}, Landroid/hardware/camera2/TotalCaptureResult;->get(Landroid/hardware/camera2/CaptureResult$Key;)Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Ljava/lang/Long;
    invoke-virtual {v0}, Ljava/lang/Long;->longValue()J
    move-result-wide v0
    sput-wide v0, Lcom/b/G960H;->SRT:J
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

# called by OPPO's image listeners right after acquireNextImage: copy RAW_SENSOR frames of the armed shot
.method public static declared-synchronized seen(Landroid/media/Image;)V
    .locals 10
    sget-boolean v0, Lcom/b/G960H;->CAP:Z
    if-eqz v0, :ret
    if-eqz p0, :ret
    :try_start
    invoke-virtual {p0}, Landroid/media/Image;->getFormat()I
    move-result v0
    const/16 v1, 0x20
    if-ne v0, v1, :ret
    sget v9, Lcom/b/G960H;->NC:I
    const/16 v1, 0xc
    if-lt v9, v1, :room
    const-string v0, "hdrp: more than 12 RAW frames - extra frame not copied"
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
    :room
    sget-object v1, Lcom/b/G960H;->BUF:[Ljava/nio/ByteBuffer;
    if-nez v1, :have_pool
    const/16 v1, 0xc
    new-array v2, v1, [Ljava/nio/ByteBuffer;
    sput-object v2, Lcom/b/G960H;->BUF:[Ljava/nio/ByteBuffer;
    new-array v2, v1, [J
    sput-object v2, Lcom/b/G960H;->TSA:[J
    new-array v2, v1, [I
    sput-object v2, Lcom/b/G960H;->STR:[I
    sget-object v1, Lcom/b/G960H;->BUF:[Ljava/nio/ByteBuffer;
    :have_pool
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v6
    invoke-virtual {p0}, Landroid/media/Image;->getPlanes()[Landroid/media/Image$Plane;
    move-result-object v2
    const/4 v3, 0x0
    aget-object v2, v2, v3
    invoke-virtual {v2}, Landroid/media/Image$Plane;->getBuffer()Ljava/nio/ByteBuffer;
    move-result-object v3
    invoke-virtual {v3}, Ljava/nio/ByteBuffer;->duplicate()Ljava/nio/ByteBuffer;
    move-result-object v3
    invoke-virtual {v3}, Ljava/nio/ByteBuffer;->remaining()I
    move-result v4
    aget-object v5, v1, v9
    if-eqz v5, :alloc
    invoke-virtual {v5}, Ljava/nio/ByteBuffer;->capacity()I
    move-result v8
    if-ge v8, v4, :have_buf
    :alloc
    invoke-static {v4}, Ljava/nio/ByteBuffer;->allocateDirect(I)Ljava/nio/ByteBuffer;
    move-result-object v5
    aput-object v5, v1, v9
    :have_buf
    invoke-virtual {v5}, Ljava/nio/ByteBuffer;->clear()Ljava/nio/Buffer;
    invoke-virtual {v5, v3}, Ljava/nio/ByteBuffer;->put(Ljava/nio/ByteBuffer;)Ljava/nio/ByteBuffer;
    sget-object v1, Lcom/b/G960H;->TSA:[J
    invoke-virtual {p0}, Landroid/media/Image;->getTimestamp()J
    move-result-wide v4
    aput-wide v4, v1, v9
    sget-object v1, Lcom/b/G960H;->STR:[I
    invoke-virtual {v2}, Landroid/media/Image$Plane;->getRowStride()I
    move-result v3
    aput v3, v1, v9
    add-int/lit8 v1, v9, 0x1
    sput v1, Lcom/b/G960H;->NC:I
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v8
    sput-wide v8, Lcom/b/G960H;->LASTT:J
    sub-long/2addr v8, v6
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v6, "hdrp: RAW frame "
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " copied in "
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v8, v9}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v6, " ms, "
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {p0}, Landroid/media/Image;->getWidth()I
    move-result v6
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, "x"
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {p0}, Landroid/media/Image;->getHeight()I
    move-result v6
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " stride "
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " ts="
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v4, v5}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    # summary 1.5 s after the last frame
    sget-object v0, Lcom/b/G960H;->HD:Landroid/os/Handler;
    if-eqz v0, :ret
    new-instance v1, Lcom/b/G960H;
    const/4 v2, 0x3
    invoke-direct {v1, v2}, Lcom/b/G960H;-><init>(I)V
    const-wide/16 v2, 0x5dc
    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    :ret
    return-void
    :err
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const-string v1, "hdrp: RAW copy FAILED "
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method

.method private static lfr(ILandroid/hardware/camera2/TotalCaptureResult;)V
    .locals 3
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "hdrp: frame "
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    if-nez p1, :have
    const-string v1, ": no capture result"
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    goto :out
    :have
    const-string v1, ": exposure ns "
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_EXPOSURE_TIME:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-virtual {p1, v1}, Landroid/hardware/camera2/TotalCaptureResult;->get(Landroid/hardware/camera2/CaptureResult$Key;)Ljava/lang/Object;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;
    const-string v1, ", ISO "
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_SENSITIVITY:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-virtual {p1, v1}, Landroid/hardware/camera2/TotalCaptureResult;->get(Landroid/hardware/camera2/CaptureResult$Key;)Ljava/lang/Object;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;
    const-string v1, ", boost "
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->CONTROL_POST_RAW_SENSITIVITY_BOOST:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-virtual {p1, v1}, Landroid/hardware/camera2/TotalCaptureResult;->get(Landroid/hardware/camera2/CaptureResult$Key;)Ljava/lang/Object;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;
    :out
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method

# 1.5 s after the last RAW frame of the shot: per-frame exposure/ISO, match count, metadata sample; guard cleared
.method private static declared-synchronized shot()V
    .locals 8
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v0
    sget-wide v2, Lcom/b/G960H;->LASTT:J
    sub-long/2addr v0, v2
    const-wide/16 v2, 0x578
    cmp-long v0, v0, v2
    if-gez v0, :go
    return-void
    :go
    sget-boolean v0, Lcom/b/G960H;->CAP:Z
    if-nez v0, :run
    return-void
    :run
    const/4 v0, 0x0
    sput-boolean v0, Lcom/b/G960H;->CAP:Z
    :try_start
    sget v4, Lcom/b/G960H;->NC:I
    const/4 v5, 0x0
    const/4 v6, 0x0
    const/4 v7, 0x0
    :loop
    if-ge v5, v4, :done
    sget-object v2, Lcom/b/G960H;->TSA:[J
    aget-wide v0, v2, v5
    invoke-static {v0, v1}, Lcom/b/G960H;->find(J)Landroid/hardware/camera2/TotalCaptureResult;
    move-result-object v0
    add-int/lit8 v1, v5, 0x1
    invoke-static {v1, v0}, Lcom/b/G960H;->lfr(ILandroid/hardware/camera2/TotalCaptureResult;)V
    if-eqz v0, :next
    add-int/lit8 v6, v6, 0x1
    move-object v7, v0
    :next
    add-int/lit8 v5, v5, 0x1
    goto :loop
    :done
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "hdrp: SHOT SUMMARY RAW frames="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v4}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, " matched="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, " | shot results="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget v1, Lcom/b/G960H;->SR:I
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, " first result ts="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget-wide v2, Lcom/b/G960H;->SRT:J
    invoke-virtual {v0, v2, v3}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    if-eqz v7, :nosample
    check-cast v7, Landroid/hardware/camera2/TotalCaptureResult;
    invoke-static {v7}, Lcom/b/G960H;->sample(Landroid/hardware/camera2/TotalCaptureResult;)V
    :nosample
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    invoke-static {}, Lcom/b/hdrp/Hdrp;->afterShot()V
    return-void
    :err
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const-string v1, "hdrp: summary FAILED "
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    invoke-static {}, Lcom/b/G960H;->unlock()V
    return-void
.end method

.method public static max(I)I
    .locals 3
    :try_start
    invoke-static {}, Lcom/oppo/camera/MyApplication;->d()Landroid/content/Context;
    move-result-object v0
    const-string v1, "pref_gcam_hdrp"
    const/4 v2, 0x0
    invoke-static {v0, v1, v2}, Lcom/b/S960S;->bool(Landroid/content/Context;Ljava/lang/String;Z)Z
    move-result v0
    if-eqz v0, :keep
    const/16 v0, 0xc
    if-ge p0, v0, :keep
    return v0
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :keep
    :keep
    return p0
.end method

.method public static wrap(Landroid/media/ImageReader;Landroid/media/ImageReader$OnImageAvailableListener;)Landroid/media/ImageReader$OnImageAvailableListener;
    .locals 1
    sput-object p0, Lcom/b/G960H;->OR:Landroid/media/ImageReader;
    new-instance v0, Lcom/b/G960H$L;
    invoke-direct {v0, p1}, Lcom/b/G960H$L;-><init>(Landroid/media/ImageReader$OnImageAvailableListener;)V
    return-object v0
.end method

# true = the frame belonged to our burst and was taken; false = give it to OPPO's listener
.method public static take(Landroid/media/ImageReader;)Z
    .locals 1
    sget-boolean v0, Lcom/b/G960H;->BURST:Z
    if-nez v0, :ours
    return v0
    :ours
    invoke-static {p0}, Lcom/b/G960H;->img(Landroid/media/ImageReader;)V
    const/4 v0, 0x1
    return v0
.end method

.method private static img(Landroid/media/ImageReader;)V
    .locals 8
    :try_start
    invoke-virtual {p0}, Landroid/media/ImageReader;->acquireNextImage()Landroid/media/Image;
    move-result-object v0
    if-eqz v0, :done
    sget v1, Lcom/b/G960H;->FR:I
    add-int/lit8 v1, v1, 0x1
    sput v1, Lcom/b/G960H;->FR:I
    invoke-virtual {v0}, Landroid/media/Image;->getTimestamp()J
    move-result-wide v2
    invoke-static {v0}, Lcom/b/G960H;->keep(Landroid/media/Image;)I
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v4
    sget-wide v6, Lcom/b/G960H;->TF:J
    sub-long/2addr v4, v6
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v6, "burst: RAW frame "
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " at +"
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v4, v5}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v6, " ms, ts="
    invoke-virtual {v0, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v2, v3}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    :done
    return-void
    :err
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const-string v1, "burst: image FAILED "
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method

# called for every preview result (from G960H$W). First one of a session: the session works with our
# extra stream -> clear the guard and schedule the test burst in 3 s.
.method public static prev(Landroid/hardware/camera2/CameraCaptureSession;)V
    .locals 5
    sget v0, Lcom/b/G960H;->PC:I
    add-int/lit8 v0, v0, 0x1
    sput v0, Lcom/b/G960H;->PC:I
    sget-boolean v0, Lcom/b/G960H;->FIRED:Z
    if-nez v0, :done
    sget-boolean v0, Lcom/b/G960H;->ON:Z
    if-eqz v0, :done
    const/4 v0, 0x1
    sput-boolean v0, Lcom/b/G960H;->FIRED:Z
    sput-object p0, Lcom/b/G960H;->SESS:Landroid/hardware/camera2/CameraCaptureSession;
    :try_start
    invoke-static {}, Lcom/b/G960H;->lockFile()Ljava/io/File;
    move-result-object v0
    invoke-virtual {v0}, Ljava/io/File;->delete()Z
    const-string v0, "raw: preview is running (guard cleared) - HDR+ test armed, press the shutter"
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

.method public run()V
    .locals 2
    iget v0, p0, Lcom/b/G960H;->m:I
    if-nez v0, :not0
    invoke-static {}, Lcom/b/G960H;->fire()V
    return-void
    :not0
    const/4 v1, 0x1
    if-ne v0, v1, :not1
    invoke-static {}, Lcom/b/G960H;->summary()V
    return-void
    :not1
    const/4 v1, 0x3
    if-ne v0, v1, :not3
    invoke-static {}, Lcom/b/G960H;->shot()V
    return-void
    :not3
    invoke-static {}, Lcom/b/G960H;->after()V
    return-void
.end method

# one burst of 8 TEMPLATE_STILL_CAPTURE requests that target only our RAW10 surface
.method private static fire()V
    .locals 8
    :try_start
    sget-boolean v0, Lcom/b/G960H;->ON:Z
    if-nez v0, :go
    const-string v0, "burst: skipped (session changed before the burst)"
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
    :go
    sget-object v0, Lcom/b/G960H;->SESS:Landroid/hardware/camera2/CameraCaptureSession;
    sget-object v1, Lcom/b/G960H;->R:Landroid/media/ImageReader;
    invoke-static {}, Lcom/b/G960H;->lockFile()Ljava/io/File;
    move-result-object v2
    invoke-virtual {v2}, Ljava/io/File;->createNewFile()Z
    # OPPO's own RAW capture builder (createRawCaptureBuilder): STILL_CAPTURE + OPPO's settings,
    # targets = preview surface(s) + OPPO's RAW surface. A bare request with only the RAW target crashed the HAL.
    sget-object v2, Lcom/b/G960H;->CAM:Ljava/lang/Object;
    check-cast v2, Lcom/oppo/camera/f/g;
    invoke-static {v2}, Lcom/oppo/camera/f/g;->K(Lcom/oppo/camera/f/g;)Landroid/hardware/camera2/CaptureRequest$Builder;
    move-result-object v2
    if-nez v2, :have_builder
    const-string v2, "burst: OPPO's RAW builder returned null - not firing"
    invoke-static {v2}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    invoke-static {}, Lcom/b/G960H;->unlock()V
    return-void
    :have_builder
    const/4 v3, 0x1
    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;
    move-result-object v3
    sget-object v4, Landroid/hardware/camera2/CaptureRequest;->STATISTICS_LENS_SHADING_MAP_MODE:Landroid/hardware/camera2/CaptureRequest$Key;
    invoke-virtual {v2, v4, v3}, Landroid/hardware/camera2/CaptureRequest$Builder;->set(Landroid/hardware/camera2/CaptureRequest$Key;Ljava/lang/Object;)V
    invoke-virtual {v2}, Landroid/hardware/camera2/CaptureRequest$Builder;->build()Landroid/hardware/camera2/CaptureRequest;
    move-result-object v2
    new-instance v3, Ljava/util/ArrayList;
    invoke-direct {v3}, Ljava/util/ArrayList;-><init>()V
    const/4 v4, 0x0
    :loop
    const/16 v5, 0x8
    if-ge v4, v5, :filled
    invoke-virtual {v3, v2}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z
    add-int/lit8 v4, v4, 0x1
    goto :loop
    :filled
    const/4 v4, 0x0
    sput v4, Lcom/b/G960H;->BR:I
    sput v4, Lcom/b/G960H;->BF:I
    sput v4, Lcom/b/G960H;->FR:I
    sput v4, Lcom/b/G960H;->LOST:I
    sget v4, Lcom/b/G960H;->PC:I
    sput v4, Lcom/b/G960H;->PC0:I
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v4
    sput-wide v4, Lcom/b/G960H;->TF:J
    new-instance v4, Lcom/b/G960H$B;
    invoke-direct {v4}, Lcom/b/G960H$B;-><init>()V
    sget-object v5, Lcom/b/G960H;->HD:Landroid/os/Handler;
    const/4 v6, 0x1
    sput-boolean v6, Lcom/b/G960H;->BURST:Z
    const-string v6, "burst: submitting 8 requests from OPPO's RAW capture builder (preview + RAW targets)"
    invoke-static {v6}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    invoke-virtual {v0, v3, v4, v5}, Landroid/hardware/camera2/CameraCaptureSession;->captureBurst(Ljava/util/List;Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;Landroid/os/Handler;)I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    return-void
    :err
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const/4 v1, 0x0
    sput-boolean v1, Lcom/b/G960H;->BURST:Z
    const-string v1, "burst: FAILED to submit: "
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    invoke-static {}, Lcom/b/G960H;->unlock()V
    return-void
.end method

.method private static unlock()V
    .locals 1
    :try_start
    invoke-static {}, Lcom/b/G960H;->lockFile()Ljava/io/File;
    move-result-object v0
    invoke-virtual {v0}, Ljava/io/File;->delete()Z
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

# burst callbacks (G960H$B), all on the gcam-raw thread
.method public static bres(Landroid/hardware/camera2/TotalCaptureResult;)V
    .locals 1
    invoke-static {p0}, Lcom/b/G960H;->put(Landroid/hardware/camera2/TotalCaptureResult;)V
    sget v0, Lcom/b/G960H;->BR:I
    add-int/lit8 v0, v0, 0x1
    sput v0, Lcom/b/G960H;->BR:I
    return-void
.end method

.method public static bfail(Landroid/hardware/camera2/CaptureFailure;)V
    .locals 3
    sget v0, Lcom/b/G960H;->BF:I
    add-int/lit8 v0, v0, 0x1
    sput v0, Lcom/b/G960H;->BF:I
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "burst: capture FAILED reason="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {p0}, Landroid/hardware/camera2/CaptureFailure;->getReason()I
    move-result v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, " (0=error 1=flushed) imageCaptured="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {p0}, Landroid/hardware/camera2/CaptureFailure;->wasImageCaptured()Z
    move-result v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static bdone(I)V
    .locals 6
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    if-nez p0, :ab
    const-string v1, "burst: sequence completed after "
    goto :hd
    :ab
    const-string v1, "burst: sequence ABORTED after "
    :hd
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v2
    sget-wide v4, Lcom/b/G960H;->TF:J
    sub-long/2addr v2, v4
    invoke-virtual {v0, v2, v3}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v1, " ms"
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    invoke-static {}, Lcom/b/G960H;->unlock()V
    :try_start
    new-instance v1, Lcom/b/G960H;
    const/4 v0, 0x1
    invoke-direct {v1, v0}, Lcom/b/G960H;-><init>(I)V
    sget-object v0, Lcom/b/G960H;->HD:Landroid/os/Handler;
    const-wide/16 v2, 0x2bc
    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

# 0.7 s after the burst ended: totals, frame/result matching, preview frames during the burst, metadata sample
.method private static declared-synchronized summary()V
    .locals 10
    :try_start
    const/4 v4, 0x0
    const/4 v5, 0x0
    const/4 v9, 0x0
    sget-object v6, Lcom/b/G960H;->Q:Ljava/util/ArrayDeque;
    invoke-virtual {v6}, Ljava/util/ArrayDeque;->iterator()Ljava/util/Iterator;
    move-result-object v6
    :it
    invoke-interface {v6}, Ljava/util/Iterator;->hasNext()Z
    move-result v7
    if-eqz v7, :it_done
    invoke-interface {v6}, Ljava/util/Iterator;->next()Ljava/lang/Object;
    move-result-object v7
    check-cast v7, Landroid/media/Image;
    add-int/lit8 v4, v4, 0x1
    invoke-virtual {v7}, Landroid/media/Image;->getTimestamp()J
    move-result-wide v7
    invoke-static {v7, v8}, Lcom/b/G960H;->find(J)Landroid/hardware/camera2/TotalCaptureResult;
    move-result-object v7
    if-eqz v7, :it
    add-int/lit8 v5, v5, 0x1
    move-object v9, v7
    goto :it
    :it_done
    new-instance v6, Ljava/lang/StringBuilder;
    invoke-direct {v6}, Ljava/lang/StringBuilder;-><init>()V
    const-string v7, "burst: SUMMARY RAW frames="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget v7, Lcom/b/G960H;->FR:I
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, " results="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget v7, Lcom/b/G960H;->BR:I
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, " failed="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget v7, Lcom/b/G960H;->BF:I
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, " lost="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget v7, Lcom/b/G960H;->LOST:I
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, " kept="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6, v4}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, " matched="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, " | preview frames since burst start="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget v7, Lcom/b/G960H;->PC:I
    sget v8, Lcom/b/G960H;->PC0:I
    sub-int/2addr v7, v8
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, " in ms="
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v0
    sget-wide v2, Lcom/b/G960H;->TF:J
    sub-long v2, v0, v2
    invoke-virtual {v6, v2, v3}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v6
    invoke-static {v6}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    if-eqz v9, :no_sample
    check-cast v9, Landroid/hardware/camera2/TotalCaptureResult;
    invoke-static {v9}, Lcom/b/G960H;->sample(Landroid/hardware/camera2/TotalCaptureResult;)V
    :no_sample
    # preview check for the next 3 s
    sget v7, Lcom/b/G960H;->PC:I
    sput v7, Lcom/b/G960H;->PC0:I
    sput-wide v0, Lcom/b/G960H;->TF:J
    new-instance v1, Lcom/b/G960H;
    const/4 v0, 0x2
    invoke-direct {v1, v0}, Lcom/b/G960H;-><init>(I)V
    sget-object v0, Lcom/b/G960H;->HD:Landroid/os/Handler;
    const-wide/16 v2, 0xbb8
    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    return-void
    :err
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const-string v1, "burst: summary FAILED "
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method

# 3 s later: is the preview still running at full speed? then free the RAW frames
.method private static after()V
    .locals 6
    :try_start
    sget v0, Lcom/b/G960H;->PC:I
    sget v1, Lcom/b/G960H;->PC0:I
    sub-int/2addr v0, v1
    int-to-long v0, v0
    const-wide/16 v2, 0x2710
    mul-long/2addr v0, v2
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v2
    sget-wide v4, Lcom/b/G960H;->TF:J
    sub-long/2addr v2, v4
    div-long/2addr v0, v2
    new-instance v2, Ljava/lang/StringBuilder;
    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V
    const-string v3, "burst: preview after the burst, fps x10="
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2, v0, v1}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v3, " - test done, RAW frames freed"
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v2
    invoke-static {v2}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    const/4 v2, 0x0
    sput-boolean v2, Lcom/b/G960H;->BURST:Z
    invoke-static {}, Lcom/b/G960H;->drain()V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

.method private static str(Ljava/lang/Object;)Ljava/lang/String;
    .locals 1
    if-nez p0, :nn
    const-string v0, "null"
    return-object v0
    :nn
    instance-of v0, p0, [F
    if-eqz v0, :not_f
    check-cast p0, [F
    invoke-static {p0}, Ljava/util/Arrays;->toString([F)Ljava/lang/String;
    move-result-object v0
    return-object v0
    :not_f
    instance-of v0, p0, [I
    if-eqz v0, :not_i
    check-cast p0, [I
    invoke-static {p0}, Ljava/util/Arrays;->toString([I)Ljava/lang/String;
    move-result-object v0
    return-object v0
    :not_i
    instance-of v0, p0, [Ljava/lang/Object;
    if-eqz v0, :plain
    check-cast p0, [Ljava/lang/Object;
    invoke-static {p0}, Ljava/util/Arrays;->deepToString([Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v0
    return-object v0
    :plain
    invoke-static {p0}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v0
    return-object v0
.end method

.method private static kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    .locals 2
    invoke-virtual {p0, p2}, Landroid/hardware/camera2/TotalCaptureResult;->get(Landroid/hardware/camera2/CaptureResult$Key;)Ljava/lang/Object;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->str(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v0
    const-string v1, "raw: meta "
    invoke-virtual {v1, p1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    const-string p1, " = "
    invoke-virtual {v1, p1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    invoke-static {v1}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method

.method private static sample(Landroid/hardware/camera2/TotalCaptureResult;)V
    .locals 3
    :try_start
    const-string v0, "exposure ns"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_EXPOSURE_TIME:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "ISO"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_SENSITIVITY:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "raw boost"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->CONTROL_POST_RAW_SENSITIVITY_BOOST:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "frame duration ns"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_FRAME_DURATION:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "black level"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_DYNAMIC_BLACK_LEVEL:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "white level"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_DYNAMIC_WHITE_LEVEL:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "wb gains"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->COLOR_CORRECTION_GAINS:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "ccm"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->COLOR_CORRECTION_TRANSFORM:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "neutral"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_NEUTRAL_COLOR_POINT:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "noise profile"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->SENSOR_NOISE_PROFILE:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    const-string v0, "shading mode"
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->STATISTICS_LENS_SHADING_MAP_MODE:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-static {p0, v0, v1}, Lcom/b/G960H;->kv(Landroid/hardware/camera2/TotalCaptureResult;Ljava/lang/String;Landroid/hardware/camera2/CaptureResult$Key;)V
    sget-object v1, Landroid/hardware/camera2/CaptureResult;->STATISTICS_LENS_SHADING_CORRECTION_MAP:Landroid/hardware/camera2/CaptureResult$Key;
    invoke-virtual {p0, v1}, Landroid/hardware/camera2/TotalCaptureResult;->get(Landroid/hardware/camera2/CaptureResult$Key;)Ljava/lang/Object;
    move-result-object v1
    const-string v0, "raw: meta shading map = none"
    if-eqz v1, :sm_log
    check-cast v1, Landroid/hardware/camera2/params/LensShadingMap;
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v2, "raw: meta shading map = "
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Landroid/hardware/camera2/params/LensShadingMap;->getColumnCount()I
    move-result v2
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v2, "x"
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Landroid/hardware/camera2/params/LensShadingMap;->getRowCount()I
    move-result v2
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    :sm_log
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    return-void
    :err
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const-string v1, "raw: sample FAILED "
    invoke-virtual {v1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/b/G960H;->log(Ljava/lang/String;)V
    return-void
.end method
