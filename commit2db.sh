#!/usr/local/bin/bash

MOUNTPOINT=/mnt/13/
RSYNCFROM=DC/REPORT/Export/Serchio/
RSYNCTO=/root/script/serchiolog/xpsbucket

#SAVEIFS=${IFS}
#IFS=;

# MONTA LA 13 SU RSYNCFROM

/root/script/monta13 ${MOUNTPOINT}

# RSYNC IN RYNCTO

if [ $? -eq 0 ]; then

	/bin/echo "==========> RSYNC 13 e DB 159"
	
	# BUTTA IN DB
	for item in  $(/usr/local/bin/rsync -r --exclude '* *' --ignore-existing --out-format "%n" ${MOUNTPOINT}${RSYNCFROM} ${RSYNCTO} |grep xps)
	do
		/bin/echo "----------> serchiolog: processing file $item"
		/root/script/serchiolog/serchiolog.pl ${RSYNCTO}/$item # get things done
	done

	/bin/echo "==========> Ok, ho fatto. Smonto e ciao."
	/sbin/umount ${MOUNTPOINT}

else
	/bin/echo "==========> FAIL at mount"

fi

#IFS=${SAVEIFS}
