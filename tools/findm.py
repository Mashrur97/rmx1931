import sys,re
from androguard.core.dex import DEX
from loguru import logger; logger.remove()
pat=re.compile(sys.argv[2])
d=DEX(open(sys.argv[1],'rb').read())
for m in d.get_encoded_methods():
    try: out=[i.get_output() for i in m.get_instructions()]
    except Exception: continue
    hits=[o for o in out if pat.search(o)]
    if hits: print('##',sys.argv[1],m.get_class_name(),m.get_name(),m.get_descriptor(),len(out),hits[:4])
