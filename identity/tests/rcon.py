#!/usr/bin/env python3
"""Send a command to the disposable identity test server."""
import argparse,socket,struct
p=argparse.ArgumentParser();p.add_argument('command');p.add_argument('--port',type=int,default=27530);a=p.parse_args()
def packet(i,t,b):
 d=struct.pack('<ii',i,t)+b.encode()+b'\0\0';return struct.pack('<i',len(d))+d
def exact(s,n):
 b=b''
 while len(b)<n:
  v=s.recv(n-len(b))
  if not v: raise EOFError('RCON closed')
  b+=v
 return b
def receive(s):
 n=struct.unpack('<i',exact(s,4))[0];d=exact(s,n);return struct.unpack('<ii',d[:8])+(d[8:-2].decode(),)
with socket.create_connection(('127.0.0.1',a.port),timeout=20) as s:
 s.sendall(packet(1,3,'local-identity-test'))
 while True:
  i,t,b=receive(s)
  if t==2:
   if i==-1: raise SystemExit('Authentication failed')
   break
 s.sendall(packet(2,2,a.command))
 while True:
  i,t,b=receive(s)
  if i==2: print(b);break
