#!/usr/bin/env python3
"""Local RCON: rcon.py 'cmd' or rcon.py - < file.lua (lines joined into one /sc)."""
import socket,struct,sys
def pkt(i,t,b):
    d=struct.pack('<ii',i,t)+b.encode()+b'\0\0'; return struct.pack('<i',len(d))+d
def recv(s):
    n=struct.unpack('<i',s.recv(4,socket.MSG_WAITALL))[0]; d=b''
    while len(d)<n: d+=s.recv(n-len(d))
    return struct.unpack('<ii',d[:8])+(d[8:-2].decode(errors='replace'),)
arg=sys.argv[1]
cmd=arg if arg!='-' else '/sc '+' '.join(l.strip() for l in sys.stdin.read().splitlines() if l.strip() and not l.strip().startswith('--'))
s=socket.create_connection(('127.0.0.1',27420))
s.sendall(pkt(1,3,'mptest'))
while recv(s)[1]!=2: pass
s.sendall(pkt(2,2,cmd))
r=recv(s)
while r[0]!=2: r=recv(s)
print(r[2])
