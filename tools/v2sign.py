# Minimal APK Signature Scheme v2 signer (RSA PKCS#1 v1.5 + SHA-256, algorithm 0x0103).
# Replaces any existing APK Signing Block; zip entries are left byte-for-byte as they are.
# usage: v2sign.py in.apk out.apk key.pk8 cert.x509.pem
import sys, struct, hashlib
from cryptography.hazmat.primitives.serialization import load_der_private_key, Encoding, PublicFormat
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import hashes
from cryptography import x509

src, dst, keyf, certf = sys.argv[1:5]
apk = open(src, 'rb').read()
key = load_der_private_key(open(keyf, 'rb').read(), None)
cert = x509.load_pem_x509_certificate(open(certf, 'rb').read())

eocd = apk.rfind(b'PK\x05\x06')
cd_size, cd_off = struct.unpack_from('<II', apk, eocd + 12)
# strip an existing signing block
start = cd_off
if apk[cd_off - 16:cd_off] == b'APK Sig Block 42':
    blk = struct.unpack_from('<Q', apk, cd_off - 24)[0]
    start = cd_off - blk - 8
sec1, sec3, sec4 = apk[:start], apk[cd_off:cd_off + cd_size], bytearray(apk[eocd:])

def lp(b): return struct.pack('<I', len(b)) + b

def digest(sections):
    chunks = []
    for s in sections:
        for i in range(0, len(s), 1 << 20):
            c = s[i:i + (1 << 20)]
            chunks.append(hashlib.sha256(b'\xa5' + struct.pack('<I', len(c)) + c).digest())
    return hashlib.sha256(b'\x5a' + struct.pack('<I', len(chunks)) + b''.join(chunks)).digest()

e4 = bytearray(sec4); struct.pack_into('<I', e4, 16, len(sec1))   # CD offset as if no block
dg = digest([sec1, sec3, bytes(e4)])
ALG = 0x0103
signed = lp(lp(struct.pack('<I', ALG) + lp(dg))) + lp(lp(cert.public_bytes(Encoding.DER))) + lp(b'')
sig = key.sign(signed, padding.PKCS1v15(), hashes.SHA256())
pub = cert.public_key().public_bytes(Encoding.DER, PublicFormat.SubjectPublicKeyInfo)
signer = lp(signed) + lp(lp(struct.pack('<I', ALG) + lp(sig))) + lp(pub)
value = lp(lp(signer))
pair = struct.pack('<Q', len(value) + 4) + struct.pack('<I', 0x7109871a) + value
size = len(pair) + 8 + 16
block = struct.pack('<Q', size) + pair + struct.pack('<Q', size) + b'APK Sig Block 42'
struct.pack_into('<I', sec4, 16, len(sec1) + len(block))
open(dst, 'wb').write(sec1 + block + sec3 + bytes(sec4))
print('signed', dst, 'digest', dg.hex()[:16])
