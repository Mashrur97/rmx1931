#!/system/bin/sh
# Test: restore the slow-mo title tag on one clip so the gallery treats it as slow-mo.
# Only changes the MediaStore "title" field, not the video file.
U=content://media/external/video/media/1984
echo "before:"
content query --uri $U --projection _id:_display_name:title
content update --uri $U --bind 'title:s:slow_motion_hfr_240\:0,0,0,0'
echo "after:"
content query --uri $U --projection _id:_display_name:title
am force-stop com.oneplus.gallery
echo "done - open OnePlus Gallery and check the clip"
