#!/bin/bash
cd "$(dirname "$0")"
PASS=$2

echo "Инициализация установочного скрипта установщика OPENVPN для операционной системы типа Ubuntu";

SSOPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
USERR="root"

echo "Обновление системы удаленного сервера";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "locale-gen en_US.UTF-8"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "apt-get update"

echo "Установка OPENVPN";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "apt-get -y install openvpn easy-rsa"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "make-cadir ~/openvpn-ca"

echo "Конфигурирование OPENVPN";
# sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/US/RU/' ./vars"
# sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/CA/MO/' ./vars"
# sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/SanFrancisco/Moscow/' ./vars"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/Fort-Funston/Ltd/' ./vars"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/me@myhost.mydomain/qwer@qwer.qw/' ./vars"
#sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/MyOrganizationalUnit/Community_1/' ./vars"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/EasyRSA/server/' ./vars"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; sed -i 's/export KEY_SIZE=1024/export KEY_SIZE=2048/' ./vars"

echo "Конфигурирование OPENVPN...";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; source vars; ./clean-all; ./build-ca; ./build-key-server server; ./build-dh"
echo "можем сгенерировать подпись HMAC для усиления способности сервера проверять целостность TSL";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "openvpn --genkey --secret ~/openvpn-ca/keys/ta.key"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/openvpn-ca; source vars; ./build-key client1; cd ~/openvpn-ca/keys; cp ca.crt ca.key server.crt server.key ta.key dh2048.pem /etc/openvpn"
sshpass -p $PASS scp $SSOPT server.conf $USERR@$1:/etc/openvpn/server.conf

sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd /etc/; sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' ./sysctl.conf"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd /etc/; sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' ./sysctl.conf"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "sysctl -p"

echo "Установка Firewall UFW:";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "apt-get install ufw"

echo "Настройка Firewall UFW";
sshpass -p $PASS scp $SSOPT ufw_before.conf $USERR@$1:/etc/ufw/before.rules
sshpass -p $PASS ssh $SSOPT $USERR@$1 "sed -i 's/DEFAULT_FORWARD_POLICY=\"DROP\"/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/' /etc/default/ufw"

echo "Перезагрузка Firewall UFW";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "ufw allow 1194/udp"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "ufw allow OpenSSH"

sshpass -p $PASS ssh $SSOPT $USERR@$1 "ufw disable"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "ufw enable"

echo "Запуск OpenVPN";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "systemctl start openvpn@server"

echo "Проверка статус OpenVPN";
sshpass -p $PASS ssh $SSOPT $USERR@$1 "systemctl status openvpn@server"

echo "Настройка сервиса на автоматическое включение при настройке сервиса OpenVPN"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "systemctl enable openvpn@server"

echo "Генерация клиентского конфига OpenVPN"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "mkdir -p ~/client-configs/files"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "chmod 700 ~/client-configs/files"
sshpass -p $PASS scp $SSOPT base.conf $USERR@$1:~/client-configs/base.conf
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/client-configs/; sed -i 's/remote IP_SERVER/remote $1/' ./base.conf"

sshpass -p $PASS scp $SSOPT make_config.conf $USERR@$1:~/client-configs/make_config.sh
sshpass -p $PASS ssh $SSOPT $USERR@$1 "chmod 700 ~/client-configs/make_config.sh"

echo "Генерация клиентского файла конфига client1"
sshpass -p $PASS ssh $SSOPT $USERR@$1 "cd ~/client-configs; ./make_config.sh client1"

echo "Копирование клиентского файла конфига client1 в локальную директорию ~"
#sshpass -p $PASS ssh $SSOPT $USERR@$1 "sftp root@$1:client-configs/files/client1.ovpn ~/"
sshpass -p $PASS scp $SSOPT $USERR@$1:~/client-configs/files/client1.ovpn ./client_$1.ovpn

exit 0
