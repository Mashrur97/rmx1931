import sys
from androguard.core.dex import DEX
d=DEX(open(sys.argv[1],'rb').read())
want=[(sys.argv[i],sys.argv[i+1]) for i in range(2,len(sys.argv),2)]
for m in d.get_encoded_methods():
    for c,n in want:
        if m.get_class_name()==c and m.get_name()==n:
            print('####',c,n,m.get_descriptor())
            idx=0
            for ins in m.get_instructions():
                print('  %04x %s %s'%(idx,ins.get_name(),ins.get_output())); idx+=ins.get_length()
