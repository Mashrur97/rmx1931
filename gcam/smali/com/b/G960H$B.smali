.class public Lcom/b/G960H$B;
.super Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;
.source "G960H.java"

# callback of the test burst (step 1c): results go to the timestamp table, failures are logged

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Landroid/hardware/camera2/CameraCaptureSession$CaptureCallback;-><init>()V
    return-void
.end method

.method public onCaptureCompleted(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/TotalCaptureResult;)V
    .locals 0
    invoke-static {p3}, Lcom/b/G960H;->bres(Landroid/hardware/camera2/TotalCaptureResult;)V
    return-void
.end method

.method public onCaptureFailed(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/hardware/camera2/CaptureFailure;)V
    .locals 0
    invoke-static {p3}, Lcom/b/G960H;->bfail(Landroid/hardware/camera2/CaptureFailure;)V
    return-void
.end method

.method public onCaptureSequenceCompleted(Landroid/hardware/camera2/CameraCaptureSession;IJ)V
    .locals 0
    const/4 p1, 0x0
    invoke-static {p1}, Lcom/b/G960H;->bdone(I)V
    return-void
.end method

.method public onCaptureSequenceAborted(Landroid/hardware/camera2/CameraCaptureSession;I)V
    .locals 0
    const/4 p1, 0x1
    invoke-static {p1}, Lcom/b/G960H;->bdone(I)V
    return-void
.end method

.method public onCaptureBufferLost(Landroid/hardware/camera2/CameraCaptureSession;Landroid/hardware/camera2/CaptureRequest;Landroid/view/Surface;J)V
    .locals 0
    invoke-static {p3}, Lcom/b/G960H;->lost(Landroid/view/Surface;)V
    return-void
.end method
