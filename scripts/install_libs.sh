#!/usr/bin/env bash
export PATH=/usr/local/bin:$PATH
swd=$(dirname $0)
cd $swd
mkdir libs
cd libs

if [ ! -e "/usr/local/bin/brew" ];then
    echo "+Installing Homebrew ..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    sleep 2
fi

brew install automake pkg-config git openssl
export LDFLAGS="-L$(brew --prefix openssl)/lib"
export CPPFLAGS="-I$(brew --prefix openssl)/include"
export PKG_CONFIG_PATH="$(brew --prefix openssl)/lib/pkgconfig"
brew uninstall --force --ignore-dependencies libusb libtool libxml2 libplist libusbmuxd libimobiledevice
brew install libusb libtool libxml2
brew install --HEAD libplist
brew link --overwrite libplist
brew install --HEAD libusbmuxd
brew link --overwrite libusbmuxd
sleep 2
#echo "+Installing libplist ..."
#git clone https://github.com/libimobiledevice/libplist.git
#cd libplist
#./autogen.sh --without-cython
#make
#sudo make install
#cd ..
echo "+Installing libimobiledevice-glue ..."
git clone https://github.com/libimobiledevice/libimobiledevice-glue.git
cd ./libimobiledevice-glue
./autogen.sh --without-cython
make
sudo make install
cd ..
sleep 2
brew install --HEAD libimobiledevice
brew link --overwrite libimobiledevice
sleep 2
# echo "+Installing libideviceactivation ..."
# git clone https://github.com/libimobiledevice/libideviceactivation.git
# cd ./libideviceactivation
# ./autogen.sh
# make
# sudo make install
# cd ..
# sleep 2
echo "+Installing libirecovery ..."
git clone https://github.com/libimobiledevice/libirecovery.git
cd ./libirecovery
./autogen.sh --without-cython
make
sudo make install
cd ..
sleep 2
echo "+Installing libidevicerestore ..."
git clone https://github.com/libimobiledevice/idevicerestore.git
cd ./idevicerestore
./autogen.sh
make
sudo make install
cd ..
sleep 2
cd ..
rm -rf ./libs
brew cleanup
cd $swd/../
echo "DONE." > ./.libs_installed
exit
#killall Terminal
