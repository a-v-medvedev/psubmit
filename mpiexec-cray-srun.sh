#!/bin/bash

#t1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_NP%/$PSUBMIT_NP/g")

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.$PSUBMIT_JOBID.0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "err.$PSUBMIT_JOBID.0"
else
    #[ -z "$PSUBMIT_TPN" ] && PSUBMIT_TPN=1
    [ -z "$PSUBMIT_PREPROC" ] || eval $PSUBMIT_PREPROC
    [ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"
    echo $- | grep -q x && omit_setx=true || set -x;
    #OMP_NUM_THREADS="$PSUBMIT_TPN"
    srun --cpu-bind=no --gpus-per-node=8 --ntasks-per-node=$PSUBMIT_PPN --output=out.%j.%t --error=err.%j.%t --input=none "$TARGET_BIN" $ALL_ARGS >& out.$PSUBMIT_JOBID.master
    [ -z "$omit_setx" ] && set +x

    [ -z "$PSUBMIT_POSTPROC" ] || eval $PSUBMIT_POSTPROC
    
#    t2=$(date +"%s");
#    [ "$(expr $t2 - $t1)" -lt "2" ] && sleep $(expr 2 - $t2 + $t1)

fi
