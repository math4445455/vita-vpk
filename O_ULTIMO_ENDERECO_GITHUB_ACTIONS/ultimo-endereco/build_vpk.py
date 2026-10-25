#!/usr/bin/env python3
"""Build the *native* PlayStation Vita VPK from this port and an official
Lua Player Plus Vita runtime VPK. Does NOT use any PSP EBOOT/PBP.

Usage: python build_vpk.py ~/Downloads/eboot_safe.bin
"""
from __future__ import annotations
import argparse
import io
from pathlib import Path
import struct
import sys
import zipfile

HERE = Path(__file__).resolve().parent
TITLE_ID = 'ULTMEND01'
TITLE = 'O ULTIMO ENDERECO'
OUT = HERE / 'O_ULTIMO_ENDERECO_VITA.vpk'


def align4(n):
    return (n + 3) & ~3


def read_sfo(raw: bytes):
    if len(raw) < 20 or raw[:4] != b'\x00PSF':
        raise ValueError('param.sfo invalido no runtime de origem')
    _, version, key_pos, data_pos, count = struct.unpack_from('<4sIIII', raw)
    if version not in (0x101, 0x100) or count > 256:
        raise ValueError('Versao/quantidade de campos do param.sfo invalida')
    entries = []
    for i in range(count):
        off=20+16*i
        if off+16>len(raw): raise ValueError('Indice SFO truncado')
        key_rel, fmt, length, max_length, data_rel = struct.unpack_from('<HHIII',raw,off)
        ks=key_pos+key_rel
        ke=raw.find(b'\x00',ks)
        if ke<0 or ke>ks+200: raise ValueError('Chave SFO invalida')
        key=raw[ks:ke].decode('ascii')
        if max_length > 1_000_000 or data_pos+data_rel+length > len(raw):
            raise ValueError('Valor SFO fora dos limites')
        data=raw[data_pos+data_rel:data_pos+data_rel+length]
        entries.append([key,fmt,data,max_length])
    return entries


def write_sfo(entries):
    keys=bytearray();data=bytearray();indices=[]
    for k,fmt,value,max_length in entries:
        key_off=len(keys);keys+=k.encode('ascii')+b'\x00'
        while len(data)%4: data+=b'\x00'
        data_off=len(data);data+=value
        mx=max(max_length,len(value))
        indices.append(struct.pack('<HHIII',key_off,fmt,len(value),mx,data_off))
        # Padding up to original max: required by SFO schema for serialized fields.
        data+=b'\x00'*(align4(mx)-len(value))
    data_pos=align4(20+16*len(entries)+len(keys))
    header=struct.pack('<4sIIII',b'\x00PSF',0x101,20+16*len(entries),data_pos,len(entries))
    blob=bytearray(header+b''.join(indices)+keys)
    blob+=b'\x00'*(data_pos-len(blob))
    blob+=data
    return bytes(blob)


def updated_sfo(data: bytes):
    entries=read_sfo(data)
    replace={'TITLE':TITLE,'STITLE':TITLE,'TITLE_ID':TITLE_ID,
             'APP_VER':'01.00','VERSION':'01.00'}
    found=set()
    for ent in entries:
        key,fmt,value,max_length=ent
        if key in replace:
            ent[2]=replace[key].encode('utf8')+b'\x00'
            found.add(key)
        elif key=='CONTENT_ID':
            # Remove stale identity from the interpreter's package; Vita checks it.
            prev=value.decode('ascii','replace').rstrip('\x00')
            if len(prev)>=16 and '-' in prev:
                head,_,tail=prev.partition('-')
                # Preserve original publisher prefix but change game's title ID.
                tail=(TITLE_ID+tail[9:]) if len(tail)>=9 else TITLE_ID
                ent[2]=(head+'-'+tail).encode('ascii')+b'\x00'
    for required in ('TITLE','TITLE_ID'):
        if required not in found:
            entries.append([required,0x0204,replace[required].encode('utf8')+b'\x00',128 if required=='TITLE' else 12])
    blob=write_sfo(entries)
    check=read_sfo(blob)
    got={e[0]:e[2].rstrip(b'\x00').decode('utf8','replace') for e in check}
    if got['TITLE_ID']!=TITLE_ID:
        raise ValueError('Falha ao alterar Title ID')
    return blob


