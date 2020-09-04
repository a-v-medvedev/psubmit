rm -f err.$PSUBMIT_JOBID.* out.$PSUBMIT_JOBID.*
#export I_MPI_FABRICS=ofi
#export I_MPI_OFI_PROVIDER=verbs
#export I_MPI_PIN_DOMAIN=core
time1=$(date +"%s")
ALL_ARGS=`eval echo '' $*`
ALL_ARGS=`echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g"`

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.$PSUBMIT_JOBID.0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "err.$PSUBMIT_JOBID.0"
else

[ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

# The line below is to cut off CUDA from the environment
#LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`
set -x
which mpiexec.hydra
#ldd "$TARGET_BIN"
[ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"
mpiexec.hydra $machinefile -np "$PSUBMIT_NP" -ppn "$PSUBMIT_PPN" --errfile-pattern=err.$PSUBMIT_JOBID.%r --outfile-pattern=out.$PSUBMIT_JOBID.%r "$TARGET_BIN" $ALL_ARGS
set +x
time2=$(date +"%s")
timediff=$(expr $time2 - $time1)
if [ "$timediff" -lt "2" ]; then
    sleep $(expr 2 - "$timediff")
fi

fi
