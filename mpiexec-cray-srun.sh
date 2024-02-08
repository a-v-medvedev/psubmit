#!/bin/bash

#t1=$(date +"%s")

# FIXME we have to introduce this into the config file in some way
#NGPUS=8

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_NP%/$PSUBMIT_NP/g")

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.$PSUBMIT_JOBID.0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "err.$PSUBMIT_JOBID.0"
else
    [ -z "$NGPUS" ] && NGPUS=0
    [ "$NGPUS" == "0" ] || gpuopts="--cpu-bind=no --gpus-per-node=$NGPUS"
    [ -z "$PSUBMIT_TPN" ] && PSUBMIT_TPN=1
    export OMP_NUM_THREADS="$PSUBMIT_TPN"
    [ -z "$PSUBMIT_PREPROC" ] || eval $PSUBMIT_PREPROC
    if [ -f "hostfile.$PSUBMIT_JOBID" ]; then 
        [ -z "$SLURM_JOBID" ] && { echo "FATAL: mpiexec-cray-srun.sh: there is a hostfile, so the SLURM_JOBID must be set!"; exit 1; }
        sed -i 's/:.*//' "hostfile.$PSUBMIT_JOBID" 
        machinefile="-F hostfile.$PSUBMIT_JOBID"
        overlap="--overlap"
    fi

    echo $- | grep -q x && omit_setx=true || set -x;
    srun $overlap $machinefile $gpuopts --ntasks-per-node=$PSUBMIT_PPN --output=out.$PSUBMIT_JOBID.%t --error=err.$PSUBMIT_JOBID.%t --input=none "$TARGET_BIN" $ALL_ARGS >& out.$PSUBMIT_JOBID.master
    [ -z "$omit_setx" ] && set +x

    [ -z "$PSUBMIT_POSTPROC" ] || eval $PSUBMIT_POSTPROC
    
#    t2=$(date +"%s");
#    [ "$(expr $t2 - $t1)" -lt "2" ] && sleep $(expr 2 - $t2 + $t1)

fi
