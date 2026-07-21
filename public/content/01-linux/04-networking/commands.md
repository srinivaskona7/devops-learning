# Networking — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Throwaway shell with ip, ping, dig, curl, traceroute
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y iproute2 iputils-ping dnsutils \
  curl wget net-tools traceroute >/dev/null
```

## Core commands

```bash
# Show all interfaces + addresses (modern replacement for ifconfig)
ip addr show
```

```bash
# Brief, colorized one-line-per-iface view
ip -br -c addr
```

```bash
# Bring an interface up
ip link set eth0 up
```

```bash
# Add an IP to an interface
ip addr add 10.0.0.5/24 dev eth0
```

```bash
# Show kernel routing table
ip route
```

```bash
# Which route would be used to reach a host
ip route get 1.1.1.1
```

```bash
# Add a static route via a gateway
ip route add 10.10.0.0/16 via 10.0.0.1
```

```bash
# Listening + established sockets (-t TCP -u UDP -l listen -p proc -n numeric)
ss -tulpn
```

```bash
# All established TCP connections
ss -tan state established
```

```bash
# Socket summary counts
ss -s
```

```bash
# ICMP reachability test, 4 packets
ping -c 4 1.1.1.1
```

```bash
# Hop-by-hop path, no DNS reverse
traceroute -n example.com
```

```bash
# Interactive ping + trace combined
mtr example.com
```

```bash
# Default-resolver DNS query
dig example.com
```

```bash
# Just the answer record
dig +short A example.com
```

```bash
# Query a specific resolver, MX records
dig @8.8.8.8 example.com MX
```

```bash
# Follow DNS from the root servers
dig +trace example.com
```

```bash
# Resolve respecting nsswitch (files + DNS)
getent hosts example.com
```

```bash
# Print HTTP status only, follow redirects, fail on 4xx/5xx
curl -fsSL https://example.com -o /dev/null -w '%{http_code}\n'
```

```bash
# HEAD request — headers only
curl -I https://example.com
```

```bash
# Verbose request — see TLS handshake + headers
curl -v https://example.com
```

```bash
# Read-only firewall inspection (filter table, numeric, counters)
iptables -L -n -v
```

```bash
# NAT table — Docker chains live here
iptables -t nat -L -n
```

```bash
# Tiny packet capture: 5 packets on port 80
tcpdump -i eth0 -nn 'port 80' -c 5
```

## Inspection / verification

```bash
# Confirm a process is listening on a port
ss -tulpn | grep 8080
```

```bash
# Quick port-reachability check (no HTTP)
nc -zv host 443
```

```bash
# Time + status for an HTTP request
curl -s -o /dev/null -w 'code=%{http_code} time=%{time_total}s\n' http://localhost:8080/
```

```bash
# See iptables rule numbers for surgical edits
iptables -L -n -v --line-numbers
```

## Cleanup

```bash
# Remove an IP from an interface
ip addr del 10.0.0.5/24 dev eth0
```

```bash
# Remove a static route
ip route del 10.10.0.0/16
```

## One-liners worth memorising

```bash
# Quick HTTP latency probe with no body
curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' https://example.com
```

```bash
# Count established connections to a port
ss -tan state established '( dport = :443 or sport = :443 )' | wc -l
```

```bash
# Spin a one-shot HTTP server for testing
python3 -m http.server 8080 &
```

```bash
# Show open ports with owning processes
ss -tulpn | column -t
```

```bash
# Trace which process initiates a connection
strace -e trace=network -f curl example.com 2>&1 | grep connect
```
