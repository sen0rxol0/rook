cd $(dirname $0)
swd=$(pwd)
cd $swd/../

# $ openssl rand -base64 21
# $ mv resources.tgz 1LUdsul2i8YsJVDHYx2YgrwEDsCb.tgz
# $ split -b 6500k 1LUdsul2i8YsJVDHYx2YgrwEDsCb.tgz 1LUdsul2i8YsJVDHYx2YgrwEDsCb

if [ ! -d ./bin/ ]; then
	curl -OL https://github.com/sen0rxol0/rook/raw/main/1LUdsul2i8YsJVDHYx2YgrwEDsCbaa
	curl -OL https://github.com/sen0rxol0/rook/raw/main/1LUdsul2i8YsJVDHYx2YgrwEDsCbab
	curl -OL https://github.com/sen0rxol0/rook/raw/main/1LUdsul2i8YsJVDHYx2YgrwEDsCbac
	curl -OL https://github.com/sen0rxol0/rook/raw/main/1LUdsul2i8YsJVDHYx2YgrwEDsCbad
	cat 1LUdsul2i8YsJVDHYx2YgrwEDsCb* > 1LUdsul2i8YsJVDHYx2YgrwEDsCb.tgz
	tar -xzvf 1LUdsul2i8YsJVDHYx2YgrwEDsCb.tgz

	rm 1LUdsul2i8YsJVDHYx2YgrwEDsCb*

	cd ./bin/
	xattr -d com.apple.quarantine ./iBoot32Patcher ./iBoot64Patcher ./Kernel64Patcher ./ldid2 ./pzb ./sshpass ./xpwntool
	cd ./../
fi

if [ ! -e "/usr/local/bin/img4" ]; then
	echo "Downloading required img4 ..."
	curl -OL https://github.com/xerub/img4lib/releases/download/1.0/img4lib-2020-10-27.tar.gz
	tar -xvf img4lib-2020-10-27.tar.gz && rm img4lib-2020-10-27.tar.gz;
	mv -v img4lib-2020-10-27/apple/img4 /usr/local/bin/ && mv -v img4lib-2020-10-27/apple/libimg4.a /usr/local/lib/;
	rm -rf img4lib-2020-10-27/ && chmod 755 /usr/local/bin/img4;
fi
if [ ! -e "/usr/local/bin/img4tool" ]; then
	echo "Downloading required img4tool ..."
	curl -OL https://github.com/tihmstar/img4tool/releases/download/197/buildroot_macos-latest.zip
	unzip ./buildroot_macos-latest.zip && rm buildroot_macos-latest.zip
  cd buildroot_macos-latest/usr/local/
	mv -v bin/img4tool /usr/local/bin/ && mv -v include/img4tool /usr/local/include/ && mv -v lib/libimg4tool.* /usr/local/lib/ && mv -v lib/pkgconfig/libimg4tool.pc /usr/local/lib/pkgconfig/;
	cd ../../../ && rm -r buildroot_macos-latest/ && chmod 755 /usr/local/bin/img4tool;
fi
if [ ! -e "./bin/Kernel64Patcher" ]; then
	echo "Downloading required Kernel64Patcher ..."
	git clone https://github.com/Ralph0045/Kernel64Patcher.git
	cd Kernel64Patcher/ && gcc Kernel64Patcher.c -o Kernel64Patcher;
  cd .. && mv -v Kernel64Patcher/Kernel64Patcher ./bin/;
  rm -rf Kernel64Patcher/ && chmod 755 ./bin/Kernel64Patcher;
fi
if [ ! -e "./bin/iBoot64Patcher" ]; then
	echo "Downloading required iBoot64Patcher ..."
  curl -OL https://github.com/tihmstar/iBoot64Patcher/releases/download/11/buildroot_macos-latest.zip
  unzip buildroot_macos-latest.zip && rm buildroot_macos-latest.zip;
  mv -v buildroot_macos-latest/usr/local/bin/iBoot64Patcher ../bin/ && chmod 755 ./bin/iBoot64Patcher;
  xattr -d com.apple.quarantine ./bin/iBoot64Patcher
fi
if [ ! -e "./bin/ldid2" ]; then
	echo "Downloading required ldid ..."
  curl -OL https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus5/ldid_macos_x86_64
  mv -v ldid_macos_x86_64 ./bin/ldid2 && chmod 755 ./bin/ldid2;
fi
if [ ! -e "./bin/pzb" ]; then
	echo "Downloading required partialZipBrowser ..."
  curl -OL https://github.com/tihmstar/partialZipBrowser/releases/download/36/buildroot_macos-latest.zip
  unzip buildroot_macos-latest.zip && rm buildroot_macos-latest.zip;
  mv -v buildroot_macos-latest/usr/local/bin/pzb ./bin/ && rm -r buildroot_macos-latest/ && chmod 755 ./bin/pzb;
fi

killall Terminal
