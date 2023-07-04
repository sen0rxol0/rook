#!/usr/bin/env bash

cat <<EOF
================================================================================
#      Custom ramdisk maker script, made by @sen0rxol0.
#
# USAGE: sudo $0 <shsh> <iOS firmware version>
# Device support: A7, A8, A8X, A9, A9X, A10, A10X, A11 and T2
# Credits/Thanks:
#   img4, img4tool, Kernel64Patcher, iBoot64Patcher, ldid2, partialZipBrowser, plutil
#   https://github.com/Ralph0045/SSH-Ramdisk-Maker-and-Loader
#   http://newosxbook.com iosBinaries
#   https://github.com/dayt0n/restored-external-hax
================================================================================
EOF

if [ $UID != 0 ];then
    echo "Run this script with sudo:"
    echo "\$ sudo $0 $*"
    exit 1
fi

sleep 1
cd $(dirname $0)
swd=$(pwd)
cd $swd/../bin
swd_bin=$(pwd)
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
# device_id_lc=${device_id/P/p}
# device_model_short=${device_model:0:3}
echo "DEVICE: -type:$device_id -model:$device_model -cpid:$device_cpid ******"
sleep 4

# tsschecker -e ECID -d PRODUCT -B MODEL -s -l

if [ -z $1 ]; then
  echo "Drag and drop SHSH file into terminal:"
  read shsh
else
  shsh=$1
fi
if [ ! -e $shsh ]; then
	echo "[EXITING] SHSH file is required to continue!"
	exit
fi

if [ -z $2 ]; then
  ipsw_version="14.3"
else
  ipsw_version=$2
fi

ipsw_url=$(curl --header "Accept: application/json" https://api.ipsw.me/v4/ipsw/$ipsw_version | python3 -c "import sys, json;[print(o['url']) for o in json.load(sys.stdin) if o['identifier'] == '$device_id']")
# ipsw_bid=$(curl --header "Accept: application/json" https://api.ipsw.me/v4/ipsw/$ipsw_version | python3 -c "import sys, json;[print(o['buildid']) for o in json.load(sys.stdin) if o['identifier'] == '$device_id']")

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
# 14_3_iPhone9,3_d101ap
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
$swd_bin/pzb -g $(_extractFromManifest "iBSS") -o ./ibss.im4p $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "iBEC") -o ./ibec.im4p $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "DeviceTree") -o ./dtree.im4p $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "RestoreTrustCache") -o ./dmg.trustcache $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "RestoreKernelCache") -o ./kernelcache.release $ipsw_url
$swd_bin/pzb -g $(_extractFromManifest "RestoreRamDisk") -o ./rdsk.dmg $ipsw_url

if [ ! -e rdsk.dmg ]; then
  echo "[EXITING] Failed to download required files from IPSW!"
  exit
fi

