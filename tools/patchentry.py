# Replace the contents of a STORED zip entry in place (same size), fixing both CRCs.
# usage: patchentry.py in.apk out.apk entry_name new_file
import sys, struct, zlib, zipfile
src, dst, name, newf = sys.argv[1:5]
apk = bytearray(open(src, 'rb').read()); new = open(newf, 'rb').read()
i = zipfile.ZipFile(src).getinfo(name)
assert i.compress_type == 0 and i.file_size == len(new), 'entry must be stored and same size'
h = i.header_offset
assert apk[h:h + 4] == b'PK\x03\x04'
nl, el = struct.unpack_from('<HH', apk, h + 26)
d = h + 30 + nl + el
crc = zlib.crc32(new) & 0xffffffff
apk[d:d + len(new)] = new
struct.pack_into('<I', apk, h + 14, crc)
# central directory entry
eocd = apk.rfind(b'PK\x05\x06'); cd_size, cd_off = struct.unpack_from('<II', apk, eocd + 12)
p, hit = cd_off, 0
while p < cd_off + cd_size:
    n, e, c = struct.unpack_from('<HHH', apk, p + 28)
    if apk[p + 46:p + 46 + n].decode() == name and struct.unpack_from('<I', apk, p + 42)[0] == h:
        struct.pack_into('<I', apk, p + 16, crc); hit += 1
    p += 46 + n + e + c
assert hit == 1
open(dst, 'wb').write(apk)
print('patched', name, 'crc', hex(crc))
