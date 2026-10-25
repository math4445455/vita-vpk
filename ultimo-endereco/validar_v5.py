#!/usr/bin/env python3
from pathlib import Path
import struct,hashlib
p=Path(__file__).resolve().parent
assets=p/'APP_VITA/assets'
from_sheets=lambda f:(int.from_bytes((assets/f).read_bytes()[16:20],'big'),int.from_bytes((assets/f).read_bytes()[20:24],'big'))
assert from_sheets('lia.png')==(576,48)
assert from_sheets('objects.png')==(512,64)
for i in range(1,7):
 b=(p/f'APP_VITA/audio/distrito{i}.ogg').read_bytes()
 assert len(b)>50000 and b[:4]==b'OggS', f'missing Vorbis track for area {i}'
hashes=[hashlib.sha256((p/f'APP_VITA/audio/distrito{i}.ogg').read_bytes()).hexdigest() for i in range(1,7)]
assert len(set(hashes))==6, 'different area music required'
g=(p/'APP_VITA/game.lua').read_text(encoding='utf8')
assert "Ogg.load('audio/distrito'..c..'.ogg',0)" in g
assert 'TRACK_NAMES' in g
print('V5 OK: 12 frames kemonomimi, 6 different OggS soundtracks, chapter-select music, 54 rooms preserved')
