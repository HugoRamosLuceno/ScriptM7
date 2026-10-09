#!/bin/bash

setxkbmap es # Set keyboard to spanish

sudo apt update # Update repos of the ISO, tend to be outdated

sudo apt install tmux neovim flameshot # Install needed tools and personal preference tools

sudo apt install bind9 dnsutils nmap # Install class packages

cat << EOF

#############################
-----------------------------
Changing IP to 192.168.202.17
-----------------------------
#############################

EOF

cat << EOF | sudo tee -a /etc/network/interfaces > /dev/null
auto eno1
iface eno1 inet static
	address 192.168.202.17
	netmask 255.255.0.0
	gateway 192.168.88.88
EOF

sudo systemctl stop networking
cat << EOF
#######################################
---------------------------------------
Waiting 20 seconds for service to stop
---------------------------------------
#######################################
EOF
sleep 20
sudo systemctl start networking


cat << EOF





########################


------------------------


Starting network service


------------------------


########################





EOF





ip -c a show dev eno1
