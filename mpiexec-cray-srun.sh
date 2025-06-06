#!/bin/bash

#t1=$(date +"%s")

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

    [ -z "$NGPUS" ] && NGPUS=0
    [ "$NGPUS" == "0" ] || gpuopts="--cpu-bind=no --gpus-per-node=$NGPUS"
    [ -z "$PSUBMIT_NTH" ] && PSUBMIT_NTH=1
    export OMP_NUM_THREADS="$PSUBMIT_NTH"
    [ -z "$PSUBMIT_PREPROC" ] || source $PSUBMIT_PREPROC

    if [ "$TARGET_BIN" != "false" ]; then
        echo ">>> PSUBMIT: srun is: " $(which srun)
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
            if [ -f "hostfile.$PSUBMIT_JOBID" ]; then 
                [ -z "$SLURM_JOBID" ] && { echo "FATAL: mpiexec-cray-srun.sh: there is a hostfile, so the SLURM_JOBID must be set!"; exit 1; }
                sed -i 's/:.*//' "hostfile.$PSUBMIT_JOBID" 
                machinefile="-F hostfile.$PSUBMIT_JOBID"
                overlap="--overlap --jobid=$SLURM_JOBID"
            fi

            echo $- | grep -q x && omit_setx=true || set -x;
            srun $overlap $machinefile $gpuopts --ntasks-per-node=$PSUBMIT_PPN --output=out.$PSUBMIT_JOBID.%t --error=err.$PSUBMIT_JOBID.%t --input=none "$executable" $ALL_ARGS >& out.$PSUBMIT_JOBID.master
            { [ -z "$omit_setx" ] && set +x; } 2>/dev/null
        else
            echo ">>> PSUBMIT: ERROR: can't find or execute the program"
        fi
    fi

    [ -z "$PSUBMIT_POSTPROC" ] || source $PSUBMIT_POSTPROC
    
#    t2=$(date +"%s");
#    [ "$(expr $t2 - $t1)" -lt "2" ] && sleep $(expr 2 - $t2 + $t1)

fi
