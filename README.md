### TASMAN patch

This repository contains a script to patch TASMAN 1.28 (other versions
may also work)
to add two input keywords:

* `extparvar` accepts `y` (yes) and `n` (no) and tells TASMAN whether
  variations should be read from the file `parvars.inp` or generated
  by TASMAN. The specification `extparvar y` overrides any other
  TASMAN option determining how sampling should be performed.
* `getcalcscript` accepts the path to an executable (e.g., a bash script)
  This executable must accept an integer number as argument and 
  then populate the calculation directory with TALYS result files
  associated with the index given as argument.

## Applying the patch

Edit the variable `$tasman_path` in the script `modify_tasman.sh` so
that it points to the diretory containing the TASMAN source files.
Make sure that GNU awk (`gawk`) is available on the system.
Then run the script
```
./modify_tasman.sh
```
This will modify several source files and keep a backup of the original
files in a `backup` folder under the source folder.
Original files will only be modified if all source files concerned
were successfully patched.

After the patch has been applied, TASMAN needs to be rebuilt.

## Using modified TASMAN

This repository already contains a directory structure that may be used.
Precalculated TALYS calculations should go as tar archives into directory
`calcarchive`, see the README.md file in that directory for more information.
The directory `curcalc` contains exemplary input files for TASMAN.

Given that directory `calcarchive` contains the results in appropriate format,
TASMAN can be run with precalculated calculations in the following way:

```
cd curcalc
tasman < tasman.inp > tasman.out 
```

If you want to modify the input file `tasman.inp`, please keep the line
`mode 1` and make sure that `ntalys` is compatible with the number of
calculations available in directory `calcarchive`.
For instance, if `ntalys 2`, then files `calc.0001.tar` up to 
`calc.0003.tar` must be present. 
The number of files is always one larger than given by `ntalys` as the 
latter does not count the reference calculation.

  
