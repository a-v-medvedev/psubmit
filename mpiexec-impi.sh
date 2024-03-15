rm -f err.$PSUBMIT_JOBID.* out.$PSUBMIT_JOBID.*

time1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_NP%/$PSUBMIT_NP/g")

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.$PSUBMIT_JOBID.0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "err.$PSUBMIT_JOBID.0"
else

    [ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

    # The line below is to cut off CUDA from the environment
    #LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`
    
    echo ">>> PSUBMIT: mpiexec.hydra is: " $(which mpiexec.hydra)
    echo ">>> PSUBMIT: Executable is: " $(which $TARGET_BIN)
#    echo ">>> PSUBMIT: ldd:"
#    ldd $(which $TARGET_BIN)

    [ -z "$PSUBMIT_TPN" ] && PSUBMIT_TPN=1
    export OMP_NUM_THREADS="$PSUBMIT_TPN"

    export PSUBMIT_JOBID PSUBMIT_NP
    [ -z "$PSUBMIT_PREPROC" ] || eval $PSUBMIT_PREPROC

    [ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"

    export I_MPI_HYDRA_BOOTSTRAP="ssh"

    time2=$(date +"%s")
    echo $- | grep -q x && omit_setx=true || set -x;
    mpiexec.hydra $machinefile -np "$PSUBMIT_NP" -ppn "$PSUBMIT_PPN" --errfile-pattern=err.$PSUBMIT_JOBID.%r --outfile-pattern=out.$PSUBMIT_JOBID.%r "$TARGET_BIN" $ALL_ARGS
    [ -z "$omit_setx" ] && set +x

    time3=$(date +"%s");
    walltime="$(expr $time3 - $time2)"
    [ "$(expr $time3 - $time1)" -lt "2" ] && sleep $(expr 2 - $time3 + $time1)
    echo ">>> PSUBMIT: Walltime: $walltime"

    [ -z "$PSUBMIT_POSTPROC" ] || eval $PSUBMIT_POSTPROC    
fi
