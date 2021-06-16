#!/bin/bash

. $PSUBMIT_DIRNAME/psub_common.sh

DIRECT_JOB_PID=""
DIRECT_LOCKFILE=""
DIRECT_OVERSUBSCRIBE_LEVEL=1
[ -z "$PSUBMIT_OPTS_DIRECT_OVERSUBSCRIBE_LEVEL" ] || DIRECT_OVERSUBSCRIBE_LEVEL=$PSUBMIT_OPTS_DIRECT_OVERSUBSCRIBE_LEVEL

function psub_check_job_status() {
    if [ "$jobstatus" == "Q" ]; then
        local np=$(expr "$NNODES" \* "$PPN")
        daemonize -EPATH=$PATH -ELD_LIBRARY_PATH=$LD_LIBRARY_PATH -l "$DIRECT_LOCKFILE" -c $PWD -p "$DIRECT_JOB_PID" -o ${FILE_OUT} $(which timeout) -k10s ${TIME_LIMIT}m "$PSUBMIT_DIRNAME/psubmit-mpiexec-wrapper.sh" -t direct -i "$jobid_short" -n "$np" -p "$PPN" -d "$PSUBMIT_DIRNAME" -o "$OPTSCRIPT" -a "\"$ARGS\"" >& "$OUTFILE"
        grep -q 'Is another instance running' "$OUTFILE"
        if [ "$?" == "0" ]; then 
            jobstatus="Q"; 
            rm -f "$OUTFILE"; 
            return 1;
        else 
            local pid=$(cat "$DIRECT_JOB_PID")
            local isnumber=$(expr "$pid" "+" "0" 2> /dev/null)
            if [ ! -z "$isnumber" -a "$isnumber" == "$pid" ]; then
            	jobstatus="R";
			else
			    jobstatus="NONE"
                sleep 1
				return 1
			fi
            rm -f "$OUTFILE"; 
        fi
    fi
    if [ "$jobstatus" == "R" ]; then
        if [ -f $DIRECT_JOB_PID ]; then
            local pid=$(cat "$DIRECT_JOB_PID")
            local isnumber=$(expr "$pid" "+" "0" 2> /dev/null)
            if [ ! -z "$isnumber" -a "$isnumber" == "$pid" ]; then
                local N=$(ps -p $pid --no-headers | wc -l)
                [ "$N" == "0" ] && jobstatus="DONE"
                [ "$N" == "1" ] && jobstatus="R"
            else
                jobstatus="DONE"
            fi
        else
            jobstatus="DONE"
        fi
    fi
    psub_update_oldjobstatus
}

function psub_check_job_done() {
    psub_check_if_exited
    [ "$?" == 1 ] && jobdone=1
}

function psub_cancel() {
	if [ "$jobid" != "" -a "$jobcancelled" == "" ]; then
        local pid=$(cat $DIRECT_JOB_PID)
        expr "$pid" "+" "1" >& /dev/null && kill $pid
		jobcancelled="$jobid"
        jobstatus="C"
	fi
}

function psub_submit() {
    OUTFILE=$(mktemp -u .out.XXXXXXX)
    rm -f "$OUTFILE"
    DIRECT_JOB_PID=`mktemp -u .XXXXXXX.pid`
    rm -f $DIRECT_JOB_PID
    local tag=$(echo "$RANDOM%$DIRECT_OVERSUBSCRIBE_LEVEL+1" | bc)
    DIRECT_LOCKFILE=$PSUBMIT_DIRNAME/direct-run-${tag}.lock
    local mult=1000000
    [ "$DIRECT_OVERSUBSCRIBE_LEVEL" == 1 ] && mult=1
    local startid=$(echo "$tag*$mult" | bc)
    if [ -f "$DIRECT_LOCKFILE" ]; then
        (
            flock -e 9
            jobid=$(cat "$DIRECT_LOCKFILE")
            expr "$jobid" \+ 1 >& /dev/null || jobid=$startid && true
            jobid=$(expr "$jobid" \+ 1)
            echo $jobid > "$DIRECT_LOCKFILE"
            echo $jobid > $OUTFILE
        ) 9<"$DIRECT_LOCKFILE"
    else
        touch "$DIRECT_LOCKFILE"
        (
            flock -n 9 || exit 1
            jobid=$startid
            echo $startid > "$DIRECT_LOCKFILE"
            echo $jobid > $OUTFILE
        ) 9<"$DIRECT_LOCKFILE" || echo 1$startid > $OUTFILE 
    fi
    jobid=$(cat $OUTFILE)
    jobstatus="Q"
    export jobid
    jobid_short=$jobid
    export jobid_short
    local np=$(expr "$NNODES" \* "$PPN")
    rm -f hostfile.$jobid_short
    for i in `seq 1 1 $np`; do
        echo "localhost" >> hostfile.$jobid_short
    done
}

function psub_set_paths() {
    psub_common_set_paths
}

function psub_set_outfiles() {
    FILE_OUT=direct-output.$jobid_short
}

function psub_move_outfiles() {
    psub_common_move_outfiles
    [ -z "$DIRECT_JOB_PID" ] || rm -f "$DIRECT_JOB_PID" && true
}

function psub_make_stackfile() {
    psub_common_make_stackfile
}

function psub_cleanup() {
    psub_common_cleanup
    [ -z "$DIRECT_JOB_PID" ] || rm -f "$DIRECT_JOB_PID" && true
}

