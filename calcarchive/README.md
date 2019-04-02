This directory can be populated with the
results of TALYS calculations stored in 
tar archives, which are then retrieved
by the script `get_talys_calc.sh` during
a TASMAN run.

The names of the files have to be in the 
form `calc.DDDD.tar` where `DDDD` is an
integer padded with leading zeros if 
required, e.g. 3 would be 0003. 
The smallest number has to be one, and
the file `calc.0001.tar` is expected to
contain the reference calculation, which is
used as the center for the calculation of 
uncertainties and covariance matrices.

If another convention of the filenames is
desired, the script `get_talys_calc.sh`
has to be changed accordingly.

Please also note that the result files
should not be hidden in a directory in 
the tar archive. To ensure this,
create tar archives like this:
```
cd <directory with TALYS result files>
tar -cf calc.0000.tar *
```
