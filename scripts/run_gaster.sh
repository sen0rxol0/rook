#!/usr/bin/env bash

cd $(dirname $0)
cd ../resources/exploit

if [ ! -d ./gaster ];then
	git clone https://github.com/0x7ff/gaster.git
	cd gaster
	rm -rf .git/
	make
	chmod +x gaster
	cd ..
fi

cd gaster

if [ -z "$1" ];then
echo "PWNING"
./gaster pwn
sleep 1
exec ./gaster reset
fi

exec ./gaster $@
