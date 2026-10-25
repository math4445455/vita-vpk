#!/usr/bin/env python3
from pathlib import Path
import struct
BASE=Path(__file__).parent
assets=BASE/'APP_VITA/assets'
def dims(name):
 b=(assets/name).read_bytes()
 assert b[:8]==b'\x89PNG\r\n\x1a\n', name
 return struct.unpack('>II',b[16:24])
assert dims('lia.png')==(576,48),'sprite sheet requires 12x48px frames'
assert dims('objects.png')==(512,64)
assert dims('title.png')==(480,272)
for i in range(1,55): assert dims(f'rooms/{i:02d}.png')==(480,224)
compat=(BASE/'APP_VITA/vita_compat.lua').read_text()
assert 'drawImageExtended(x*2,y*2' in compat
assert 'drawScaleImage(x*2,y*2' in compat
assert 'fillRect(x*2,(x+w)*2,y*2,(y+h)*2' in compat
assert 'nativeGraphics.initRescaler(' not in compat
print('OK - GPU draw coordinates 2x -> 960x544; 48px/12-frame fox and 54 rooms present.')
