#!/usr/bin/env bash
set -ex

EASY_RSA_LOC="/etc/openvpn/easyrsa"
SERVER_CERT="${EASY_RSA_LOC}/pki/issued/server.crt"

OVPN_SRV_NET=${OVPN_SERVER_NET:-172.16.100.0}
OVPN_SRV_MASK=${OVPN_SERVER_MASK:-255.255.255.0}

OVPN_SRV_MGMT=${OVPN_MGMT:-127.0.0.1}

# 设置需要检测的文件
fileDir="${OVPN_SETUP_PATH:-/etc/openvpn/setup/openvpn.conf}"


cd $EASY_RSA_LOC

if [ -e "$SERVER_CERT" ]; then
  echo "Found existing certs - reusing"
else
  if [ ${OVPN_ROLE:-"master"} = "slave" ]; then
    echo "Waiting for initial sync data from master"
    while [ $(wget -q localhost/api/sync/last/try -O - | wc -m) -lt 1 ]
    do
      sleep 5
    done
  else
    echo "Generating new certs"
    easyrsa init-pki
    cp -R /usr/share/easy-rsa/* $EASY_RSA_LOC/pki
    echo "ca" | easyrsa build-ca nopass
    easyrsa build-server-full server nopass
    easyrsa gen-dh
    openvpn --genkey --secret ./pki/ta.key
  fi
fi
easyrsa gen-crl

iptables -t nat -D POSTROUTING -s ${OVPN_SRV_NET}/${OVPN_SRV_MASK} ! -d ${OVPN_SRV_NET}/${OVPN_SRV_MASK} -j MASQUERADE || true
iptables -t nat -A POSTROUTING -s ${OVPN_SRV_NET}/${OVPN_SRV_MASK} ! -d ${OVPN_SRV_NET}/${OVPN_SRV_MASK} -j MASQUERADE

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

cp -f /etc/openvpn/setup/openvpn.conf /etc/openvpn/openvpn.conf

if [ ${OVPN_PASSWD_AUTH} = "true" ]; then
  mkdir -p /etc/openvpn/scripts/
  cp -f /etc/openvpn/setup/auth.sh /etc/openvpn/scripts/auth.sh
  chmod +x /etc/openvpn/scripts/auth.sh
  echo "auth-user-pass-verify /etc/openvpn/scripts/auth.sh via-file" | tee -a /etc/openvpn/openvpn.conf
  echo "script-security 2" | tee -a /etc/openvpn/openvpn.conf
  echo "verify-client-cert require" | tee -a /etc/openvpn/openvpn.conf
  openvpn-user db-init --db.path=$EASY_RSA_LOC/pki/users.db
fi

[ -d $EASY_RSA_LOC/pki ] && chmod 755 $EASY_RSA_LOC/pki
[ -f $EASY_RSA_LOC/pki/crl.pem ] && chmod 644 $EASY_RSA_LOC/pki/crl.pem

mkdir -p /etc/openvpn/ccd

#函数定义
function restartOpenvpn(){
    echo "重启openvpn......"
    appId=$(ps aux | grep "[o]penvpn --config" |  awk '{print $1}')
    if [ "$appId" ]; then
        kill -9 "$appId"
        cp -f /etc/openvpn/setup/openvpn.conf /etc/openvpn/openvpn.conf
        sleep 2
    fi
    nohup openvpn --config /etc/openvpn/openvpn.conf --client-config-dir /etc/openvpn/ccd --port 1194 --proto tcp --management ${OVPN_SRV_MGMT} 8989 --dev tun0 --server ${OVPN_SRV_NET} ${OVPN_SRV_MASK} >> /tmp/openvpn.log 2>&1 &

}
#函数调用
restartOpenvpn



nohup \
inotifywait -mr \
  --timefmt '%d/%m/%y %H:%M' --format '%T %w %f' \
  -e modify $fileDir |
while read -r date time dir file; do
       changed_abs=${dir}${file}

       echo $(date +%F%n%T) $changed_abs '已经被改变，执行重启步骤！'>>/tmp/openvpn.log
       # 重启应用
       restartOpenvpn

done >> /tmp/openvpn.log 2>&1 &

tail -f /tmp/openvpn.log

