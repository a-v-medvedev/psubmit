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

PBSFILE=""
psub_submit() {
    local outfile=$(mktemp -u .out.XXXXXXX)
    rm -f "$outfile"
    PBSFILE=$(mktemp -u submit.XXXXXXX.pbs)
    local n=$(expr "$NNODES" \* "$PPN")
    [ -z "$JOB_NAME" ] && JOB_NAME=$(basename "$TARGET_BIN")
    echo $- | grep -q x && xopt="-x"
    echo $PSUBMIT_DIRNAME/psubmit-mpiexec-wrapper.sh -w "$PWD" -t pbs -n "$n" -p "$PPN" -h "$NTH" -d "$PSUBMIT_DIRNAME" -e "$TARGET_BIN" -o "$OPTSCRIPT" -a "\"$ARGS\"" $xopt >> $PBSFILE
    local queue=""
    [ -z "$QUEUE" ] || queue="-q $QUEUE"
    local nodetype=""
    [ -z "$NODETYPE" ] || nodetype=":$NODETYPE";
    qsub -N "pbs_output" -l "nodes=${NNODES}:ppn=${PPN}${nodetype},walltime=00:$TIME_LIMIT:00" $queue "$PBSFILE" 2>&1 | tee "$outfile"
    grep -q "^[0-9]*\.$QUEUE_SUFFIX$" "$outfile"
    if [ $? != "0" ]; then rm -f "$outfile"; exit 0; fi
    export jobid=$(grep "^[0-9]*\.$QUEUE_SUFFIX$" "$outfile")
    export jobid_short=`echo $jobid | awk -F. '{ print $1 }'`
    rm "$outfile"
    sleep 2
}

psub_set_paths() {
    psub_common_set_paths
}

psub_set_outfiles() {
    FILE_OUT=pbs_output.o$jobid_short
}

psub_move_outfiles() {
    psub_common_move_outfiles
    local dir="$SCRATCH_PWD"
    local target="$dir/results.$jobid_short"
    mv pbs_output.e$jobid_short "$target"
    [ -z "$PBSFILE" ] || rm -f $PBSFILE
}

function psub_make_stackfile() {
    psub_common_make_stackfile
}

psub_cleanup() {
    psub_common_cleanup 
    [ -z "$PBSFILE" ] || rm -f $PBSFILE
}
