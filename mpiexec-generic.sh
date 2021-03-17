#!/bin/bash

t1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "out.$PSUBMIT_JOBID.0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "err.$PSUBMIT_JOBID.0"
else

	[ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"
	echo $- | grep -q x && omit_setx=true || set -x;
	mpirun $machinefile -np "$PSUBMIT_NP" "$TARGET_BIN" $ALL_ARGS >& out.$PSUBMIT_JOBID.0
	[ -z "$omit_setx" ] && set +x

    t2=$(date +"%s");
    [ "$(expr $t2 - $t1)" -lt "2" ] && sleep $(expr 2 - $t2 + $t1)

fi
