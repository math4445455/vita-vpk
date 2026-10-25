#!/usr/bin/env python3
"""Validador estrutural do VPK; nao emula nem executa o jogo em um Vita."""
import struct
import sys
from pathlib import Path
from zipfile import ZipFile

def main(path: Path):
    assert path.is_file(), f"Arquivo ausente: {path}"
    required = {
        'eboot.bin', 'sce_sys/param.sfo', 'sce_sys/icon0.png',
        'sce_sys/livearea/contents/template.xml',
        'index.lua', 'game.lua', 'logic.lua', 'vita_compat.lua',
        'data/content.lua', 'assets/title.png',
    }
    required.update(f'assets/rooms/{i:02d}.png' for i in range(1,55))
    required.update(f'audio/distrito{i}.ogg' for i in range(1,7))
    with ZipFile(path) as vpk:
        broken = vpk.testzip()
        assert not broken, f"Problema ZIP em {broken}"
        names = set(vpk.namelist())
        missing = sorted(required - names)
        assert not missing, f"Faltando: {missing}"
        elf = vpk.read('eboot.bin')
        assert elf[:4] == b'SCE\x00' and len(elf) > 100_000, 'EBOOT nao parece Vita SELF'
        sfo = vpk.read('sce_sys/param.sfo')
        assert sfo[:4] == b'\x00PSF', 'param.sfo invalido'
        for i in range(1,55):
            b=vpk.read(f'assets/rooms/{i:02d}.png')
            assert b.startswith(b'\x89PNG\r\n\x1a\n'), f'Imagem {i} nao e PNG'
        from build_vpk import read_sfo, TITLE_ID
        fields = {key: (fmt, value) for key, fmt, value, _ in read_sfo(sfo)}
        needed = {'TITLE_ID','CONTENT_ID','CATEGORY','APP_VER','ATTRIBUTE',
                  'ATTRIBUTE2','ATTRIBUTE_MINOR','PSP2_SYSTEM_VER','SAVEDATA_MAX_SIZE'}
        assert needed <= fields.keys(), f'SFO com campos ausentes: {needed-fields.keys()}'
        assert fields['TITLE_ID'][1] == TITLE_ID.encode('ascii')+b'\x00', 'TITLE_ID incorreto'
        assert fields['CONTENT_ID'][1] == ('HB0001-'+TITLE_ID+'_00-0000000000000000').encode('ascii')+b'\x00', 'CONTENT_ID incorreto'
        assert fields['CATEGORY'][1] == b'gd\x00', 'Categoria SFO incorreta'
        assert fields['ATTRIBUTE'][1] == struct.pack('<I',0x8000), 'Atributos SFO incorretos'
        assert fields['ATTRIBUTE2'][1] == struct.pack('<I',0x0C), 'Memoria SFO incorreta'
        vita_images = {
            'sce_sys/icon0.png': (128, 128, 128 * 1024),
            'sce_sys/livearea/contents/startup.png': (280, 158, 64 * 1024),
            'sce_sys/livearea/contents/bg0.png': (840, 500, 128 * 1024),
            'sce_sys/pic0.png': (960, 544, 256 * 1024),
        }
        for name, (width, height, cap) in vita_images.items():
            data = vpk.read(name)
            assert data[:8] == b'\x89PNG\r\n\x1a\n' and data[12:16] == b'IHDR', f'Imagem LiveArea invalida: {name}'
            w, h, depth, ctype, _, _, interlace = struct.unpack_from('>IIBBBBB', data, 16)
            assert (w, h) == (width, height), f'{name}: dimensoes {(w,h)} incorretas'
            assert (depth, ctype, interlace) == (8, 3, 0), f'{name}: deve ser PNG indexado 8 bits sem interlace'
            assert len(data) <= cap, f'{name}: arquivo grande demais ({len(data)} > {cap})'
    print('OK - VPK estruturalmente completo.')
    print('Aviso: nao substitui um teste em PS Vita ou Vita3K.')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Uso: python3 validar_vpk.py arquivo.vpk')
    main(Path(sys.argv[1]))
