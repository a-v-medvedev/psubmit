#!/bin/bash

. $PSUBMIT_DIRNAME/psub_common.sh

vbbs_id=0
outfile=""

function psub_check_job_status() {
    if [ "$jobstatus" == "E" ]; then jobstatus="DONE"; return; fi
    if [ "$jobstatus" == "DONE" ]; then return; fi
    if [ "$jobstatus" == "Q" ]; then
        NBGJOBS=$(jobs -rp | wc -l)
        if [ "$NBGJOBS" -eq "0" ]; then 
            jobstatus="R"

            # make up a node list
            cat $outfile | grep 'node:' | awk -vppn=$PPN '{print $2 ":" ppn }' > hostfile.$jobid
            for n in $(cat hostfile.$jobid); do
                PSUBMIT_NODELIST=$PSUBMIT_NODELIST,${n}:$PPN
            done
            export PSUBMIT_NODELIST=`echo $PSUBMIT_NODELIST | sed 's/^,//'`

            # ssh and start run-mpi script
            headnode=$(head -n1 hostfile.$jobid | cut -d: -f1)
            NP=$(expr "$NNODES" \* "$PPN")
            cat $outfile > $FILE_OUT

            # Start a background ssh session
            ssh $headnode export PATH=$PATH \&\& export LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \&\& export PSUBMIT_NODELIST="$PSUBMIT_NODELIST" \&\& cd "$PWD" \&\& timeout -k20 ${TIME_LIMIT}m $PSUBMIT_DIRNAME/psubmit-mpiexec-wrapper.sh -t vbbs -i $jobid_short -n "$NP" -p "$PPN" -d "$PSUBMIT_DIRNAME" -o "$OPTSCRIPT" -a "\"$ARGS\"" > "$FILE_OUT" 2>&1 &
        fi
    fi
    if [ "$jobstatus" == "R" ]; then
        NBGJOBS=$(jobs -rp | wc -l)
        if [ "$NBGJOBS" -eq "0" ]; then 
            jobstatus="DONE"
            vbbs stop $jobid
            rm -f hostfile.$jobid
        fi
    fi
    psub_update_oldjobstatus
}

function psub_check_job_done() {
    [ "$jobstatus" == "DONE" ] && jobdone=1
    true;
}

function psub_cancel() {
	if [ "$jobid" != "" -a "$jobcancelled" == "" ]; then
        # ssh to a node and kill
        headnode=$(head -n1 hostfile.$jobid | cut -d: -f1)
        ssh $headnode killall psubmit-mpiexec-wrapper.sh
        vbbs stop $jobid
		jobcancelled="$jobid"
	fi
}

function psub_submit() {
    outfile=$(mktemp -u .out.XXXXXXX)
    rm -f "$outfile"

    NBGJOBS=$(jobs -rp | wc -l)
    if [ "$NBGJOBS" -ne "0" ]; then echo ">> psub_vbbs: ERROR: non-zero background jobs count: $NBGJOBS"; exit 1; fi
    vbbs start $NNODES >& $outfile &
    if [ $? != 0 ]; then echo ">> psub_vbbs: VBBS failed on start"; exit 1; fi
    jobstatus="Q"
    local cnt=0
    while [ "$cnt" -lt 60 ]; do
        jobid=$(cat $outfile | grep 'id:' | cut -d ' ' -f2)
        if [ -z "$jobid" ]; then sleep 1; cnt=$(expr "$cnt" \+ 1); continue; fi
        jobid_short=$jobid
        break;
    done
    if [ -z "$jobid" ]; then jobstatus="NONE"; echo ">> psub_vbbs: cannot find output of 'vbbs start'"; return; fi
}

function psub_set_paths() {
    psub_common_set_paths
}

function psub_set_outfiles() {
    FILE_OUT=$SCRATCH_PWD/vbbs-$jobid.out
}

function psub_move_outfiles() {
    psub_common_move_outfiles
}

function psub_cleanup() {
    psub_common_cleanup
}
