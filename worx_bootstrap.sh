#!/bin/bash

# Make sure unzip is installed
clear
apt-get -qq update
apt -qqy install unzip

clear
echo "This script will refresh your masternode."
read -rp "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

if [ -e /etc/systemd/system/worx.service ]; then
  systemctl stop worx.service
else
  su -c "worx-cli stop" "root"
fi

echo "Refreshing node, please wait."

sleep 5

rm -rf "/root/.worx/blocks"
rm -rf "/root/.worx/chainstate"
rm -rf "/root/.worx/peers.dat"

echo "Installing bootstrap file..."

cd /root/.worx && wget https://github.com/worxcoin/worx/releases/download/1.5.1.1/bootstrap.tar.gz && tar -xvzf bootstrap.tar.gz && rm bootstrap.tar.gz

if [ -e /etc/systemd/system/worx.service ]; then
  sudo systemctl start worx.service
else
  su -c "worxd -daemon" "root"
fi

echo "Starting worx, will check status in 60 seconds..."
sleep 60

clear

if ! systemctl status worx.service | grep -q "active (running)"; then
  echo "ERROR: Failed to start worx. Please re-install using install script."
  exit
fi

echo "Waiting for wallet to load..."
until su -c "worx-cli getinfo 2>/dev/null | grep -q \"version\"" "$USER"; do
  sleep 1;
done

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can a few minutes. Do not close this window."
echo ""

until [ -n "$(worx-cli getconnectioncount 2>/dev/null)"  ]; do
  sleep 1
done

until su -c "worx-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\": true' > /dev/null" "$USER"; do 
  echo -ne "Current block: $(su -c "worx-cli getblockcount" "$USER")\\r"
  sleep 1
done

clear

cat << EOL
Now, you need to start your masternode. If you haven't already, please add this
node to your masternode.conf now, restart and unlock your desktop wallet, go to
the Masternodes tab, select your new node and click "Start Alias."
EOL

read -rp "Press Enter to continue after you've done that. " -n1 -s

clear

sleep 1
su -c "/usr/local/bin/worx-cli startmasternode local false" "$USER"
sleep 1
clear
su -c "/usr/local/bin/worx-cli masternode status" "$USER"
sleep 5

echo "" && echo "Masternode refresh completed." && echo ""