def minimal_sfo():
    """VitaSDK-style essentials, used only with an official safe SELF binary."""
    strings={
        'APP_VER': ('01.00',8), 'CATEGORY': ('gd',4),
        'PSP2_DISP_VER': ('03.600',8), 'STITLE': (TITLE,52),
        'TITLE': (TITLE,128), 'TITLE_ID': (TITLE_ID,12),
        'VERSION': ('01.00',8)
    }
    ints={'ATTRIBUTE':0,'PARENTAL_LEVEL':1}
    entries=[]
    for key in sorted(set(strings)|set(ints)):
        if key in strings:
            value,maxlen=strings[key]
            entries.append([key,0x0204,value.encode('utf8')+b'\x00',maxlen])
        else:
            entries.append([key,0x0404,struct.pack('<I',ints[key]),4])
    return write_sfo(entries)


def build(runtime_vpk: Path, dest: Path):
    if not runtime_vpk.is_file():
        raise FileNotFoundError(f'Runtime LPP-Vita nao encontrado: {runtime_vpk}')
    elf=None
    param=None
    modules={}
    if runtime_vpk.suffix.lower()=='.vpk':
        with zipfile.ZipFile(runtime_vpk,'r') as ref:
            entries={n.lower():n for n in ref.namelist()}
            if 'eboot.bin' not in entries or 'sce_sys/param.sfo' not in entries:
                raise ValueError('Este VPK nao contem eboot.bin e sce_sys/param.sfo')
            elf=ref.read(entries['eboot.bin'])
            param=updated_sfo(ref.read(entries['sce_sys/param.sfo']))
            for name in ref.namelist():
                low=name.lower()
                if (low.startswith('sce_module/') or (name.count('/')==0 and low.endswith('.suprx'))) and not name.endswith('/'):
                    modules[name]=ref.read(name)
    elif runtime_vpk.suffix.lower()=='.bin':
        if runtime_vpk.name.lower() not in ('eboot_safe.bin','eboot.bin','eboot_unsafe.bin'):
            raise ValueError('Use eboot_safe.bin da release oficial do LPP-Vita.')
        elf=runtime_vpk.read_bytes()
        param=minimal_sfo()
    else:
        raise ValueError('Informe o VPK oficial do LPP-Vita ou seu eboot_safe.bin nativo.')
    if len(elf)<1024 or elf[:4]!=b'SCE\x00':
        raise ValueError('Este arquivo nao parece um executavel nativo do Vita (SELF).')
    # Trust model: the caller must provide the *actual* official LPP-Vita binary.
    dest.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as target:
        target.writestr('eboot.bin',elf,compress_type=zipfile.ZIP_STORED)
        target.writestr('sce_sys/param.sfo',param)
        for name,content in modules.items(): target.writestr(name,content)
        for src,arcroot in [(HERE/'APP_VITA',''),(HERE/'SCE_SYS_VITA','sce_sys/')]:
            for p in sorted(src.rglob('*')):
                if p.is_file():
                    arc=arcroot+p.relative_to(src).as_posix()
                    target.write(p,arc)
    with zipfile.ZipFile(dest) as z:
        bad=z.testzip()
        if bad: raise ValueError('VPK com erro de compactacao em '+bad)
        names=set(z.namelist())
        needed={'eboot.bin','sce_sys/param.sfo','sce_sys/icon0.png',
                'index.lua','game.lua','logic.lua','vita_compat.lua',
                'assets/title.png','assets/rooms/54.png','audio/distrito6.ogg',
                'data/content.lua'}
        missing=needed-names
        if missing: raise ValueError('VPK incompleto: '+repr(sorted(missing)))
    return dest


if __name__=='__main__':
    ap=argparse.ArgumentParser(description='Criar VPK nativo do jogo usando o runtime oficial Lua Player Plus Vita')
    ap.add_argument('lpp_vpk',type=Path,help='Arquivo eboot_safe.bin ou VPK ORIGINAL do Lua Player Plus Vita (Rinnegatamante)')
    ap.add_argument('-o','--output',type=Path,default=OUT,help='Nome do VPK gerado')
    a=ap.parse_args()
    try:
        built=build(a.lpp_vpk,a.output)
        print('VPK GERADO:',built)
        print('Copie para ux0:data e instale pelo VitaShell.')
    except (FileNotFoundError, ValueError, zipfile.BadZipFile) as exc:
        print('ERRO:',exc,file=sys.stderr)
        sys.exit(1)
