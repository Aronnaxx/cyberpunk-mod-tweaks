"""Minimal read-only LevelDB reader (SSTables + write-ahead log) for Vortex's state.v2.
Usage: python leveldb_dump.py <state.v2 dir> <key substring> [out.json]
Prints/writes the newest value of every key containing the substring.
"""
import json, os, struct, sys
import cramjam


def varint(b, i):
    r = s = 0
    while True:
        c = b[i]; i += 1
        r |= (c & 0x7F) << s
        if c < 0x80:
            return r, i
        s += 7


def block_entries(data):
    n = struct.unpack_from('<I', data, len(data) - 4)[0]
    end = len(data) - 4 - 4 * n
    i, key = 0, b''
    while i < end:
        shared, i = varint(data, i)
        nonshared, i = varint(data, i)
        vlen, i = varint(data, i)
        key = key[:shared] + data[i:i + nonshared]; i += nonshared
        yield key, data[i:i + vlen]; i += vlen


def read_block(f, off, size):
    f.seek(off)
    raw = f.read(size + 5)
    data, ctype = raw[:size], raw[size]
    if ctype == 1:
        data = bytes(cramjam.snappy.decompress_raw(data))
    return data


def sstable(path):
    with open(path, 'rb') as f:
        f.seek(-48, 2)
        footer = f.read(48)
        _, i = varint(footer, 0); _, i = varint(footer, i)   # metaindex handle
        ioff, i = varint(footer, i); isize, i = varint(footer, i)
        for _, h in block_entries(read_block(f, ioff, isize)):
            doff, j = varint(h, 0); dsize, j = varint(h, j)
            for ikey, val in block_entries(read_block(f, doff, dsize)):
                tag = struct.unpack('<Q', ikey[-8:])[0]
                yield ikey[:-8], tag >> 8, tag & 0xFF, val


def logfile(path):
    data = open(path, 'rb').read()
    i, rec = 0, b''
    while i + 7 <= len(data):
        blk_left = 32768 - (i % 32768)
        if blk_left < 7:
            i += blk_left; continue
        length, rtype = struct.unpack_from('<HB', data, i + 4)
        payload = data[i + 7:i + 7 + length]; i += 7 + length
        if rtype in (1, 2):
            rec = payload
        else:
            rec += payload
        if rtype in (1, 4) and len(rec) >= 12:
            seq, count = struct.unpack_from('<QI', rec, 0)
            j = 12
            for k in range(count):
                t = rec[j]; j += 1
                kl, j = varint(rec, j); key = rec[j:j + kl]; j += kl
                val = b''
                if t == 1:
                    vl, j = varint(rec, j); val = rec[j:j + vl]; j += vl
                yield key, seq + k, t, val
            rec = b''
        elif rtype == 0:
            break


def load(dirpath, needle):
    best = {}
    for fn in os.listdir(dirpath):
        p = os.path.join(dirpath, fn)
        src = sstable(p) if fn.endswith('.ldb') else logfile(p) if fn.endswith('.log') else ()
        for key, seq, t, val in src:
            if needle not in key:
                continue
            if key not in best or seq > best[key][0]:
                best[key] = (seq, t, val)
    return {k.decode('utf-8', 'replace'): v[2].decode('utf-8', 'replace') for k, v in best.items() if v[1] == 1}


if __name__ == '__main__':
    out = load(sys.argv[1], sys.argv[2].encode())
    if len(sys.argv) > 3:
        json.dump(out, open(sys.argv[3], 'w', encoding='utf-8'), indent=0)
    print(len(out), 'keys')
    for k in list(out)[:15]:
        print(k, '=', out[k][:120])
