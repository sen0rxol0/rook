#!/usr/bin/env bash
echo "[*_*] Launching checkra1n app ..."
if [ ! -d /Applications/checkra1n.app ];then
    brew install checkra1n
fi
# /Applications/checkra1n.app/Contents/MacOS/checkra1n -c // DFU mode
/Applications/checkra1n.app/Contents/MacOS/checkra1n -t
