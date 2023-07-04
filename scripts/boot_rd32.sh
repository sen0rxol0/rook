#!/usr/bin/env bash
echo "=============================================================================="
echo "            Custom ramdisk boot script, made by @sen0rxol0."
echo "=============================================================================="

cd $(dirname $0)
swd=$(pwd)
ipwndfu_exploit=$swd/../resources/exploit/ipwndfu

if [ ! -z "$1" ]
then
rdsk_file=$1
else
  select rdsk in $(ls $swd/../resources/rdsk/*)
  do
  rdsk_file=$rdsk
  break
  done
fi

rm -r /tmp/.boot_rd32/
mkdir /tmp/.boot_rd32
tar -C /tmp/.boot_rd32/ -xpf $rdsk_file
sleep 1
clear

cd $ipwndfu_exploit
./ipwndfu -p
sleep 2

pwnd=$(irecovery -q | grep -c "PWND")

if [ $pwnd = 0 ]; then
    echo "[Exiting] No device found in pwned DFU Mode!"
    exit 1
fi

./ipwndfu -l /tmp/.boot_rd32/iBSS
cd /tmp/.boot_rd32
# irecovery -f iBSS
sleep 1
irecovery -f iBEC
sleep 1

if [ -e bootlogo ];
then
	irecovery -f bootlogo
	irecovery -c "setpicture 0"
	irecovery -c "bgcolor 0 0 0"
else
  irecovery -c "bgcolor 255 55 55"
fi

irecovery -f devicetree
irecovery -c "devicetree"
irecovery -f ramdisk
irecovery -c "ramdisk"
irecovery -f kernelcache
irecovery -c "bootx"
cd $swd
sleep 15
echo
echo "Connect with password 'alpine': \$ ssh root@localhost -p2222"
echo
echo "Press (^C) to quit !"
echo
iproxy 2222 22
