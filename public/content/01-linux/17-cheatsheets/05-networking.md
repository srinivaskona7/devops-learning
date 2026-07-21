# Networking — ip / ss / dig / curl / nc / tcpdump

> Half of all "application bugs" are network bugs in disguise. Learn to prove it.

```bash
   ┌──────────────────────────────────────────────────────────────┐
   │  LAYER          TOOL              ASKS THE QUESTION          │
   ├─────────────────┼──────────────────┼────────────────────────┤
   │  L2 link        │  ip link / ethtool│  "is the cable up?"    │
   │  L3 IP/route    │  ip addr / ip route│ "is my IP/route ok?"  │
   │  L4 socket      │  ss / netstat     │ "who's listening?"     │
   │  L7 HTTP/DNS    │  curl / dig       │ "does the protocol fly?"│
   │  packets        │  tcpdump / ngrep │ "what's actually on the wire?"│
   │  raw bytes      │  nc / ncat        │ "can I send anything?" │
   └──────────────────────────────────────────────────────────────┘
```

---

## 1. `ip` — replaces ifconfig/route/arp

```bash
ip addr           # all interfaces with IPs (alias: ip a)
ip -br addr       # brief, one-line per iface
ip -4 addr        # IPv4 only (-6 for IPv6)
ip link           # interfaces, MACs, link state
ip link set eth0 up
ip link set eth0 mtu 9000
ip addr add 10.0.0.5/24 dev eth0
ip addr del 10.0.0.5/24 dev eth0

ip route          # routing table  (alias: ip r)
ip -br route
ip route get 8.8.8.8           # which iface/route would be used for this dest?
ip route add 10.1.0.0/16 via 10.0.0.1
ip route add default via 10.0.0.1 dev eth0
ip route del 10.1.0.0/16

ip neigh          # ARP table (alias: ip n)
ip -s link show eth0           # rx/tx packets, errors, drops, overruns
ip rule           # policy routing
ip netns list                  # network namespaces
```

### `ethtool` — link-layer truth

```bash
ethtool eth0                     # speed/duplex/link
ethtool -S eth0                  # NIC counters: drops, errors, crc
ethtool -g eth0                  # ring buffer sizes
ethtool -k eth0                  # offload features (TSO, GRO, etc.)
ethtool -i eth0                  # driver and firmware
```

## 2. `ss` — sockets (replaces netstat, faster)

```bash
ss -tuln               # TCP+UDP, listening, numeric  (most-used)
ss -tunap              # all states + processes
ss -t state established
ss -t state time-wait | wc -l
ss -tn dport = :443
ss -tn '( dst 10.0.0.5 )'
ss -i                  # TCP info: rtt, cwnd, retrans, lost
ss -s                  # summary counters (TCP/UDP/RAW totals)
ss -tnp '( dport = :5432 )'   # who is connecting to postgres?

# Find what process owns port 8080
ss -tlnp 'sport = :8080'
# ⇒  users:(("server",pid=4321,fd=7))
```

| Flag | Meaning |
|------|---------|
| `-t` / `-u` / `-x` | TCP / UDP / unix |
| `-l` | listening |
| `-n` | numeric (no DNS) |
| `-p` | show owning process |
| `-a` | all states |
| `-i` | per-socket TCP info |
| `-s` | summary |
| `-o` | timers (keepalive, retrans) |

## 3. `dig` — DNS

```bash
dig example.com                      # default A record
dig example.com AAAA                 # IPv6
dig example.com MX
dig example.com TXT
dig example.com ANY +noall +answer   # tidy output
dig +short example.com               # just the IPs
dig +trace example.com               # walk from root, show every step
dig @8.8.8.8 example.com             # query a specific resolver
dig -x 8.8.8.8                       # reverse lookup
dig +tcp example.com                 # force TCP
dig +dnssec example.com              # show DNSSEC records
host example.com                     # dig's friendly cousin
nslookup example.com                 # if dig isn't installed
```

### Read the answer block

```text
;; ANSWER SECTION:
example.com.    300    IN    A    93.184.216.34
                 ^TTL  class type   value
```

`/etc/resolv.conf` shows the resolvers; `/etc/nsswitch.conf` controls hosts/files lookup order.

## 4. `curl` — HTTP debug knife