echo "Preparing the bootchain ..."
sleep 1
# echo "[*_*] Converting SHSH to IM4M for signing ..."
img4tool -e -s $shsh -m $rd_staging/IM4M
# echo "[*_*] Signing and packing bootlogo into img4 ..."
cd $swd/../resources
# img4tool -c bootlogo@750x1334.im4p -t logo bootlogo@750x1334.ibootim
img4 -i ./bootlogo@750x1334.im4p -o $rd_staging/bootlogo.img4 -M $rd_staging/IM4M
# echo "[*_*] Decrypting iBSS,iBEC ..."
build_train=$(plutil -extract "BuildIdentities.$manifest_index.Info.BuildTrain" xml1 -o - $rd_staging/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
build_number=$(plutil -extract "BuildIdentities.$manifest_index.Info.BuildNumber" xml1 -o - $rd_staging/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)

if [[ $device_id == *"iPhone8,"* ]]; then
  device_fk="${build_train}_${build_number}_${device_id}_${device_model}_"
else
  device_fk="${build_train}_${build_number}_${device_id}_"
fi

if [ ! -e ./fk/${device_fk}ibss.key ];then
  echo "[EXITING] Firmware version or device not supported!"
  exit
fi

ibss_iv=$(cat ./fk/${device_fk}ibss.iv)
ibss_key=$(cat ./fk/${device_fk}ibss.key)
ibec_iv=$(cat ./fk/${device_fk}ibec.iv)
ibec_key=$(cat ./fk/${device_fk}ibec.key)

# cd $swd
# ./run_gaster decrypt $rd_staging/ibss.im4p $rd_staging/ibss.dec
# ./run_gaster decrypt $rd_staging/ibec.im4p $rd_staging/ibec.dec
cd $rd_staging
img4 -i ./ibss.im4p -o ./ibss.dec -k $ibss_iv$ibss_key
img4 -i ./ibec.im4p -o ./ibec.dec -k $ibec_iv$ibec_key
# echo "[*_*] Patching iBSS,iBEC ..."
$swd_bin/iBoot64Patcher ./ibss.dec ./ibss.patched
$swd_bin/iBoot64Patcher ./ibec.dec ./ibec.patched -n -b "rd=md0 -v"
# echo "[*_*] Signing and packing iBSS,iBEC into img4 ..."
img4 -i ./ibss.patched -o ./ibss.img4 -A -M IM4M -T ibss
img4 -i ./ibec.patched -o ./ibec.img4 -A -M IM4M -T ibec
# echo "[*_*] Signing and packing DeviceTree into img4 ..."
img4 -i ./dtree.im4p -o ./dtree.img4 -M IM4M -T rdtr
# echo "[*_*] Signing and packing Restore Trustcache into img4 ..."
img4 -i ./*.trustcache -o ./trustcache.img4 -M IM4M -T rtsc
# echo "[*_*] Decrypting Kernelcache ..."
img4 -i ./kernelcache.release -o ./kcache.dec
# echo "[*_*] Patching Kernelcache ..."
$swd_bin/Kernel64Patcher ./kcache.dec ./kcache.patched -a
# echo "[*_*] Signing and packing patched Kernelcache into img4 ..."

if [[ "$device_cpid" == *"0x801"* ]]; then
  img4tool -c ./kcache.im4p -t rkrn ./kcache.patched --compression complzss
  img4 -i ./kcache.im4p -o ./kcache.img4 -M IM4M
else
  touch kc.bpatch
  python3 $swd_bin/diff.py ./kcache.dec ./kcache.patched ./kc.bpatch
  img4 -i ./kernelcache.re* -o ./kcache.img4 -T rkrn -P ./kc.bpatch -M IM4M
  # img4 -i ./kernelcache.re* -o ./kcache.img4 -T rkrn -P kc.bpatch -J -M IM4M # if linux
fi

echo "Continuing with custumizing RestoreRamdisk ..."
sleep 4
img4 -i ./rdsk.dmg -o ./rd.dmg
mkdir $rd_mnt
hdiutil resize -size 155MB ./rd.dmg
hdiutil attach ./rd.dmg -mountpoint $rd_mnt -owners on
sleep 5
# echo "[*_*] Compiling and signing restored_external ..."
cd $swd/../resources
# xcrun -sdk iphoneos clang -arch arm64 -framework IOKit -framework CoreFoundation -Wall -o ./restored_external ./restored-external-hax-master/src/restored_external_hax.c
cp ./data/restored_external $rd_mnt/
$swd_bin/ldid2 -e $rd_mnt/usr/local/bin/restored_external > $rd_mnt/restored_external_ent.plist
plutil -insert 'platform-application' -bool "true" $rd_mnt/restored_external_ent.plist
$swd_bin/ldid2 -S$rd_mnt/restored_external_ent.plist $rd_mnt/restored_external
cd $rd_mnt
rm ./restored_external_ent.plist
# echo "[*_*] Replacing restored_external ..."
mv ./usr/local/bin/restored_external ./usr/local/bin/restored_external_
mv ./restored_external ./usr/local/bin/
# echo "[*_*] Adding required SSH files to ramdisk ..."
echo "WELCOME BACK!" > ./etc/motd
mkdir ./private/var/root
mkdir ./private/var/run
mkdir ./sshd
cd $swd/../resources
tar -C $rd_mnt/sshd -xf ./ssh64.tar.gz
cp ./data/bin/mountfs $rd_mnt/sshd/usr/local/bin/
$swd_bin/ldid2 -M -Sent.xml $rd_mnt/sshd/usr/local/bin/mountfs
cp ./data/etc/dropbear/* $rd_mnt/sshd/etc/dropbear/
cp -Rn ./data/usr/lib $rd_mnt/sshd/usr/
cd $rd_mnt/sshd
chmod 0755 ./bin/*
chmod 0755 ./usr/bin/*
chmod 0755 ./usr/sbin/*
chmod 0755 ./usr/local/bin/*
rsync --ignore-existing -auK . ../
sleep 2
cd $rd_mnt/
rm -rf ./sshd
# echo "[*_*] Removing unnecessary RestoreRamdisk files ..."
rm -rf ./usr/local/standalone/firmware/* ./usr/share/progressui/ ./usr/share/terminfo/ ./etc/apt/ ./etc/dpkg/
sleep 1
# echo "[*_*] Adding 'root:wheel' owner/group permissions to RestoreRamdisk ..."
chown -f -R root:wheel ./*
# echo "[*_*] Adding hacktivate ..."
# mkdir ./hacktivate
# cp -v $swd/../resources/data/mobileactivationd ./hacktivate/mobileactivationd
# echo "[*_*] Unmounting and resizing RestoreRamdisk ..."
cd $rd_staging
hdiutil detach -force $rd_mnt
sleep 5
rm -r $rd_mnt/
hdiutil resize -sectors min ./rd.dmg
sleep 3
# echo "[*_*] Signing and packing RestoreRamdisk into img4 ..."
img4 -i ./rd.dmg -o ./ramdisk.img4 -M IM4M -A -T rdsk
# echo "Extracting bootchain files from staging ..."
sleep 1
cd $swd/../resources
device_rdsk_path=rdsk/$device_id
mkdir -p $device_rdsk_path
mv -v $rd_staging/*.img4 ./$device_rdsk_path/
cd ./$device_rdsk_path
# echo "SSH RamDisk files are ready, packing patched files into a single tar file ..."
sleep 1

if [ -e ../$rev_device.tar.gz ];then
	rm ../$rev_device.tar.gz
fi

tar -czf ../$rev_device.tar.gz ./
cd ../
echo "Cleaning up ..."
sleep 4
rm -r ./$device_id/
clear
echo "DONE!"
sleep 2
# open .
exit
