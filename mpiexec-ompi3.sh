rm -f err.$PSUBMIT_JOBID.* out.$PSUBMIT_JOBID.*
time1=$(date +"%s")
ALL_ARGS=`eval echo '' $*`
ALL_ARGS=`echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g"`
NUL="0"
[ "$PSUBMIT_NP" -gt 10 ] && NUL="00"
[ "$PSUBMIT_NP" -gt 100 ] && NUL="000"
[ "$PSUBMIT_NP" -gt 1000 ] && NUL="0000"
[ "$PSUBMIT_NP" -gt 10000 ] && NUL="00000"
if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.${PSUBMIT_JOBID}/1/rank.$NUL/stdout"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "out.${PSUBMIT_JOBID}/1/rank.$NUL/stdout"
else

[ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

# The line below is to cut off CUDA from the environment
#LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`
set -x
which mpirun
#ldd "$TARGET_BIN"
mpirun --bind-to core -np "$PSUBMIT_NP" --map-by ppr:$PSUBMIT_PPN:node -output-filename out.$PSUBMIT_JOBID "$TARGET_BIN" $ALL_ARGS
set +x
# ??? -merge-stderr-to-stdout
time2=$(date +"%s")
timediff=$(expr $time2 - $time1)
if [ "$timediff" -lt "2" ]; then
    sleep $(expr 2 - "$timediff")
fi
fi
