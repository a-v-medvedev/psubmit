#!/bin/bash

. $PSUBMIT_DIRNAME/psub_common.sh

psub_check_job_status() {
    queue_out=$(bjobs $jobid_short 2>&1 | grep "^$jobid_short")
    if [ -z "$queue_out" -a ! -f "$FILE_OUT" ]; then echo "JOB DISAPPEARED!"; jobstatus="NONE"; return; fi
    jobstatus=$(echo "$queue_out" | awk '{print $3}')
    if [ "$jobstatus" == "" ]; then echo "JOB DISAPPEARED!"; jobstatus="NONE"; return; fi
    case "$jobstatus" in
        RUN) jobstatus="R"
            ;;
        PEND) jobstatus="Q"
            ;;
        EXIT) jobstatus="C"
            ;;
        DONE) jobstatus="DONE"
            ;;
        *) echo ">> psub_lsf: UNEXPECTED bjobs output: $queue_out"; jobstatus="NONE";
            ;;
    esac
    psub_update_oldjobstatus
}

psub_check_job_done() {
    if [ "$jobdone" == "1" ]; then return; fi
    psub_check_if_exited
    if [ "$?" == 1 ]; then 
        jobdone=1 
        psub_check_job_status		
        local n=1
        while [ "$jobstatus" == "R" ]; do
            sleep 3
            psub_check_job_status		
            n=$(expr $n \+ 1)
            if [ "$n" == "100" ]; then echo ">> psub_lsf: psub_check_job_done: n=$n"; break; fi
        done
        jobstatus="DONE"
    fi
    psub_update_oldjobstatus
}

psub_cancel() {
    if [ "$jobid" != "" -a "$jobcancelled" == "" ]; then bkill "$jobid"; jobcancelled="$jobid"; fi
}

psub_submit() {
    local outfile=`mktemp -u .out.XXXXXXX`
    rm -f "$outfile"
    local select="select[type==any]"
    [ -z "$NODETYPE" ] || select="select[$NODETYPE]";
    local span="span[ptile=$PPN]"
    n=$(expr "$NNODES" \* "$PPN")
    bsub -q "$QUEUE" -l NMIWATCHDOG_OFF=1 -n $n -R "{$select $span}" -W 00:$TIME_LIMIT -o lsf-output.%J psubmit-mpiexec-wrapper.sh -t lsf -i $jobid_short -n "$n" -p "$PPN" -d "$PSUBMIT_DIRNAME" -o "$OPTSCRIPT" -a "\"$ARGS\"" >& "$outfile"
    local pattern="^Job <[0-9]*> is submitted to queue <"
    grep -q "$pattern" "$outfile"
    if [ $? != "0" ]; then rm -f "$outfile"; exit 0; fi
    local submitted=$(grep "$pattern" "$outfile")
    jobid=$(echo $submitted | awk -F '[<>]' '{print $2}')
    jobid_short=$jobid
    rm -f "$outfile"
    echo $submitted
}

psub_set_paths() {
    psub_common_set_paths
}

psub_set_outfiles() {
    FILE_OUT=$SCRATCH_PWD/lsf-output.$jobid
}

psub_move_outfiles() {
    psub_common_move_outfiles
}

function psub_make_stackfile() {
    psub_common_make_stackfile
}

psub_cleanup() {
    psub_common_cleanup
}
