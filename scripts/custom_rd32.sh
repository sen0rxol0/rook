#!/usr/bin/env bash

cat <<EOF
================================================================================
#      Custom ramdisk maker script, made by @sen0rxol0.
#
# USAGE: sudo $0 <iOS firmware version>
# Device support: A6
# Credits/Thanks:
#   xpwntool, ldid2, partialZipBrowser, plutil
#   https://github.com/dora2-iOS/iBoot32Patcher
#   https://github.com/Ralph0045/SSH-Ramdisk-Maker-and-Loader
#   https://github.com/dayt0n/restored-external-hax
================================================================================
EOF

if [ $UID != 0 ];then
    echo "Run this script with sudo:"
    echo "\$ sudo $0 $*"
    exit 1
fi

sleep 1
swd=$(dirname $0)
swd_bin=$swd/../bin

cd $swd

_deviceInfo()
{
  echo $(irecovery -q | grep "$1" | sed "s/$1: //")
}
device_cpid=`_deviceInfo "CPID"`
if [ -z $device_cpid ]; then
  echo "[EXITING] No device connected!"
  exit
fi
device_id=`_deviceInfo "PRODUCT"`
device_model=`_deviceInfo "MODEL"`
echo "DEVICE: -type:$device_id -model:$device_model -cpid:$device_cpid ******"
sleep 4

if [ -z $1 ]; then
  # ipsw_version="10.3.3"
  ipsw_version="8.4.1"
else
  ipsw_version=$1
fi

ipsw_url=$(curl --header "Accept: application/json" https://api.ipsw.me/v4/ipsw/$ipsw_version | python3 -c "import sys, json;[print(o['url']) for o in json.load(sys.stdin) if o['identifier'] == '$device_id']")

if [ -z $ipsw_url ]; then
  echo "[EXITING] Failed to find IPSW download URL!"
  exit
fi

rd_mnt=/tmp/rd_staging_mnt
rd_staging=/tmp/rd_staging_$device_model

if [ -d $rd_staging ]; then
  rm -rf $rd_staging/
fi

mkdir $rd_staging
cd $rd_staging
$swd_bin/pzb -g BuildManifest.plist $ipsw_url

if [ ! -e BuildManifest.plist ]; then
  echo "[EXITING] BuildManifest could not be downloaded!"
  exit
fi


firmware_version=$(plutil -extract 'ProductVersion' xml1 -o - $rd_staging/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
echo "Firmware version: $firmware_version"
restore_version_u=${firmware_version/./_}
rev_device=${restore_version_u}_${device_id}_${device_model}
manifest_index=0
ret=0

until [[ $ret != 0 ]]; do
  manifest=$(plutil -extract "BuildIdentities.$manifest_index.Manifest" xml1 -o - $rd_staging/BuildManifest.plist)
  ret=$?
  if [ $ret == 0 ]; then
    count_manifest=$(echo $manifest | grep -c "$device_model")
    if [ $count_manifest == 0 ]; then
      ((manifest_index++))
    else
      ret=1
    fi
  fi
done

if [ $ret != 1 ]; then
  echo "[EXITING] Restore manifest for device not found."
  exit
fi

_extractFromManifest()
{
    echo $(plutil -extract "BuildIdentities.$manifest_index.Manifest.$1.Info.Path" xml1 -o - $rd_staging/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
}

echo "Downloading required files from IPSW ..."
sleep 1
$swd_bin/pzb -g $(_extractFromManifest "iBSS") -o ./iBSS.dfu $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "iBEC") -o ./iBEC.dfu $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "DeviceTree") -o ./DeviceTree.img3 $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "RestoreKernelCache") -o ./RestoreKernelCache.release $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "RestoreRamDisk") -o ./RestoreRamDisk.dmg $ipsw_url

if [ ! -e RestoreRamDisk.dmg ]; then
  echo "[EXITING] Failed to download required files from IPSW!"
  exit
fi

iv=""
key=""

ramdisk_iv="104935a03d8baec8c6260ca69280f92c"
ramdisk_key="354e528373074b3c2179cba9538902b3dd7c603595a707f883ca6ca4bf14bf7e"
devicetree_iv="667bff76ee274db0b5658361f040ac89"
devicetree_key="e1c09c81f08dedc06d9aba515e82b3665b7d724b0dd5d9ad012adaf8b7f6268b"
ibec_iv="add7db95ab270c16ddd632cdc9a4ebac"
ibec_key="77b7990cbb88f3d091aaff10b424ab19c5263f100eb1ee642771500510b0dd42"
ibss_iv="a5892a58c90b6d3fb0e0b20db95070d7"
ibss_key="75612774968009e3f85545ac0088d0d0bb9cb4e2c2970e8f88489be0b9dfe103"
kernelcache_iv="6a417efd8f6d5fd1bb91c97367b428ca"
kernelcache_key="42dc4a9f72b46686f7f53fa76782b108c2fda37056095ddd775eb000b2fdfa7d"

