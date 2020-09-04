#!/bin/bash

. $PSUBMIT_DIRNAME/psub_common.sh

DIRECT_JOB_PID=""

function psub_check_job_status() {
    if [ "$jobstatus" == "Q" ]; then
        local np=$(expr "$NNODES" \* "$PPN")
        /usr/sbin/daemonize -EPATH=$PATH -ELD_LIBRARY_PATH=$LD_LIBRARY_PATH -c $PWD -p "$DIRECT_JOB_PID" -o ${FILE_OUT} $(which timeout) $TIME_LIMIT "$PSUBMIT_DIRNAME/psubmit-mpiexec-wrapper.sh" -t direct -i "$jobid_short" -n "$np" -p "$PPN" -d "$PSUBMIT_DIRNAME" -o "$OPTSCRIPT" -a "\"$ARGS\"" >& "$OUTFILE"
        cat $OUTFILE
        grep -q 'Is another instance running' "$OUTFILE"
        if [ "$?" == "0" ]; then
            jobstatus="Q"
            exit 1
        else
            echo $jobid > "$DIRECT_LOCKFILE"
            rm "$OUTFILE"
            jobstatus="R"
        fi
    fi
    if [ "$jobstatus" == "R" ]; then
        local pid=$(cat "$DIRECT_JOB_PID")
        local N=$(ps -p $pid --no-headers | wc -l)
        if [ "$N" == "0" ]; then
            jobstatus="DONE"
        fi
        if [ "$N" == "1" ]; then
            jobstatus="R"
        fi
    fi
    if [ "$jobstatus" != "$oldjobstatus" ]; then echo "Job status: $jobstatus"; fi
    oldjobstatus=$jobstatus
}

function psub_check_job_done() {
    cat "$FILE_OUT" | awk -v NNODES=1 '/Exiting.../ { done++; if (done == NNODES) { exit 1; } } { next; }'
    [ "$?" == 1 ] && jobdone=1
}

function psub_cancel() {
	if [ "$jobid" != "" -a "$jobcancelled" == "" ]; then
        local pid=$(cat $DIRECT_JOB_PID)
        expr $pid \+ 1 >& /dev/null && kill $pid
		jobcancelled="$jobid"
	fi
}

function psub_submit() {
    OUTFILE=`mktemp -u .out.XXXXXXX`
    rm -f "$OUTFILE"
    DIRECT_JOB_PID=`mktemp -u .XXXXXXX.pid`
    DIRECT_LOCKFILE=$PSUBMIT_DIRNAME/direct-run.lock
    if [ -f "$DIRECT_LOCKFILE" ]; then
        jobid=$(cat "$DIRECT_LOCKFILE")
        expr "$jobid" \+ 1 >& /dev/null || jobid=0 && true
        jobid=$(expr "$jobid" \+ 1)
        echo $jobid > "$DIRECT_LOCKFILE"
    else
        echo 0 > "$DIRECT_LOCKFILE"
    fi
    jobstatus="Q"
    export jobid
    jobid_short=$jobid
    export jobid_short
}

function psub_set_paths() {
    psub_common_set_paths
}

function psub_set_outfiles() {
    FILE_OUT=direct-output.$jobid_short
}

function psub_move_outfiles() {
    psub_common_move_outfiles
}

function psub_cleanup() {
    psub_common_cleanup
}

