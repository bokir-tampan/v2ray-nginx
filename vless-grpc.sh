#!/bin/bash

read -e -p " Masukan Domain :$domain" domain
echo -e "$domain" >> /root/domain

domain=$(cat /root/domain)
apt install iptables iptables-persistent -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y 
apt install socat cron bash-completion ntpdate -y
ntpdate pool.ntp.org
apt -y install chrony
timedatectl set-ntp true
systemctl enable chronyd && systemctl restart chronyd
systemctl enable chrony && systemctl restart chrony
timedatectl set-timezone Asia/Jakarta
apt install python -y
apt install python3 -y
chronyc sourcestats -v
chronyc tracking -v
date

# install v2ray
wget -q -O /usr/local/bin/xray "https://github.com/bokir-tampan/v2ray-nginx/raw/main/xray" 
chmod +x /usr/local/bin/xray

# // Make XRay  Root Folder

mkdir -p /etc/xray/
chmod 775 /etc/xray/
mkdir /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
service squid start
uuid=$(cat /proc/sys/kernel/random/uuid)
cat> /etc/xray/vtls.json << END
{
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [{
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                {
                 "id": "${uuid}"
#tls
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 81
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                "serviceName": "Bokir-Tampan",
                "multiMode": true
            },
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "h2"
                    ],
                    "certificates": [{
                            "certificateFile": "/etc/xray/xray.crt",
                            "keyFile": "/etc/xray/xray.key"
                        }
                    ]
                }
            }
        }
    ],
    "outbounds": [{
            "protocol": "freedom"
        }
    ]
}
END
cat> /etc/xray/vnone.json << END
{
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [{
            "port": 80,
            "protocol": "vless",
            "settings": {
                "clients": [
                {
                 "id": "${uuid}"
#none
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 81
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                "serviceName": "Bokir-Tampan",
                "multiMode": true
            },
                "security": "none",
                "tlsSettings": {
                    "alpn": [
                        "h2"
                    ],
                    "certificates": [{
                            "certificateFile": "/etc/xray/xray.crt",
                            "keyFile": "/etc/xray/xray.key"
                        }
                    ]
                }
            }
        }
    ],
    "outbounds": [{
            "protocol": "freedom"
        }
    ]
}
END
cat > /etc/systemd/system/xray@.service << EOF
[Unit]
Description=XRay Service ( %i )
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target
[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray -config /etc/xray/%i.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
cd /usr/bin/
wget https://raw.githubusercontent.com/bokir-tampan/v2ray-nginx/main/addgrpc
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 80 -j ACCEPT
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload
systemctl daemon-reload
systemctl enable xray@vtls.service
systemctl start xray@none.service
systemctl restart xray@vtls
systemctl restart xray@vnone
chmod +x /usr/bin/addgrpc
cd
mv domain /etc/xray/domain