$swd_bin/xpwntool ./RestoreRamDisk.dmg ./RestoreRamDisk.dec.dmg -iv $ramdisk_iv -k $ramdisk_key -decrypt
$swd_bin/xpwntool ./RestoreRamDisk.dec.dmg ./ramdisk.dmg

mkdir $rd_mnt
hdiutil resize ramdisk.dmg -size 40m
hdiutil attach ramdisk.dmg -mountpoint $rd_mnt/

cd $swd/../resources

tar -xzvkPf ./ssh.tar.gz -C $rd_mnt/

cp -f ./data/usr/lib32/* $rd_mnt/usr/lib/
### ----------------------------------------------------------------------------
# # xcrun -sdk iphoneos clang -arch armv7 -framework IOKit -framework CoreFoundation -Wall -o ./restored_external32 ./restored-external-hax-master/src/restored_external_hax.c
# # codesign -f -s - -i com.apple.restored_external ./restored_external32
cp ./data/restored_external32 $rd_mnt/restored_external

cd $rd_mnt

rm ./usr/local/bin/restored_external
mv ./restored_external ./usr/local/bin/
chmod 755 ./usr/local/bin/restored_external
# cat <<EOF > ./ent.xml
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
#   <key>platform-application</key>
#   <true/>
# 	<key>com.apple.private.security.disk-device-access</key>
# 	<true/>
#   <key>com.apple.private.security.container-required</key>
#   <false/>
# </dict>
# </plist>
# EOF
# $swd_bin/ldid2 -M -Sent.xml ./usr/local/bin/restored_external
# rm ./ent.xml
### ----------------------------------------------------------------------------
rm -rf ./usr/local/standalone/firmware/*
rm -rf ./usr/share/progressui/
### ----------------------------------------------------------------------------
# chmod 0755 ./bin/*
# chmod 0755 ./usr/bin/*
# chmod 0755 ./usr/sbin/*
# chmod 0755 ./usr/local/bin/*
# chown -f -R root:wheel ./*
### ----------------------------------------------------------------------------
echo "WELCOME BACK!" > ./etc/motd

cd $rd_staging/

hdiutil detach -force $rd_mnt
sleep 5
rm -rf $rd_mnt/

$swd_bin/xpwntool ./ramdisk.dmg ./ramdisk -t RestoreRamDisk.dmg
### ----------------------------------------------------------------------------
$swd_bin/xpwntool ./RestoreKernelCache.release ./kernelcache -iv $kernelcache_iv -k $kernelcache_key -decrypt
# $swd_bin/xpwntool ./RestoreKernelCache.release ./kernelcache
# mv ./RestoreKernelCache.release ./kernelcache
# $swd_bin/CBPatcher ./kernelcache ./kernelcache.patched $ipsw_version
# $swd_bin/xpwntool ./kernelcache.patched ./pwnkc -t ./RestoreKernelCache.release

$swd_bin/xpwntool ./DeviceTree.img3 ./devicetree -iv $devicetree_iv -k $devicetree_key -decrypt

$swd_bin/xpwntool ./iBEC.dfu ./ibec.dec.dfu -iv $ibec_iv -k $ibec_key -decrypt
$swd_bin/xpwntool ./ibec.dec.dfu ./ibec.dec
# $swd_bin/iBoot32Patcher ./ibec.dec ./ibec.patched -b "rd=md0 amfi=0xff cs_enforcement_disable=1 amfi_get_out_of_my_way=1 -v" --rsa --debug
$swd_bin/iBoot32Patcher ./ibec.dec ./ibec.patched -b "rd=md0 amfi=0xff cs_enforcement_disable=1 -v" --rsa --debug
$swd_bin/xpwntool ./ibec.patched ./iBEC -t ./iBEC.dfu

$swd_bin/xpwntool ./iBSS.dfu ./ibss.dec.dfu -iv $ibss_iv -k $ibss_key -decrypt
$swd_bin/xpwntool ./ibss.dec.dfu ./ibss.dec
$swd_bin/iBoot32Patcher ./ibss.dec ./ibss.patched --rsa
mv ibss.patched iBSS
# $swd_bin/xpwntool ./ibss.patched ./iBSS -t ./iBSS.dfu

mkdir rdsk
mv devicetree rdsk/
mv kernelcache rdsk/
mv ramdisk rdsk/
mv iBEC rdsk/
mv iBSS rdsk/

cd $swd/../resources
device_rdsk_path=rdsk/$device_id
mkdir -p $device_rdsk_path
cd ./$device_rdsk_path
mv -v $rd_staging/rdsk/* ./
sleep 1

if [ -e ../$rev_device.tar.gz ];then
	rm ../$rev_device.tar.gz
fi

tar -czf ../$rev_device.tar.gz ./
cd ../
rm -r ./$device_id/
