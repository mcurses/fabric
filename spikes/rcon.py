#!/usr/bin/env python3
"""Minimal RCON client for the local spike server.

Usage: rcon.py <file.lua | -> [--port N]
Each blank-line-separated chunk of the file is sent as one /sc command (lines joined with spaces, so no trailing
inline `--` comments inside a chunk). A chunk starting with `@mod` runs in the spike mod's Lua state; one starting with `/` is sent as is.
"""
import socket
import struct
import sys


def packet(sock, req_id, kind, body):
    data = struct.pack("<ii", req_id, kind) + body.encode() + b"\x00\x00"
    sock.sendall(struct.pack("<i", len(data)) + data)


def read(sock):
    def exact(n):
        buf = b""
        while len(buf) < n:
            part = sock.recv(n - len(buf))
            if not part:
                raise EOFError
            buf += part
        return buf

    (length,) = struct.unpack("<i", exact(4))
    data = exact(length)
    req_id, kind = struct.unpack("<ii", data[:8])
    return req_id, kind, data[8:-2].decode(errors="replace")


def run(command, port=27410, password="spike"):
    with socket.create_connection(("127.0.0.1", port), timeout=120) as sock:
        packet(sock, 1, 3, password)
        req_id, _, _ = read(sock)
        if req_id == -1:
            raise SystemExit("rcon auth failed")
        packet(sock, 2, 2, command)
        return read(sock)[2]


def main():
    args = sys.argv[1:]
    port = 27410
    if "--port" in args:
        i = args.index("--port")
        port = int(args[i + 1])
        del args[i : i + 2]
    src = sys.stdin.read() if args[0] == "-" else open(args[0]).read()
    for chunk in [c.strip() for c in src.split("\n\n") if c.strip()]:
        lines = [l for l in chunk.splitlines() if not l.strip().startswith("--")]
        prefix = "/sc "
        if lines and lines[0].startswith("/"):
            prefix = ""
        elif lines and lines[0].strip() == "@mod":
            prefix = "/sc __fabric-spike__ "
            lines = lines[1:]
        out = run(prefix + " ".join(l.strip() for l in lines), port)
        if out:
            print(out, end="" if out.endswith("\n") else "\n")


if __name__ == "__main__":
    main()
