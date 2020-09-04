#!/bin/bash

. $PSUBMIT_DIRNAME/psub_common.sh

psub_check_job_status() {
    queue_out=$(qstat $jobid_short 2>&1 | grep "^$jobid_short")
    if [ -z "$queue_out" -a ! -f "$FILE_OUT" ]; then echo "JOB DISAPPEARED!"; jobstatus="NONE"; return; fi
    jobstatus=$(echo $queue_out | awk '{print $5}')
    if [ "$jobstatus" == "" ]; then echo "JOB DISAPPEARED!"; jobstatus="NONE"; return; fi
    if [ "$jobstatus" != "R" -a "$jobstatus" != "C" -a "$jobstatus" != "E" -a "$jobstatus" != "Q" ]; then
        echo ">> psub_pbs: UNEXPECTED qstat out: $queue_out"
        jobstatus="NONE"
    fi
    psub_update_oldjobstatus
}

psub_check_job_done() {
    psub_check_if_exited
    [ "$?" == 1 ] && jobdone=1
}

psub_cancel() {
    if [ "$jobid" != "" -a "$jobcancelled" == "" ]; then qdel "$jobid"; jobcancelled="$jobid"; fi
}

psub_submit() {
    local outfile=$(mktemp -u .out.XXXXXXX)
    rm -f "$outfile"
    local pbsfile=$(mktemp -u submit.XXXXXXX.pbs)
    echo psubmit-mpiexec-wrapper.sh -t pbs -i $jobid_short -n "$NP" -p "$PPN" -d "$PSUBMIT_DIRNAME" -o "$OPTSCRIPT" -a "\"$ARGS\"" >> $pbsfile
    local nodetype=""
    [ -z "$NODETYPE" ] || nodetype=":$NODETYPE";
    qsub -l "nodes=${NNODES}:ppn=${PPN}${nodetype},walltime=00:$TIME_LIMIT:00" -q "$QUEUE" "$pbsfile" 2>&1 | tee "$outfile"
    grep -q "^[0-9]*\.$QUEUE_SUFFIX$" "$outfile"
    if [ $? != "0" ]; then rm -f "$outfile"; exit 0; fi
    export jobid=$(grep "^[0-9]*\.$QUEUE_SUFFIX$" "$outfile")
    export jobid_short=`echo $jobid | awk -F. '{ print $1 }'`
    sleep 2
}

psub_set_paths() {
    psub_common_set_paths
}

psub_set_outfiles() {
    FILE_OUT=pbs-output.$jobid_short
}

psub_move_outfiles() {
    psub_common_move_outfiles
}

psub_cleanup() {
    psub_common_cleanup() 
}
