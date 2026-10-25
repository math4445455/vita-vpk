#!/usr/bin/env python3
"""Verifica bit depth, pixel type e tamanho dos PNG da LiveArea antes do build."""
from pathlib import Path
from struct import unpack_from
ROOT = Path(__file__).resolve().parent / 'SCE_SYS_VITA'
REGRAS = {
    'icon0.png': (128, 128, 128 * 1024),
    'livearea/contents/startup.png': (280, 158, 64 * 1024),
    'livearea/contents/bg0.png': (840, 500, 128 * 1024),
    'pic0.png': (960, 544, 256 * 1024),
}
for nome, (largura, altura, limite) in REGRAS.items():
    p = ROOT / nome
    dados = p.read_bytes()
    assert dados[:8] == b'\x89PNG\r\n\x1a\n' and dados[12:16] == b'IHDR', f'{nome}: PNG invalido'
    w, h, bit, cor, _, _, entrelaco = unpack_from('>IIBBBBB', dados, 16)
    assert (w, h) == (largura, altura), f'{nome}: dimensoes invalidas'
    assert (bit, cor, entrelaco) == (8, 3, 0), f'{nome}: exigir PNG 8-bit indexado (paleta), sem interlace'
    assert len(dados) <= limite, f'{nome}: maior que o limite ({len(dados)} > {limite})'
    print(f'OK: {nome}: {w}x{h}, 8-bit paleta, {len(dados)} bytes')
