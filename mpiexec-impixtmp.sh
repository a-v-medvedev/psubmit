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

    echo ">>> PSUBMIT: mpiexec is: " $(which mpiexec)
    echo ">>> PSUBMIT: Executable is: " $(which $TARGET_BIN)
#    echo ">>> PSUBMIT: ldd:"
#    ldd $(which $TARGET_BIN)

    [ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"

	[ ! -f $TARGET_BIN ] && TARGET_BIN=$(which $TARGET_BIN)

	newexecname=$(mktemp)
	nds=$(echo $PSUBMIT_NODELIST | sed 's/,/ /g')
	for i in $nds; do 
		node=$(echo $i | cut -d: -f1); 
		scp "$TARGET_BIN" ${node}:$newexecname; 
		ssh ${node} "chmod +x $newexecname"; 
	done

    time2=$(date +"%s");
    export I_MPI_HYDRA_BOOTSTRAP="ssh"
    echo $- | grep -q x && omit_setx=true || set -x
	mpiexec.hydra $machinefile -np "$PSUBMIT_NP" -ppn "$PSUBMIT_PPN" --errfile-pattern=err.$PSUBMIT_JOBID.%r --outfile-pattern=out.$PSUBMIT_JOBID.%r "$newexecname" $ALL_ARGS
    [ -z "$omit_setx" ] && set +x

	for i in $nds; do 
		node=$(echo $i | cut -d: -f1); 
		ssh $node "rm -f $newexecname"; 
	done

    time3=$(date +"%s");
    walltime="$(expr $time3 - $time2)"
    [ "$(expr $time3 - $time1)" -lt "2" ] && sleep $(expr 2 - $time3 + $time1)
    echo ">>> PSUBMIT: Walltime: $walltime"
fi
