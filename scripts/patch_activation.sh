#!/usr/bin/env bash

# echo $(dirname $0)
cd $(dirname $0)

cd ./../bin/

if [ ! -e ./sshpass ];then
	echo "[Exiting] sshpass is required!"
	exit
fi

_sshpass()
{
	if [ "$1" == "ssh" ]
	then
		./sshpass -p "alpine" ssh -p2222 -o StrictHostKeyChecking=no root@localhost $2
	fi

	if [ "$1" == "scp" ]
	then
		./sshpass -p "alpine" scp -P2222 $2 $3
	fi
}

echo "HACKTIVATING"
_sshpass ssh "/bin/bash -c 'exec /usr/local/bin/mountfs'"

# _sshpass scp root@localhost:/mnt1/var/mobile/Library/Preferences/com.purplebuddy.plist ./

_sshpass ssh "/bin/bash -c 'mv /mnt1/usr/libexec/mobileactivationd /mnt1/usr/libexec/mobileactivationd_'"
_sshpass scp ../resources/data/mobileactivationd root@localhost:/mnt1/usr/libexec/mobileactivationd
_sshpass ssh "/bin/bash -c 'chmod 755 /mnt1/usr/libexec/mobileactivationd && chown 0:0 /mnt1/usr/libexec/mobileactivationd'"
_sshpass ssh "/bin/bash -c 'snapshot_name=\$(snappy -f /mnt1 -l | tail -n 1); snappy -f /mnt1 -r \$snapshot_name -t orig-fs; echo \$snapshot_name > /mnt1/.snapshot'"
_sshpass ssh "/sbin/reboot"

# snappy -f /mnt1 -d com.apple.os.update-142BD6DB73D61D4AE931F77DADD10C2F63C9118898BDD486DB66C2AF1C82BA30B9EAF5D9560AC6BDB731A6F1141485BA
# snappy -f /mnt1 -c orig-fs
# snappy -f /mnt1 -r orig-fs -x
