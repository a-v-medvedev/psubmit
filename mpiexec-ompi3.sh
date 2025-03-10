dir=out.$PSUBMIT_JOBID
rm -rf "$dir"

time1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_NP%/$PSUBMIT_NP/g")


NUL="0"
[ "$PSUBMIT_NP" -gt 10 ] && NUL="00"
[ "$PSUBMIT_NP" -gt 100 ] && NUL="000"
[ "$PSUBMIT_NP" -gt 1000 ] && NUL="0000"
[ "$PSUBMIT_NP" -gt 10000 ] && NUL="00000"
export PSUBMIT_RANK0="$dir/1/rank.$NUL/stdout"
export PSUBMIT_ERANK0="$dir/1/rank.$NUL/stderr"

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "$PSUBMIT_RANK0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "$PSUBMIT_ERANK0"
elif [ "$ALL_ARGS" == "--has-err" ]; then
    if [ ! -z "$(ls -1d $dir/1/rank.*/stderr 2>/dev/null)" ]; then
        allnull=1; for i in $dir/1/rank.*/stderr; do [ "$(cat $i | wc -l)" == "0" ] || allnull=0; done;
        [ "$allnull" == "1" ] || echo TRUE
    fi
else

    [ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

    [ -z "$ALL_ARGS" ] || export PSUBMIT_ARGS="$ALL_ARGS"

    # The line below is to cut off CUDA from the environment
    #LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`

    export PSUBMIT_JOBID PSUBMIT_NP
    [ -z "$PSUBMIT_PREPROC" ] || eval $PSUBMIT_PREPROC

    if [ "$TARGET_BIN" != "false" ]; then
        [ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"
        echo ">>> PSUBMIT: mpirun is: " $(which mpirun)
        echo ">>> PSUBMIT: mpiexec is: " $(which mpiexec)
        executable=$PSUBMIT_SUBDIR/$TARGET_BIN
        if [ ! -e $executable ]; then
            executable=$(which $TARGET_BIN)
        fi
        echo ">>> PSUBMIT: Executable is: " $executable
        if [ ! -z "$executable" ]; then
            [ -z "$machinefile" ] || prefix="--prefix $(dirname $(dirname $(which mpirun)))"
            
            time2=$(date +"%s");

            echo $- | grep -q x && omit_setx=true || set -x
            mpirun $prefix $machinefile --bind-to core -np "$PSUBMIT_NP" --map-by ppr:$PSUBMIT_PPN:node -output-filename out.$PSUBMIT_JOBID "$executable" $ALL_ARGS
            { [ -z "$omit_setx" ] && set +x; } 2>/dev/null

            time3=$(date +"%s")
            walltime=$(expr $time3 - $time2)
            [ "$(expr $time3 - $time1)" -lt "2" ] && sleep $(expr 2 - $time3 '+' $time1)
            echo ">>> PSUBMIT: Walltime: $walltime"
        fi
    fi
    [ -z "$PSUBMIT_POSTPROC" ] || eval $PSUBMIT_POSTPROC
fi
