# Minimal dex reader: defined classes, and external class/method/field references.
import struct,glob,sys,collections
def uleb(b,o):
    r=s=0
    while True:
        x=b[o];o+=1;r|=(x&0x7f)<<s;s+=7
        if x<0x80:return r,o
def load(p):
    b=open(p,'rb').read();u=lambda o:struct.unpack_from('<I',b,o)[0]
    sn,so,tn,to,pn,po,fn,fo,mn,mo,cn,co=[u(x) for x in (0x38,0x3c,0x40,0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64)]
    def S(i):
        o=u(so+4*i);_,o=uleb(b,o);e=b.index(0,o);return b[o:e].decode('utf-8','replace')
    T=[S(u(to+4*i)) for i in range(tn)]
    P=[]
    for i in range(pn):
        o=po+12*i;ret=T[u(o+4)];po2=u(o+8);args=[]
        if po2:
            n=u(po2);args=[T[struct.unpack_from('<H',b,po2+4+2*k)[0]] for k in range(n)]
        P.append('('+''.join(args)+')'+ret)
    F=[]
    for i in range(fn):
        c,t,n=struct.unpack_from('<HHI',b,fo+8*i);F.append((T[c],S(n),T[t]))
    M=[]
    for i in range(mn):
        c,p,n=struct.unpack_from('<HHI',b,mo+8*i);M.append((T[c],S(n),P[p]))
    D=[T[u(co+32*i)] for i in range(cn)]
    return T,F,M,D
defined=set();T=set();F=set();M=set()
for p in sorted(glob.glob(sys.argv[1] if len(sys.argv)>1 else 'classes*.dex')):
    t,f,m,d=load(p);defined|=set(d);T|=set(t);F|=set(f);M|=set(m)
ext=lambda c:c.startswith('L') and c not in defined
import json
json.dump({'types':sorted(x for x in T if ext(x)),'methods':sorted(x for x in M if ext(x[0])),'fields':sorted(x for x in F if ext(x[0])),'ndef':len(defined)},open('/home/claude/gal/refs.json','w'))
