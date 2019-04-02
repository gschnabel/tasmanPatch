#!/usr/bin/sh 

##################################################
#       
#           CONFIGURATION
#
##################################################

tasman_path='tasman/source'
backup_path="$tasman_path/backup"

 patch_message='c +--------------------------------------------------\n'
patch_message+='c |   patched by Georg Schnabel                      \n'
patch_message+='c |   to enable reading parameter variations from    \n'
patch_message+='c |   a file and using precalculated TALYS results   \n'
patch_message+='c +--------------------------------------------------\n'

local_patch_startmsg='c start of patch by Georg Schnabel\n'
local_patch_endmsg='\nc end of patch by Georg Schnabel\n'

##################################################
#
#           PROGRAM
#
##################################################

# sanity checks

if [ ! -d "$tasman_path" ]; then
    echo "ERROR: specified path to TASMAN source does not exist" >> "/dev/stderr"
    exit 1
fi

if [ -d "$backup_path" ]; then
    echo "ERROR: backup folder already exists. Has the patch already been applied?" >> "/dev/stderr"
    exit 1
fi

if [ ! -f "$tasman_path/checkkeyword.f" ]; then
    echo "ERROR: source file checkkeyword.f missing" >> "/dev/stderr"
    exit 1
elif [ ! -f "$tasman_path/convert.f" ]; then
    echo "ERROR: source file convert.f missing" >> "/dev/stderr"
    exit 1
elif [ ! -f "$tasman_path/input2.f" ]; then
    echo "ERROR: source file input2.f missing" >> "/dev/stderr"
    exit 1
elif [ ! -f "$tasman_path/parvariation.f" ]; then
    echo "ERROR: source file parvariation.f missing" >> "/dev/stderr"
    exit 1
elif [ ! -f "$tasman_path/tasman.cmb" ]; then
    echo "ERROR: source file tasman.cmb missing" >> "/dev/stderr"
    exit 1
elif [ ! -f "$tasman_path/tasmaninitial.f" ]; then
    echo "ERROR: source file tasmaninitial missing" >> "/dev/stderr"
    exit 1
elif [ ! -f "$tasman_path/uncertainty.f" ]; then
    echo "ERROR source file uncertainty.f missing" >> "/dev/stderr"
    exit 1
fi

mkdir "$tasman_path/backup"
if [ $? -ne 0 ]; then
    echo "ERROR: cannot create backup directory" >> "/dev/stderr"
    exit 1
fi

cp "$tasman_path/checkkeyword.f" "$tasman_path/convert.f" \
   "$tasman_path/input2.f"       "$tasman_path/parvariation.f" \
   "$tasman_path/tasman.cmb"     "$tasman_path/tasmaninitial.f" \
   "$tasman_path/uncertainty.f"  "$backup_path"

if [ $? -ne 0 ]; then
    "ERROR: source files subject to modification could not be backed up" >> "/dev/stderr"
    exit 1
fi

# keep track of failed file patching 
anyfailed=0

##################################################
# modify: checkkeyword.f
# 
# description:
#   add two new keywords #extparvar
#   and #getcalcscript to the data array 
#   and adjust the variable numkey accordingly
##################################################

