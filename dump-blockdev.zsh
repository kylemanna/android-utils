#!/bin/zsh
#
# Quick and dirty script to dump all partitions of an Android device via ADB (slow!)
# in an attempt to back it up before messing with custom ROMs or product development.
#
# Author: Kyle Manna <kyle@kylemanna.com>
#
# Use zsh as the >() process substitution is async on bash. Sigh.
#
# Example simple use case ("done" should occur last)
# $ echo hello | tee >/dev/null >(sleep 1; echo -n hi; cat -) >(cat -) ; echo done 
#
#

# Read all block devices in $blkdev array
IFS=$'\n\r' GLOBIGNORE='*' :; blkdevs=($(adb shell cat /proc/partitions | grep mmc | sed -e 's/^.*\(mmcblk[[:alnum:]]*\).*/\1/'))

#sha1sum_file=sha1sum.$(date +%s).txt
sha1sum_file=sha1sum.txt

#debugging
#blkdevs=("mmcblk0p2" "mmcblk0p3")

local cat
which pv >/dev/null 2>/dev/null && cat="pv" || cat="cat"

# Read initial data, generate initial sha1 hashes of raw images
for i in ${blkdevs[@]}; do
        local raw=$i.img
        local comp=$i.img.xz

        echo
        echo "Compressing $raw -> $comp"
        adb shell cat /dev/block/$i | tee \
            >(sha1sum | sed -e "s:-\$:$raw:" >> $sha1sum_file) \
            >(7z a dummy -txz -si -so 2>/dev/null > $comp) \
            | $cat > $raw
done

# Generate hashes of completed 7z files
for i in ${blkdevs[@]}; do
    local raw=$i.img
    local comp=$i.img.xz

    echo
    echo "Verifying $comp -> $raw"
    $cat $comp | tee \
        >(sha1sum | sed -e "s:-\$:$comp:" >> $sha1sum_file) \
        | 7z e -txz -si -so 2>/dev/null | sha1sum | sed -e "s:-\$:$comp.decomp:" >> $sha1sum_file
done
