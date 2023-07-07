#!/usr/bin/env bash

cd $(dirname $0)
cd ./../resources/exploit/

device_dfu=$(irecovery -m | grep -c "DFU")

if [ $device_dfu == 0 ];then
    echo "[Exiting] No device found in DFU Mode."
    exit
fi

device_id=$(irecovery -q | grep "PRODUCT" | cut -f 2 -d ":" | cut -c 2-)

if [[ "$device_id" == *"iPhone10"* ]];then
  if [ ! -d ./ipwndfuA11 ]; then
    # ipwndfuA11 for iPhoneX,iPhone8,iPhone8+
    git clone https://github.com/MatthewPierson/ipwndfuA11.git
  fi

  cd ipwndfuA11
else
  if [ ! -d ./ipwndfu_public ]; then
    git clone https://github.com/sen0rxol0/ipwndfu.git
    # https://github.com/LinusHenze/ipwndfu_public.git
  fi

  cd ipwndfu
fi

if [ ! -e ./ipwndfu ]; then
  echo "[Exiting] Device not supported !"
  exit
fi

check=0
until [ $check = 1 ];
do
  echo "(^C to quit) The script will run ipwndfu again and again until the device is in pwned DFU mode !"
  sleep 1
  echo "-Starting ipwndfu checkm8 exploit ..."
  ./ipwndfu -p
  check=$(lsusb | grep -c "checkm8")
done

sleep 1

echo "-Device is in pwned DFU mode. Continuing ..."
echo "-Patching signature checks now ..."

if [[ "$device_id" == *"iPhone10"* ]]; then
  ./ipwndfu --patch
  sleep 1
else
  python rmsigchks.py
  sleep 1
fi

echo "-Device is now in pwned DFU mode with SecureROM Signature checks removed !"
# killall Terminal
# exit