```bash
curl https://api.example.com/health          # body to stdout
curl -i https://...                          # include response headers
curl -I https://...                          # HEAD only (response headers)
curl -v https://...                          # verbose: TLS handshake, headers
curl -L https://short.url                    # follow redirects
curl -o file.zip https://...                 # save to file
curl -O https://example.com/file.zip         # save with remote name
curl -X POST -H 'Content-Type: application/json' \
     -d '{"k":"v"}' https://api/x
curl -u user:pass https://...                # basic auth
curl -H 'Authorization: Bearer TOKEN' https://...
curl --resolve api.example.com:443:10.0.0.5 https://api.example.com/  # bypass DNS
curl --cacert /etc/ssl/ca.pem https://...    # custom CA
curl -k https://...                          # SKIP cert validation (debug only)
curl --connect-timeout 5 --max-time 10 https://...

# Timing breakdown — find the slow phase
curl -o /dev/null -s -w '
  dns:        %{time_namelookup}s
  connect:    %{time_connect}s
  tlshandshake:%{time_appconnect}s
  starttransfer:%{time_starttransfer}s
  total:      %{time_total}s
  http_code:  %{http_code}\n' https://example.com
```

## 5. `nc` (netcat) — raw TCP/UDP

```bash
nc -zv host 22                    # is port open? (-z scan, -v verbose)
nc -zv host 20-30                 # scan a range
nc -ul 5000                       # UDP listener
nc -l 5000                        # TCP listener
nc -l 5000 > received.bin         # receive a file
nc host 5000 < send.bin           # send a file
echo "GET / HTTP/1.0" | nc example.com 80    # poor-man's curl
nc -w5 host 5000                  # timeout after 5s
```

> On many distros `nc` is GNU `ncat` (better, more features). Use `ncat --ssl` for TLS sockets.

## 6. `tcpdump` — packets don't lie

```bash
tcpdump -i any                                  # all interfaces
tcpdump -i eth0 -n                              # no DNS resolution
tcpdump -i eth0 -nn                             # no DNS, no port-name
tcpdump -i eth0 host 10.0.0.5
tcpdump -i eth0 port 443
tcpdump -i eth0 host 10.0.0.5 and port 443
tcpdump -i eth0 not port 22                     # exclude your ssh session
tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'  # SYN packets
tcpdump -i eth0 -A port 80                      # ASCII payload (HTTP)
tcpdump -i eth0 -X port 80                      # hex+ASCII
tcpdump -i eth0 -w capture.pcap                 # write to file (open in Wireshark)
tcpdump -r capture.pcap                         # read back
tcpdump -i eth0 -c 100                          # stop after 100 packets
tcpdump -i eth0 -s 0 port 443                   # snaplen 0 = full packet
```

### The 5 expressions you'll write the most

```text
host 10.0.0.5
src host 10.0.0.5
dst port 443
tcp port 443 and host 10.0.0.5
icmp
```

## 7. `mtr` — traceroute that updates live

```bash
mtr example.com           # interactive
mtr -rwc 100 example.com  # report mode, 100 pings, wide
```

## 8. Firewall quick checks

```bash
# nftables (modern)
nft list ruleset

# iptables (legacy, still common)
iptables -L -nv --line-numbers
iptables -t nat -L -nv

# ufw (Ubuntu)
ufw status verbose

# firewalld (RHEL)
firewall-cmd --list-all
```

## 9. The "is it the network?" decision tree

```bash
ping host?
  ├─ no → ip route get <ip>; arp; check L1 (ethtool)
  └─ yes
     ├─ ping by NAME no, by IP yes → DNS issue (dig +trace)
     └─ port reachable? (nc -zv host port)
         ├─ no  → firewall (nft/iptables/cloud SG); ss on the server
         └─ yes
             ├─ TLS handshake? (openssl s_client -connect host:port)
             ├─ HTTP responds? (curl -v)
             └─ slow? → curl timing breakdown; tcpdump for retransmits
```

## 10. TLS one-liners

```bash
# Show the cert chain a server presents
openssl s_client -connect example.com:443 -servername example.com </dev/null

# Cert expiry
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
   | openssl x509 -noout -dates -subject -issuer

# Force a specific TLS version
openssl s_client -tls1_2 -connect example.com:443
```

## 11. Sockets in TIME_WAIT (the FAQ)

```bash
ss -tan state time-wait | wc -l        # how many?
sysctl net.ipv4.tcp_max_tw_buckets     # cap
# Don't enable tcp_tw_recycle (removed). tcp_tw_reuse is OK on clients.
```

---

## ★ If you remember nothing else ★

```bash
1.  ss -tlnp        — what's listening, who owns the port.
2.  ip route get X  — exactly which route/iface a packet would take.
3.  dig +short / dig +trace — answer / full chain.
4.  curl -o /dev/null -w '%{time_total} %{http_code}\n'  — time + status.
5.  tcpdump -i any -nn host X and port Y    — packets are the ground truth.
```
