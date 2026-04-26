# 🌐 04 — Networking

> "Is it DNS?" usually. Linux networking is layered — interfaces, routes, sockets, DNS, firewall — and each layer has its own tool.

## Why this matters

Microservices, containers, and clouds are 90% networking. Reading `ip`, `ss`, and `dig` output fluently turns 4-hour outages into 15-minute fixes.

## 🧭 The path of a packet

```mermaid
flowchart LR
    APP[App] --> SOCK[Socket]
    SOCK --> TCP[TCP/UDP]
    TCP --> IP[IP layer<br/>routing table]
    IP --> NF[netfilter<br/>iptables/nftables]
    NF --> NIC[Interface eth0]
    NIC --> WIRE[((Network))]
    WIRE --> NIC2[Remote NIC]
    NIC2 --> DNS[(DNS resolver<br/>/etc/resolv.conf)]
```

## Concepts

- **Interface** — `lo` (loopback), `eth0` / `enp0s3`, `wlan0`, `docker0`.
- **IP address** — IPv4 (`/24` netmask) or IPv6.
- **Routing table** — kernel decides next-hop based on destination.
- **Port** — 0–65535. Privileged < 1024 (root only to bind, traditionally).
- **Socket states** — LISTEN, ESTABLISHED, TIME_WAIT, CLOSE_WAIT.
- **DNS** — `/etc/resolv.conf` lists resolvers; `/etc/nsswitch.conf` orders sources.
- **Firewall** — `iptables` (legacy), `nftables` (modern), `ufw` / `firewalld` (frontends).

## Commands

```bash
# Interfaces & addresses (modern, replaces ifconfig)
ip addr show                       # short: ip a
ip -br -c addr                     # brief, colorized
ip link set eth0 up                # bring interface up
ip addr add 10.0.0.5/24 dev eth0   # add IP

# Routing
ip route                           # → default via 172.17.0.1 dev eth0
ip route get 1.1.1.1               # show which route would be used
ip route add 10.10.0.0/16 via 10.0.0.1

# Sockets / ports (replaces netstat)
ss -tulpn                          # -t TCP, -u UDP, -l listening, -p process, -n numeric
ss -tan state established          # all established TCP
ss -s                              # summary counts
netstat -rn                        # routing table (legacy)

# Reachability
ping -c 4 1.1.1.1                  # -c count
ping6 -c 2 ::1
traceroute -n example.com          # -n no DNS reverse
mtr example.com                    # interactive ping+trace

# DNS
dig example.com                    # query default resolver
dig +short A example.com
dig @8.8.8.8 example.com MX        # specific resolver
dig +trace example.com             # follow from root
host example.com
nslookup example.com
getent hosts example.com           # respects nsswitch (files + DNS)

# HTTP
curl -fsSL https://example.com -o /dev/null -w '%{http_code}\n'
curl -I https://example.com        # HEAD only — headers
curl -v https://example.com        # verbose, see TLS handshake
wget -q -O - https://example.com | head

# Firewall (iptables — read-only inspection)
iptables -L -n -v                  # filter table
iptables -t nat -L -n              # NAT table (DOCKER chains live here)

# Packet capture (tiny dose; full coverage in topic 10)
tcpdump -i eth0 -nn 'port 80' -c 5
```

## 🧪 Lab — Inspect interfaces, ports, DNS, HTTP

```bash
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y iproute2 iputils-ping dnsutils \
  curl wget net-tools traceroute >/dev/null
```

**Step 1.** List interfaces and their IPs.

```bash
ip -br -c addr
# → lo               UNKNOWN        127.0.0.1/8 ::1/128
# → eth0@if38        UP             172.17.0.2/16 fe80::42:acff:fe11:2/64
```

**Step 2.** View the default route and test it.

```bash
ip route
# → default via 172.17.0.1 dev eth0
# → 172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2

ip route get 1.1.1.1
# → 1.1.1.1 via 172.17.0.1 dev eth0 src 172.17.0.2 uid 0
```

**Step 3.** Resolve a name three ways and compare.

```bash
getent hosts example.com
# → 93.184.216.34   example.com

dig +short example.com
# → 93.184.216.34

dig +trace example.com | tail -5
```

**Step 4.** Open a listener and see it in `ss`.

```bash
( python3 -m http.server 8080 >/dev/null 2>&1 & )
sleep 1
ss -tulpn | grep 8080
# → tcp LISTEN 0  5  0.0.0.0:8080  0.0.0.0:*  users:(("python3",pid=42,fd=3))
```

**Step 5.** Make an HTTP request and inspect.

```bash
curl -sI http://localhost:8080/
# → HTTP/1.0 200 OK
# → Server: SimpleHTTP/0.6 Python/3.10.6
# → Content-type: text/html; charset=utf-8

curl -s -o /dev/null -w 'code=%{http_code} time=%{time_total}s\n' http://localhost:8080/
# → code=200 time=0.002s
```

**Step 6.** Trace the path to a public host.

```bash
traceroute -n -m 8 1.1.1.1
# →  1  172.17.0.1   0.05 ms
# →  2  192.168.1.1  1.2 ms
# →  …
```

**Step 7.** Quick `tcpdump` of localhost traffic.

```bash
( curl -s http://localhost:8080/ >/dev/null & )
tcpdump -i lo -nn -c 4 'port 8080'
# → IP 127.0.0.1.54312 > 127.0.0.1.8080: Flags [S] …
# → IP 127.0.0.1.8080 > 127.0.0.1.54312: Flags [S.] …
```

## ⚠️ Gotchas

> ⚠️ `ifconfig` and `netstat` are **deprecated**. They lie about modern features (multiple IPs per iface, namespaces). Use `ip` and `ss`.
>
> ⚠️ `/etc/hosts` always wins over DNS unless `/etc/nsswitch.conf` says otherwise. First-line check when names resolve "wrong."
>
> ⚠️ `ping` uses ICMP — many cloud security groups block it. Reachability ≠ port reachability. Use `nc -zv host port` or `curl -v`.
>
> ⚠️ `TIME_WAIT` sockets are **normal** after close (60s default). They don't indicate a leak.
>
> ⚠️ Inside a Docker container you see the **container's** netns, not the host's. `ip addr` on host shows `docker0` and `vethX` pairs.
>
> ⚠️ Firewall rules are evaluated in order with first-match-wins. Always read full chain output (`iptables -L -n -v --line-numbers`).
>
> ⚠️ `curl -k` (insecure) silently disables TLS verification. Never in scripts that handle credentials.

## 📖 Further reading

- `man 8 ip` · `man 8 ss` · `man 1 dig` · `man 1 curl` · `man 8 tcpdump`
- [iproute2 docs](https://wiki.linuxfoundation.org/networking/iproute2)
- [ArchWiki — Network configuration](https://wiki.archlinux.org/title/Network_configuration)
- [nftables wiki](https://wiki.nftables.org/)
- [Beej's Guide to Network Programming](https://beej.us/guide/bgnet/) — sockets from the C side