curfile="checkkeyword.f"
curpath="$tasman_path/$curfile"
printf "patching $curfile ... "
cat "$curpath" | gawk '
BEGIN{
    regex_numkey = "(^ *parameter *\\(numkey *= *)([0-9]+)(\\).*)$" 
    regex_datakey = "^ *data *\\( *keyword *\\( *i *\\) *, *i *= *1 *, *numkey *\\) */"
    patched_numkey = 0
    patched_datakey = 0
    print "'"$patch_message"'"
}
$0 ~ regex_numkey && !patched_numkey {
    num = gensub(regex_numkey, "\\2", "g", $0)
    num += 2
    newstr = gensub(regex_numkey, "\\1" num "\\3", "g", $0)
    printf "%s", "'"$local_patch_startmsg"'"
    printf "%s",  newstr
    printf "%s", "'"$local_patch_endmsg"'"
    patched_numkey = 1
    next
}
$0 ~ regex_datakey && patched_numkey && !patched_datakey {
    printf "%s", "'"$local_patch_startmsg"'"
    print
    while (1) {
        if (getline <= 0) {
            print("unexpected EOF") > "/dev/stderr"
            exit
        }
        isnonempty = index($0, ",")
        found = index($0, "/")
        if (found) { break }
        print
    }
    replstr = ", '"'"'#extparvar'"'"', '"'"'#getcalcscript'"'"' /"
    newstr = gensub(/ *\//, replstr, "g", $0) 
    printf "%s", newstr
    printf "%s", "'"$local_patch_endmsg"'"
    patched_datakey = 1
    next
}
{
    print
}
END{
    if (!patched_numkey || !patched_datakey) {
        print("Unable to patch file '$curfile'") > "/dev/stderr"
        exit 1
    }
}
' > "$backup_path/${curfile}.new"

if [ $? -eq 0 ]; then
    printf "successful\n"
else
    printf "failed\n"
    anyfailed=1
fi

##################################################
# modify: convert.f
#
# description:
#   adding a character variable 'origstr'
#   which is the not lower-cased version of 
#   variable 'str'
#   add reading in the value associated with the
#   input keyword #getcalcscript in the loop
##################################################

curfile="convert.f"
curpath="$tasman_path/$curfile"
printf "patching $curfile ... "
cat "$curpath" | gawk '
BEGIN{
    regex_str = "(^ *character\\*80 *)(str *$)"
    regex_str2 =  "(^ *)str( *\\([^)]+\\) *= *inline *\\([^)]+\\).*$)"
    regex_loop = "^ *do *([0-9]+) *[a-z]+ *= *[0-9]+ *, *[0-9]+ *$"
    patched_str = 0
    patched_str2 = 0
    patched_loop = 0
    print "'"$patch_message"'"
}
$0 ~ regex_str && !patched_str {
    newstr = gensub(regex_str, "\\1origstr, \\2", "g", $0)    
    printf "%s", "'"$local_patch_startmsg"'"
    printf "%s", newstr
    printf "%s", "'"$local_patch_endmsg"'"
    patched_str = 1
    next
}
$0 ~ regex_str2 && patched_str && !patched_str2 {
    tmpstr = $0
    newstr = gensub(regex_str2, "\\1origstr\\2", "g", $0)
    printf "%s", "'"$local_patch_startmsg"'"
    printf "%s", newstr
    printf "%s", "'"$local_patch_endmsg"'"
    print tmpstr
    patched_str2 = 1
    next
}
$0 ~ regex_loop && patched_str && patched_str2 && !patched_loop {
    loopnum = gensub(regex_loop, "\\1", "g", $0)
    regex_endloop = "^ *" loopnum " *continue *$"
    regex_ifexpr = "(^ *)if.*inline.*\\.eq\\..*#[a-z].*then"
    while ($0 !~ regex_ifexpr) { 
        print
        if ($0 ~ regex_endloop) { next }
        if (getline <= 0) {
            print("Unexpected EOF") > "/dev/stderr"
            exit 1
        }
    }
    tmpstr = $0
    spacer = gensub(regex_ifexpr, "\\1", "g", tmpstr)
    printf "%s", "'"$local_patch_startmsg"'"
    print spacer "if (inline(i)(k+1:k+14).eq.'"'"'#getcalcscript'"'"') then" 
    print spacer "  inline(i)(k+10:80)=origstr(k+10:80)"
    print spacer "  return"
    printf "%s", spacer "endif"
    printf "%s", "'"$local_patch_endmsg"'"
    print tmpstr
    patched_loop = 1
    next
}
{ 
    print
}
END{
    if (!patched_str || !patched_str2 || !patched_loop) {
        print("Unable to patch file '$curfile'") > "/dev/stderr"
        exit 1
    }
}
' > "$backup_path/${curfile}.new"

if [ $? -eq 0 ]; then
    printf "successful\n"
else
    printf "failed\n"
    anyfailed=1
fi

##################################################
# modify: input2.f
#
# description:
#   addingg two if-blocks with checks for 
#   the keywords #extparvar and #getcalcscript
#   and reading in the associated values
##################################################

curfile="input2.f"
curpath="$tasman_path/$curfile"
printf "patching $curfile ... "
cat "$curpath" | gawk '
BEGIN{
    regex_keycheck = "(^ *)if *\\( *key *\\.eq\\. *.#[a-z][^)]+\\) *then *$"
    patched_keycheck = 0
    print "'"$patch_message"'"
}
$0 ~ regex_keycheck && !patched_keycheck {
    tmpstr = $0 
    spacer = gensub(regex_keycheck, "\\1", "g", tmpstr)
    printf "%s", "'"$local_patch_startmsg"'"
    print spacer "if (key.eq.'"'"'#extparvar'"'"') then"
    print spacer "  if (ch.eq.'"'"'n'"'"') flagextparvar=.false."
    print spacer "  if (ch.eq.'"'"'y'"'"') flagextparvar=.true."
    print spacer "  if (ch.ne.'"'"'y'"'"'.and.ch.ne.'"'"'n'"'"') goto 900"
    print spacer "  goto 10"
    print spacer "endif"
    print spacer "if (key.eq.'"'"'#getcalcscript'"'"') then"
    print spacer "  read(value,'"'"'(a160)'"'"') getcalcscript"
    print spacer "  goto 10"
    printf "%s", spacer "endif"
    printf "%s", "'"$local_patch_endmsg"'"
    print tmpstr
    patched_keycheck = 1
    next
}
{
    print
}
END{
    if (!patched_keycheck) {
        print("Unable to patch file '$curfile'") > "/dev/stderr"
        exit 1
    }
}
' > "$backup_path/${curfile}.new"

if [ $? -eq 0 ]; then
    printf "successful\n"
else
    printf "failed\n"
    anyfailed=1
fi

##################################################
# modify: parvariation.f
#
# description:
#   add definition of array 'extpar'
#   add reading external parameter variations
#   add overriding sampled parameter values of
#   TASMAN by values from file 'parvars.inp"
##################################################

curfile="parvariation.f"
curpath="$tasman_path/$curfile"
printf "patching $curfile ... "
cat "$curpath" | gawk '
BEGIN{
    regex_extpardef = "(^ *)include *\"tasman.cmb\" *$"
    regex_loopstart = "(^ *)isamp *= *1 *$"
    regex_gotonum = "(^ *150 *)(partalys *\\(.*$)"
    patched_extpardef = 0
    patched_loopstart = 0
    patched_gotonum = 0
    print "'"$patch_message"'"
}
$0 ~ regex_extpardef && !patched_extpardef {
    print
    spacer = gensub(regex_extpardef, "\\1", "g", $0)
    printf "%s", "'"$local_patch_startmsg"'"
    print  spacer "real   extpar(Npar)" 
    printf "%s", spacer "integer k"
    printf "%s", "'"$local_patch_endmsg"'"
    patched_extpardef = 1 
    next
}
$0 ~ regex_loopstart && patched_extpardef && !patched_loopstart {
    tmpary[0] = $0 
    cnt = 0
    while (1) {
        if (getline <= 0) {
            print("Unexpected EOF") > "/dev/stderr"
            exit 1
        }
        cnt++
        tmpary[cnt] = $0
        if (match($0, /^[^c] *[^ ]/) > 0) { break }    
    }
    if (match(tmpary[cnt], /^ *do *120 *i *= *1 *, *Npar *$/) > 0) {
        spacer = gensub(/(^ *).*$/, "\\1", "g", $0)
        printf "%s", "'"$local_patch_startmsg"'"
        printf "%s", spacer "if (flagextparvar) read(80,*) (extpar(k),k=1,Npar)"
        printf "%s", "'"$local_patch_endmsg"'"
        patched_loopstart = 1
    } 
    for (i=0; i<=cnt; i++) { print tmpary[i] }
    delete tmpary
    next
}
$0 ~ regex_gotonum && patched_extpardef && patched_loopstart && !patched_gotonum {
    tmpstr = $0
    spacergoto = gensub(regex_gotonum, "\\1", "g", $0)
    spacer = gensub(".", " ", "g", spacergoto)
    printf "%s", "'"$local_patch_startmsg"'"
    print spacergoto "if (flagextparvar) then"
    print spacer "  par(i)=extpar(i)"
    printf "%s", spacer "endif"
    printf "%s", "'"$local_patch_endmsg"'" 
    print spacer gensub(regex_gotonum, "\\2", "g", tmpstr)
   patched_gotonum = 1
   next
}
{
    print
}
END{
    if (!patched_extpardef || !patched_loopstart || !patched_gotonum) {
        print("Unable to patch file '$curfile'") > "/dev/stderr"
        exit 1
    }
}
' > "$backup_path/${curfile}.new"

if [ $? -eq 0 ]; then
    printf "successful\n"
else
    printf "failed\n"
    anyfailed=1
fi

##################################################
# modify: tasman.cmb
#
# description:
#   adding a named common block /extParCom/
#   that contains variables flagextparvar
#   and getcalcscript
##################################################

curfile="tasman.cmb"
curpath="$tasman_path/$curfile"
printf "patching $curfile ... "
cat "$curpath" | gawk '
BEGIN{
    regex_submachine = "^c *\\*+ *subroutine *machine *.*$"
    patched = 0
    comcnt = 0
    print "'"$patch_message"'"
}
$0 ~ regex_submachine {
    printf "%s", "'"$local_patch_startmsg"'"
    print "c"
    print "c *********************** External parameter variations ****************"
    print "c"
    print "        common /extParCom/ flagextparvar,getcalcscript"
    print "        logical flagextparvar"
    printf "%s",  "        character*160 getcalcscript"
    printf "%s", "'"$local_patch_endmsg"'" 

    for (i=1; i<=comcnt; i++) {
        print comblock[i]
    }
    print $0
    patched = 1
    comcnt = 0  
    next
}

/^c/ {
    comcnt++ 
    comblock[comcnt] = $0
    next
}
/^[^c]/ {
    for (i=1; i<=comcnt; i++) {
        print comblock[i]
    }
    comcnt = 0
    print
}
END{
    if (!patched) {
        print("Unable to patch file '$curfile'") > "/dev/stderr"
        exit 1
    }
}
' > "$backup_path/${curfile}.new"

if [ $? -eq 0 ]; then
    printf "successful\n"
else
    printf "failed\n"
    anyfailed=1
fi

##################################################
# modify: tasmaninitial.f
#
# description:
#   adding default initialization for variables
#   'flagextparvar' and 'getcalcscript'
##################################################

curfile="tasmaninitial.f"
curpath="$tasman_path/$curfile"
printf "patching $curfile ... "
cat "$curpath" | gawk '
BEGIN{
    regex_init = "^c *\\*+ Initialization *.*$"
    patched_init = 0
    print "'"$patch_message"'"
}
$0 ~ regex_init {
    while ($0 ~ /^c/) {
        print
        getline
    }
    spacer = gensub(/(^ *).*$/, "\\1", "g", $0)
    printf "%s", "'"$local_patch_startmsg"'"
    print spacer "flagextparvar=.false."
    printf "%s", spacer "getcalcscript='"'""none""'"'"
    printf "%s", "'"$local_patch_endmsg"'" 
    print $0
    patched_init = 1
    next 
}
{
    print
}
END{
    if (!patched_init) {
        print("Unable to patch file '$curfile'") > "/dev/stderr"
        exit 1
    }
}
' > "$backup_path/${curfile}.new"

if [ $? -eq 0 ]; then
    printf "successful\n"
else
    printf "failed\n"
    anyfailed=1
fi

##################################################
# modify: uncertainty.f
#
# description:
#   adding definition of variable 'calcnumstr'
#   adding line to open file 'parvars.inp'
#   modifying loop that calls talys to 
#   call getcalcscript to retrieve calculations
#   instead of running talys
#   close file 'parvars.inp' at the end
##################################################

curfile="uncertainty.f"
curpath="$tasman_path/$curfile"
printf "patching $curfile ... "
cat "$curpath" | gawk '
BEGIN {
    regex_definevars = "^ *include *.tasman.cmb. *$"
    regex_openfile = "^ *do *10 *italys *= *Ntalbeg *, *Ntalys *$" 
    regex_extendloop[1] = "^ *talcmd *= *talys.*$" 
    regex_extendloop[2] = "^ *i *= *system *\\( *talcmd *\\) *$"
    regex_closefile = "^ *10 *continue *$"
    patched_definevars = 0
    patched_openfile = 0
    patched_extendloop = 0
    patched_closefile = 0
    print "'"$patch_message"'"
}
$0 ~ regex_definevars {
    print
    spacer = gensub(/(^ *).*$/, "\\1", "g", $0)
    printf "%s", "'"$local_patch_startmsg"'"
    printf "%s", spacer "character*80 calcnumstr" 
    printf "%s", "'"$local_patch_endmsg"'" 
    patched_definevars = 1
    next
}
$0 ~ regex_openfile && patched_definevars {
    spacer = gensub(/(^ *).*$/, "\\1", "g", $0)
    printf "%s", "'"$local_patch_startmsg"'"
    printf "%s", spacer "if (flagextparvar) open(unit=80,file=\"parvars.inp\",status='"'""old""'"')"
    printf "%s", "'"$local_patch_endmsg"'" 
    print $0
    patched_openfile = 1
    next
}
$0 ~ regex_extendloop[1] {
    spacer = gensub(/(^ *).*$/, "\\1", "g", $0)
    tmpstr1 = $0
    getline
    tmpstr2 = $0
    if ($0 ~ regex_extendloop[2]) {
        printf "%s", "'"$local_patch_startmsg"'"
        print spacer "write(calcnumstr,\"(I4.4)\") italys+1"
        print spacer "if (trim(getcalcscript).ne.'"'""none""'"') then"
        print spacer "  talcmd=trim(getcalcscript)//'"'"' '"'"'//trim(calcnumstr)"
        print spacer "  write(*,*) talcmd"
        print spacer "  i=system(talcmd)"
        print spacer "else"
        print spacer "  talcmd=talys//'"'"" < talys.inp > talys.out""'"'"
        print spacer "  i=system(talcmd)"
        printf "%s", spacer "endif"
        printf "%s", "'"$local_patch_endmsg"'" 
        patched_extendloop = 1
        next
    } else {
      print tmpstr1
      print tmpstr2
    }
    next
}
$0 ~ regex_closefile {
    print
    spacer = gensub(/(^ *[0-9]+ *).*$/, "\\1", "g", $0)
    spacer = gensub(/./, " ", "g", spacer)
    printf "%s", "'"$local_patch_startmsg"'"
    printf "%s", spacer "if (flagextparvar) close(unit=80)" 
    printf "%s", "'"$local_patch_endmsg"'" 
    patched_closefile = 1
    next
}
{
    print
}
END{
    if (!patched_definevars || !patched_openfile || !patched_extendloop || !patched_closefile) {
        print("Unable to patch file '$curfile'") > "/dev/stderr"
        exit 1
    }
}
' > "$backup_path/${curfile}.new"

if [ $? -eq 0 ]; then
    printf "successful\n"
else
    printf "failed\n"
    anyfailed=1
fi

##################################################
#
#       FINALIZATION ACTION
#
##################################################

if [ $anyfailed -eq 0 ]; then 
    curfile="checkkeyword.f" && \
    cp "$backup_path/${curfile}.new" "$tasman_path/${curfile}" && \
    curfile="convert.f" && \
    cp "$backup_path/${curfile}.new" "$tasman_path/${curfile}" && \
    curfile="input2.f" && \
    cp "$backup_path/${curfile}.new" "$tasman_path/${curfile}" && \
    curfile="parvariation.f" && \
    cp "$backup_path/${curfile}.new" "$tasman_path/${curfile}" && \
    curfile="tasman.cmb" && \
    cp "$backup_path/${curfile}.new" "$tasman_path/${curfile}" && \
    curfile="tasmaninitial.f" && \
    cp "$backup_path/${curfile}.new" "$tasman_path/${curfile}" && \
    curfile="uncertainty.f" && \
    cp "$backup_path/${curfile}.new" "$tasman_path/${curfile}" 

    if [ $? -ne 0 ]; then
        echo "ERROR: something went wrong during copying the patched files" >> "/dev/stderr"
        echo "       into the TASMAN source directory." >> "/dev/stderr"
        echo "       Original files are restored." >> "/dev/stderr"
        cp "$backup_path"/*.f "$backup_path/tasman.cmb" "$tasman_path"
        rm -rf "$backup_path"
        exit 1
    else
        echo "All files patched successfully!"
    fi
else
    echo "ERROR: some source files could not be patched" >> "/dev/stderr"
    rm -rf "$backup_path"
    exit 1
fi
