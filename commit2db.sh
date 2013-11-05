#!/usr/bin/env bash

RSYNCFROM=/root/xpscache/
RSYNCTO=/root/script/serchiolog/xpsbucket


for i in  $(/usr/local/bin/rsync -r --ignore-existing --out-format '%n' ${RSYNCFROM} ${RSYNCTO} |grep xps)
do
	/bin/echo "serchiolog: processing file $i"
	/bin/echo /root/script/serchiolog/serchiolog.pl ${RSYNCTO}/$i # get things done
done
