dir=out.$PSUBMIT_JOBID
rm -rf "$dir"

time1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")

NUL="0"
[ "$PSUBMIT_NP" -gt 10 ] && NUL="00"
[ "$PSUBMIT_NP" -gt 100 ] && NUL="000"
[ "$PSUBMIT_NP" -gt 1000 ] && NUL="0000"
[ "$PSUBMIT_NP" -gt 10000 ] && NUL="00000"

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.${PSUBMIT_JOBID}.1.$NUL"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "err.${PSUBMIT_JOBID}.1.$NUL"
else

    [ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

    # The line below is to cut off CUDA from the environment
    #LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`

    echo ">>> PSUBMIT: mpirun is: " $(which mpirun)
    echo ">>> PSUBMIT: exetable is: " $(which $TARGET_BIN)
    echo ">>> PSUBMIT: ldd:"
    ldd $(which $TARGET_BIN)
    
    echo $- | grep -q x && omit_setx=true || set -x
    mpirun --bind-to core -np "$PSUBMIT_NP" --map-by ppr:$PSUBMIT_PPN:node -output-filename out.$PSUBMIT_JOBID "$TARGET_BIN" $ALL_ARGS
    [ -z "$omit_setx" ] && set +x

    time2=$(date +"%s");
    [ "$(expr $time2 - $time1)" -lt "2" ] && sleep $(expr 2 - $t2 + $t1)

fi
