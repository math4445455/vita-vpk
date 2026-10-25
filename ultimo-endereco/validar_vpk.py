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
        assert b'ULTMEND01' in sfo, 'O TITLE_ID nao foi alterado'
    print('OK - VPK estruturalmente completo.')
    print('Aviso: nao substitui um teste em PS Vita ou Vita3K.')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Uso: python3 validar_vpk.py arquivo.vpk')
    main(Path(sys.argv[1]))
