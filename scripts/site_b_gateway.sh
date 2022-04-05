#!/usr/bin/env bash

## NAT traffic going to the internet
route add default gw 172.18.18.1
iptables -t nat -A POSTROUTING -o enp0s8 -j MASQUERADE

## Save the iptables rules
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

## Security
### Allow ipsec packets
iptables -A INPUT -i enp0s8 -p udp --dport 500 -j ACCEPT # IKE
iptables -A INPUT -i enp0s8 -p udp --dport 4500 -j ACCEPT # NAT traversal

## Allow ipsec traffic
iptables -A INPUT -p tcp --dport ssh -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i enp0s8 -p esp -j ACCEPT  # encrypted packets

### Block every other traffic
iptables -A INPUT -i enp0s8 -j DROP

cat > /etc/ipsec.conf <<EOL
conn b-to-cloud
        left=172.18.18.18
        leftsubnet=172.18.18.18/32
        right=172.30.30.30
        rightsubnet=172.30.30.30/32
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
echo 172.18.18.18 172.30.30.30 : PSK \"XFIVGJWguyjhw02TYBVHeLRTE/1ldbXPjIMSiM/ELYSGm2tnxdbW+/W7E92FZLBQE+M5zt/oVoTUWSKbnsgeiw==\" >> /etc/ipsec.secrets

ipsec restart