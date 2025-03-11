rm -f err.$PSUBMIT_JOBID.* out.$PSUBMIT_JOBID.*

time1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_NP%/$PSUBMIT_NP/g")

export PSUBMIT_RANK0="out.$PSUBMIT_JOBID.0"
export PSUBMIT_ERANK0="err.$PSUBMIT_JOBID.0"

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "$PSUBMIT_RANK0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "$PSUBMIT_ERANK0"
elif [ "$ALL_ARGS" == "--has-err" ]; then
    if [ ! -z "$(ls -1d err.$PSUBMIT_JOBID.* 2>/dev/null)" ]; then
        allnull=1; for i in err.$PSUBMIT_JOBID.*; do [ "$(cat $i | wc -l)" == "0" ] || allnull=0; done;
        [ "$allnull" == "1" ] || echo TRUE
    fi
else

    [ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

    [ -z "$ALL_ARGS" ] || export PSUBMIT_ARGS="$ALL_ARGS"

    # The line below is to cut off CUDA from the environment
    #LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`

    echo ">>> PSUBMIT: mpiexec is: " $(which mpiexec)
    export PSUBMIT_JOBID PSUBMIT_NP
    [ -z "$PSUBMIT_PREPROC" ] || source $PSUBMIT_PREPROC

    if [ "$TARGET_BIN" != "false" ]; then
        [ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"
        case $TARGET_BIN in
        /*)  executable=$TARGET_BIN;;
        ./*) executable="$TARGET_BIN";;
        *)   executable=$PSUBMIT_SUBDIR/$TARGET_BIN
             if [ ! -e $executable ]; then
                 executable=$(which $TARGET_BIN)
             fi
             ;;
        esac
        echo ">>> PSUBMIT: Executable is: " $executable
        if [ ! -z "$executable" -o ! -x "$executable" ]; then
            newexecname=$(mktemp)
            nds=$(echo $PSUBMIT_NODELIST | sed 's/,/ /g')
            for i in $nds; do 
                node=$(echo $i | cut -d: -f1); 
                scp "$executable" ${node}:$newexecname; 
                ssh ${node} "chmod +x $newexecname"; 
            done

            time2=$(date +"%s");
            export I_MPI_HYDRA_BOOTSTRAP="ssh"
            echo $- | grep -q x && omit_setx=true || set -x
            mpiexec.hydra $machinefile -np "$PSUBMIT_NP" -ppn "$PSUBMIT_PPN" --errfile-pattern=err.$PSUBMIT_JOBID.%r --outfile-pattern=out.$PSUBMIT_JOBID.%r "$newexecname" $ALL_ARGS
            { [ -z "$omit_setx" ] && set +x; } 2>/dev/null

            for i in $nds; do 
                node=$(echo $i | cut -d: -f1); 
                ssh $node "rm -f $newexecname"; 
            done

            time3=$(date +"%s");
            walltime="$(expr $time3 - $time2)"
            [ "$(expr $time3 - $time1)" -lt "2" ] && sleep $(expr 2 - $time3 + $time1)
            echo ">>> PSUBMIT: Walltime: $walltime"
        else
            echo ">>> PSUBMIT: ERROR: can't find or execute the program"
        fi   
    fi
    [ -z "$PSUBMIT_POSTPROC" ] || source $PSUBMIT_POSTPROC
fi
