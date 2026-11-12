.class public Lcom/b/G960H$W;
.super Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
.source "G960H.java"

# Wraps OPPO's preview capture callback: records every TotalCaptureResult for the RAW ring
# (matched to RAW images by SENSOR_TIMESTAMP), then passes every event through unchanged.

.field public d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;

.field public s:Z

.method public constructor <init>(Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;)V
    .locals 0
    invoke-direct {p0}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;-><init>()V
    iput-object p1, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    return-void
.end method

.method public onCaptureStarted(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;JJ)V
    .locals 0
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual/range {p0 .. p6}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onCaptureStarted(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;JJ)V
    :r
    return-void
.end method

.method public onReadoutStarted(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;JJ)V
    .locals 0
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual/range {p0 .. p6}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onReadoutStarted(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;JJ)V
    :r
    return-void
.end method

.method public onCaptureProgressed(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/CaptureResult;)V
    .locals 0
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual {p0, p1, p2, p3}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onCaptureProgressed(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/CaptureResult;)V
    :r
    return-void
.end method

.method public onCaptureCompleted(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/TotalCaptureResult;)V
    .locals 1
    iget-boolean v0, p0, Lcom/b/G960H$W;->s:Z
    if-eqz v0, :preview
    invoke-static {p3}, Lcom/b/G960H;->sres(Landroid/hardware/camera2/TotalCaptureResult;)V
    goto :passed
    :preview
    invoke-static {p1}, Lcom/b/G960H;->prev(Landroid/hardware/camera2/CameraCaptureSession;)V
    :passed
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual {p0, p1, p2, p3}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onCaptureCompleted(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/TotalCaptureResult;)V
    :r
    return-void
.end method

.method public onCaptureFailed(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/CaptureFailure;)V
    .locals 0
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual {p0, p1, p2, p3}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onCaptureFailed(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/CaptureFailure;)V
    :r
    return-void
.end method

.method public onCaptureSequenceCompleted(Landroid/hardware/camera2/CameraCaptureSession;IJ)V
    .locals 0
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual {p0, p1, p2, p3, p4}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onCaptureSequenceCompleted(Landroid/hardware/camera2/CameraCaptureSession;IJ)V
    :r
    return-void
.end method

.method public onCaptureSequenceAborted(Landroid/hardware/camera2/CameraCaptureSession;I)V
    .locals 0
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual {p0, p1, p2}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onCaptureSequenceAborted(Landroid/hardware/camera2/CameraCaptureSession;I)V
    :r
    return-void
.end method

.method public onCaptureBufferLost(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/view/Surface;J)V
    .locals 0
    invoke-static {p3}, Lcom/b/G960H;->lost(Landroid/view/Surface;)V
    iget-object p0, p0, Lcom/b/G960H$W;->d:Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
    if-eqz p0, :r
    invoke-virtual/range {p0 .. p5}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;->onCaptureBufferLost(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/view/Surface;J)V
    :r
    return-void
.end method
