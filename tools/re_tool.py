import sys, capstone
from elftools.elf.elffile import ELFFile
f=open(sys.argv[1],'rb'); e=ELFFile(f); data=open(sys.argv[1],'rb').read()
# symbol lookup
syms={}
for s in ('.dynsym','.symtab'):
    sec=e.get_section_by_name(s)
    if sec:
        for x in sec.iter_symbols():
            if x['st_value']: syms[x['st_value']]=x.name
def nearest(a):
    c=[k for k in syms if k<=a]; 
    if not c: return None
    k=max(c); return syms[k],a-k
# plt map
pltmap={}
rela=e.get_section_by_name('.rela.plt'); dsym=e.get_section_by_name('.dynsym'); plt=e.get_section_by_name('.plt')
if rela and plt:
    for i,r in enumerate(rela.iter_relocations()):
        pltmap[plt['sh_addr']+0x20+i*16]=dsym.get_symbol(r['r_info_sym']).name
def vaddr2off(v):
    for seg in e.iter_segments():
        if seg['p_type']=='PT_LOAD' and seg['p_vaddr']<=v<seg['p_vaddr']+seg['p_filesz']:
            return v-seg['p_vaddr']+seg['p_offset']
def readstr(v):
    o=vaddr2off(v)
    if o is None: return None
    end=data.find(b'\0',o); s=data[o:end]
    return s.decode('latin1') if 0<len(s)<200 and all(32<=c<127 for c in s) else None
cs=capstone.Cs(capstone.CS_ARCH_ARM64,capstone.CS_MODE_ARM); cs.detail=False
def dis(start,n):
    o=vaddr2off(start)
    adrp={}
    for i in cs.disasm(data[o:o+n*4],start):
        note=''
        ops=i.op_str
        if i.mnemonic=='adrp':
            r=ops.split(',')[0]; adrp[r]=int(ops.split('#')[1],16)
        elif i.mnemonic=='add' and '#' in ops:
            p=[x.strip() for x in ops.split(',')]
            if p[1] in adrp:
                v=adrp[p[1]]+int(p[2].lstrip('#'),16); s=readstr(v); note=f' ; {hex(v)} {repr(s) if s else ""}'
        elif i.mnemonic in ('bl','b') and '#' in ops:
            t=int(ops.lstrip('#'),16); n2=pltmap.get(t) or (nearest(t) and nearest(t)[1]==0 and nearest(t)[0]); note=f' ; {n2}' if n2 else ''
        print(f'{i.address:#x}: {i.mnemonic:6} {ops}{note}')
if __name__=='__main__':
    a=int(sys.argv[2],16); print('in func:',nearest(a)); dis(a,int(sys.argv[3]))
