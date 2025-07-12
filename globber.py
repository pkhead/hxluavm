#!/usr/bin/env python3
import glob
import sys
import os

SRC = sys.argv[1]

for f in (glob.glob(SRC + '/*.c')):
    bn = os.path.basename(f)
    if bn == 'lua.c' or bn == 'luac.c': continue
    
    sys.stdout.write(os.path.abspath(f))
    sys.stdout.write('\n')