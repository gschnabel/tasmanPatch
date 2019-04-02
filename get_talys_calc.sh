#!/bin/sh

# This scripts takes an integer number as argument
# and picks the tar archive with the filanem 'calc.DDDD.tar'
# in the directory specified in 'srcdir'
# (where DDDD is the integer padded with leading zeros)
# and extracts its content in the directory 'dstdir' 

# If used to feed precalculated TALYS results to TASMAN
# the smallest numbers should be 1, i.e. file 'calc.0001.tar'
# must exist. Furthermore, result files in the tar archive
# should NOT be stored in a subdirectory in the archive.
# The name of the input file in the archive must be
# 'talys.inp'

srcdir="../calcarchive"
dstdir="."

calcnr=$(echo $1 | sed "s/^0*//")
numstr=$(printf "%04d" "$calcnr")
tarfile="calc.${numstr}.tar"
echo "Using results in $tarfile ..." >> /dev/stdout
tar xf "${srcdir}/${tarfile}" -C "${dstdir}" 
