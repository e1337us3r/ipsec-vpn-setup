#!/usr/bin/env bash

## Traffic going to the internet
route add default gw 172.30.30.1

# Round robin reverse proxy
iptables -A PREROUTING -t nat -i enp0s8 -p tcp --dport 8080  \
         -m statistic --mode nth --every 2 --packet 0 \
         -j DNAT --to-destination 10.2.0.2:8080

iptables -A PREROUTING -t nat -i enp0s8 -p tcp --dport 8080 \
         -j DNAT --to-destination 10.2.0.3:8080

# Setup NAT
iptables -A POSTROUTING -t nat -o enp0s8 -j MASQUERADE


## Security
### Allow ipsec packets
iptables -A INPUT -i enp0s8 -p udp --dport 500 -j ACCEPT # IKE
iptables -A INPUT -i enp0s8 -p udp --dport 4500 -j ACCEPT # NAT traversal

## Allow ipsec traffic
iptables -A INPUT -p tcp --dport ssh -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i enp0s8 -p esp -j ACCEPT  # encrypted packets
iptables -A INPUT -m policy --dir in --pol ipsec -p tcp --dport 8080 -j ACCEPT # only accept 8080 traffic if coming from ipsec

### Block every other traffic
iptables -A INPUT -i enp0s8 -j DROP

## Save the iptables rules
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

cat > /etc/ipsec.conf << EOL
conn cloud-to-a
        left=172.30.30.30
        leftsubnet=172.30.30.30/32
        right=172.16.16.16
        rightsubnet=172.16.16.16/32 
        type=tunnel
        auto=start
        keyexchange=ikev2
        authby=secret
        ike=aes256-sha512-modp3072!
        esp=aes256-sha256!
        dpdaction=restart
        dpddelay=30s
        dpdtimeout=120s

conn cloud-to-b
        left=172.30.30.30
        leftsubnet=172.30.30.30/32
        right=172.18.18.18
        rightsubnet=172.18.18.18/32 
        type=tunnel
        auto=start
        keyexchange=ikev2
        authby=secret
        ike=aes256-sha512-modp3072!
        esp=aes256-sha256!
        dpdaction=restart
        dpddelay=30s
        dpdtimeout=120s

EOL

echo 172.30.30.30 172.16.16.16 : PSK \"bQlcDdS1QWnmkD2c4gUTT3RPv7oafFZ6ArKVOedXBskwdADkKEJLKxS4wpwC85aoX8yLGCnQ+dgXMgBtEUXi8A==\" >> /etc/ipsec.secrets
echo 172.30.30.30 172.18.18.18 : PSK \"XFIVGJWguyjhw02TYBVHeLRTE/1ldbXPjIMSiM/ELYSGm2tnxdbW+/W7E92FZLBQE+M5zt/oVoTUWSKbnsgeiw==\" >> /etc/ipsec.secrets

ipsec restart