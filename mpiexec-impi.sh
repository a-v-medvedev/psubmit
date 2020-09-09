rm -f err.$PSUBMIT_JOBID.* out.$PSUBMIT_JOBID.*

t1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.$PSUBMIT_JOBID.0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "err.$PSUBMIT_JOBID.0"
else

    [ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

    # The line below is to cut off CUDA from the environment
    #LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`
    
    echo ">>> PSUBMIT: mpiexec is: " $(which mpiexec)
    echo ">>> PSUBMIT: exetable is: " $(which $TARGET_BIN)
#    echo ">>> PSUBMIT: ldd:"
#    ldd $(which $TARGET_BIN)
    
    [ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"

    echo $- | grep -q x && omit_setx=true || set -x;
    mpiexec.hydra $machinefile -np "$PSUBMIT_NP" -ppn "$PSUBMIT_PPN" --errfile-pattern=err.$PSUBMIT_JOBID.%r --outfile-pattern=out.$PSUBMIT_JOBID.%r "$TARGET_BIN" $ALL_ARGS
    [ -z "$omit_setx" ] && set +x

    t2=$(date +"%s");
    [ "$(expr $t2 - $t1)" -lt "2" ] && sleep $(expr 2 - $t2 + $t1)

fi
