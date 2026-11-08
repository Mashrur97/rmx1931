# Rebuild an APK zip, replacing some entries, keeping order/compression of the rest.
# Stored entries are aligned (4 bytes, .so files 4096) like zipalign -p.
# usage: rezip.py in.apk out.apk name=file [name=file ...]
import sys, struct, zlib, zipfile
src, dst = sys.argv[1], sys.argv[2]
repl = dict(a.split('=', 1) for a in sys.argv[3:])
raw = open(src, 'rb').read()
zin = zipfile.ZipFile(src)
out = bytearray(); cd = bytearray(); n = 0
for i in zin.infolist():
    if i.filename.startswith('META-INF/') and i.filename.endswith(('.SF', '.RSA', '.DSA', '.EC', 'MANIFEST.MF')):
        continue  # old v1 signature is stale anyway; v2 is what counts
    h = i.header_offset
    nl, el = struct.unpack_from('<HH', raw, h + 26)
    name = raw[h + 30:h + 30 + nl]
    if i.filename in repl:
        data = open(repl[i.filename], 'rb').read()
        crc = zlib.crc32(data) & 0xffffffff
        if i.compress_type == 8:
            c = zlib.compressobj(9, zlib.DEFLATED, -15); comp = c.compress(data) + c.flush()
        else:
            comp = data
        usize = len(data)
    else:
        comp = raw[h + 30 + nl + el:h + 30 + nl + el + i.compress_size]
        crc, usize = i.CRC, i.file_size
    extra = b''
    if i.compress_type == 0:
        align = 4096 if i.filename.endswith('.so') else 4
        pos = len(out) + 30 + nl
        pad = (-pos) % align
        if pad and pad < 4: pad += align
        if pad: extra = struct.pack('<HH', 0xd935, pad - 4) + b'\0' * (pad - 4)
    off = len(out)
    flags = i.flag_bits & ~0x08
    out += struct.pack('<IHHHHHIIIHH', 0x04034b50, 20, flags, i.compress_type, i.date_time and 0 or 0, 0x21,
                       crc, len(comp), usize, nl, len(extra)) + name + extra + comp
    cd += struct.pack('<IHHHHHHIIIHHHHHII', 0x02014b50, 20, 20, flags, i.compress_type, 0, 0x21,
                      crc, len(comp), usize, nl, 0, 0, 0, 0, 0, off) + name
    n += 1
cdo = len(out)
out += cd + struct.pack('<IHHHHIIH', 0x06054b50, 0, 0, n, n, len(cd), cdo, 0)
open(dst, 'wb').write(out)
print('rebuilt', dst, n, 'entries')
