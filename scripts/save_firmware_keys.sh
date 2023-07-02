#!/usr/bin/env bash

cd $(dirname $0)/../resources/fk

devices="iPhone8,1 iPhone8,2 iPhone8,4 iPhone9,1 iPhone9,2 iPhone9,3 iPhone9,4 iPhone10,1 iPhone10,2 iPhone10,3 iPhone10,4 iPhone10,5 iPhone10,6"
#ios_ver="14.3"
buildid="AzulC_18C66_"

for device in $devices
do
echo $device
curl "https://www.theiphonewiki.com/wiki/$buildid($device)" --output /tmp/${device}_keys.html

if [ "$device" == "iPhone8,1" ];then
model1=n71ap
model2=n71map
fi

if [ "$device" == "iPhone8,2" ];then
model1=n66ap
model2=n66map
fi

if [ "$device" == "iPhone8,4" ];then
model1=n69ap
model2=n69uap
fi

if [ ! -z $model1 ];then

ibec_iv=$(cat /tmp/${device}_keys.html | grep "keypage-ibec-iv" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibec-iv\">" '{print $2}')
ibec_key=$(cat /tmp/${device}_keys.html | grep "keypage-ibec-key" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibec-key\">" '{print $2}')
ibss_iv=$(cat /tmp/${device}_keys.html | grep "keypage-ibss-iv" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibss-iv\">" '{print $2}')
ibss_key=$(cat /tmp/${device}_keys.html | grep "keypage-ibss-key" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibss-key\">" '{print $2}')
echo $ibec_iv > $buildid${device}_${model1}_ibec.iv
echo $ibec_key > $buildid${device}_${model1}_ibec.key
echo $ibss_iv > $buildid${device}_${model1}_ibss.iv
echo $ibss_key > $buildid${device}_${model1}_ibss.key

ibec_iv=$(cat /tmp/${device}_keys.html | grep "keypage-ibec2-iv" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibec2-iv\">" '{print $2}')
ibec_key=$(cat /tmp/${device}_keys.html | grep "keypage-ibec2-key" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibec2-key\">" '{print $2}')
ibss_iv=$(cat /tmp/${device}_keys.html | grep "keypage-ibss2-iv" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibss2-iv\">" '{print $2}')
ibss_key=$(cat /tmp/${device}_keys.html | grep "keypage-ibss2-key" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibss2-key\">" '{print $2}')
echo $ibec_iv > $buildid${device}_${model2}_ibec.iv
echo $ibec_key > $buildid${device}_${model2}_ibec.key
echo $ibss_iv > $buildid${device}_${model2}_ibss.iv
echo $ibss_key > $buildid${device}_${model2}_ibss.key

model1=""
model2=""

else

ibec_iv=$(cat /tmp/${device}_keys.html | grep "keypage-ibec-iv" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibec-iv\">" '{print $2}')
ibec_key=$(cat /tmp/${device}_keys.html | grep "keypage-ibec-key" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibec-key\">" '{print $2}')
ibss_iv=$(cat /tmp/${device}_keys.html | grep "keypage-ibss-iv" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibss-iv\">" '{print $2}')
ibss_key=$(cat /tmp/${device}_keys.html | grep "keypage-ibss-key" | awk -F "</code>" '{print $1}' | awk -F "keypage-ibss-key\">" '{print $2}')
echo $ibec_iv > $buildid${device}_ibec.iv
echo $ibec_key > $buildid${device}_ibec.key
echo $ibss_iv > $buildid${device}_ibss.iv
echo $ibss_key > $buildid${device}_ibss.key

fi
done

rm /tmp/iPhone*
