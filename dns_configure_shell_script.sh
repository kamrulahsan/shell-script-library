#!/bin/bash
#yum update -y
#yum upgrade -y
#echo -e "Please enter the domain name: "
#read domain_name

read -p "Please enter the domain IP: " domain_ip

read -p "Please enter the domain name: " domain_name



yum install bind bind-utils -y
mv /etc/named.conf /etc/named.conf.original



cat >/etc/named.conf <<EOL
options {
        listen-on port 53 { any; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";

        secroots-file   "/var/named/data/named.secroots";
        allow-query     { any; };
        recursion no;

        dnssec-enable yes;
        dnssec-validation yes;

        bindkeys-file "/etc/named.iscdlv.key";
        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOL

chown named:named /etc/named.conf

cat >/etc/named.conf <<EOL
zone    $domain_name.com  {
        type master;
        file    "/var/named/forward.$domain_name.com";
 };
EOL



cat >>/etc/named.conf <<EOL
zone   "$domain_ip.in-addr.arpa"  {
       type master;
       file    "/var/named/reverse.$domain_name.com";
 };
EOL


cat >> /var/named/forward.$domain_name.com <<EOL
\$TTL 1d
@               IN      SOA     dns1.$domain_name.com.    hostmaster.$domain_name.com. (
                1        ; serial
                6h       ; refresh after 6 hours
                1h       ; retry after 1 hour
                1w       ; expire after 1 week
                1d )     ; minimum TTL of 1 day
;
;
;Name Server Information
@               IN      NS      ns1.$domain_name.com.
ns1             IN      A       $domain_ip
;
EOL

chown named:named /var/named/forward.$domain_name.com


cat >/var/named/reverse.$domain_name.com <<EOL
\$TTL 1d
@               IN      SOA     dns1.$domain_name.com.    hostmaster.$domain_name.com. (
                1        ; serial
                6h       ; refresh after 6 hours
                1h       ; retry after 1 hour
                1w       ; expire after 1 week
                1d )     ; minimum TTL of 1 day
;
;
;Name Server Information
@               IN      NS      ns1.$domain_name.com.
ns1             IN      A       $domain_ip
;
;
;Reverse IP Information
$domain_ip.in-addr.arpa.      IN      PTR       ns1.$domain_name.com.
EOL

chown named:named /var/named/reverse.$domain_name.com

systemctl start named
systemctl enable named

firewall-cmd --permanent --add-port=53/tcp
firewall-cmd --permanent --add-port=53/udp
firewall-cmd --reload

systemctl restart NetworkManager
