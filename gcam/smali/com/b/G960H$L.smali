.class public Lcom/b/G960H$L;
.super Ljava/lang/Object;
.source "G960H.java"

.implements Landroid/media/ImageReader$OnImageAvailableListener;

# wraps OPPO's listener on its RAW reader (plan B): frames of our own burst are taken by G960H, the rest pass through

.field public d:Landroid/media/ImageReader$OnImageAvailableListener;

.method public constructor <init>(Landroid/media/ImageReader$OnImageAvailableListener;)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lcom/b/G960H$L;->d:Landroid/media/ImageReader$OnImageAvailableListener;
    return-void
.end method

.method public onImageAvailable(Landroid/media/ImageReader;)V
    .locals 1
    invoke-static {p1}, Lcom/b/G960H;->take(Landroid/media/ImageReader;)Z
    move-result v0
    if-nez v0, :done
    iget-object v0, p0, Lcom/b/G960H$L;->d:Landroid/media/ImageReader$OnImageAvailableListener;
    if-eqz v0, :done
    invoke-interface {v0, p1}, Landroid/media/ImageReader$OnImageAvailableListener;->onImageAvailable(Landroid/media/ImageReader;)V
    :done
    return-void
.end method
