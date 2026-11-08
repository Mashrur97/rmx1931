# Add a 3GPP 'titl' (title) tag inside moov/udta, taking the space from the 'free' box
# right after moov, so mdat and its chunk offsets don't move.
# usage: addtitle.py in.mp4 out.mp4 "title text"
import sys, struct
src, dst, title = sys.argv[1], sys.argv[2], sys.argv[3]
b = bytearray(open(src, 'rb').read())

def boxes(start, end):
    o = start
    while o < end:
        s, t = struct.unpack_from('>I4s', b, o)
        yield o, s, t
        o += s

top = list(boxes(0, len(b)))
i = [t for _, _, t in top].index(b'moov')
mo, ms, _ = top[i]
fo, fs, ft = top[i + 1]
assert ft == b'free', 'need a free box right after moov'
assert not any(t == b'udta' for _, _, t in boxes(mo + 8, mo + ms)), 'udta already present'

text = title.encode() + b'\0'
titl = b'titl' + b'\0\0\0\0' + struct.pack('>H', 0x15c7) + text   # version/flags, lang 'eng'
titl = struct.pack('>I', len(titl) + 4) + titl
udta = struct.pack('>I', len(titl) + 8) + b'udta' + titl
n = len(udta)
assert fs - n >= 8, 'not enough free space'

out = b[:mo] + struct.pack('>I', ms + n) + b[mo + 4:mo + ms] + udta \
    + struct.pack('>I', fs - n) + b'free' + b'\0' * (fs - n - 8) + b[fo + fs:]
assert len(out) == len(b)
open(dst, 'wb').write(out)
print('added', n, 'bytes of udta/titl; file size unchanged')
