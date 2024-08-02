#!/bin/bash

. $PSUBMIT_DIRNAME/psub_common.sh

psub_check_job_status() {
    [ "$jobstatus" == "DONE" ] && return
    local queue_flag=""
    [ -z "$QUEUE" ] || queue_flag="-p $QUEUE"
    queue_out=$(squeue -o "%A %t" $queue_flag 2>&1 | grep "$jobid_short")
    if [ -z "$queue_out" -a ! -f "$FILE_OUT" ]; then echo "JOB DISAPPEARED!"; jobstatus="NONE"; return; fi
    jobstatus=$(echo $queue_out | awk '{print $2}')
    if [ -z "$jobstatus" ]; then
        psub_check_job_done
		[ "$jobdone" == "1" ] && return
        echo "JOB DISAPPEARED!"; jobstatus="NONE"; return
    fi
    case "$jobstatus" in
        R) 
            ;;
        PD) jobstatus="Q"
            ;;
        CG) jobstatus="CG"
            ;;
        CF) 
            ;;
        *) echo ">> psub_slurm: UNEXPECTED: ($jobstatus) in squeue out: $queue_out"; jobstatus="NONE"
    esac
    psub_update_oldjobstatus
}

psub_check_job_done() {
    psub_check_if_exited
    [ "$?" == 1 ] && jobdone=1
    [ "$jobdone" == "1" ] && jobstatus="DONE"
    psub_update_oldjobstatus
}

psub_cancel() {
	if [ "$jobid" != "" -a "$jobcancelled" == "" ]; then scancel $jobid; jobcancelled="$jobid"; fi
}

psub_submit() {
    outfile=$(mktemp -u .out.XXXXXXX)
    rm -f "$outfile"
    n=$(expr "$NNODES" \* "$PPN")
    local resources=""
    if [ -z "$RESOURCE_HANDLING" -o "$RESOURCE_HANDLING" == "gres" ]; then
        [ -z "$NODETYPE" ] || resources="--gres=$NODETYPE"
    elif [ "$RESOURCE_HANDLING" == "qos" ]; then
        [ -z "$NODETYPE" ] || resources="--qos=$NODETYPE"
    else
        # unknown case 
        echo ">> FATAL: psub_submit(): unknown RESOURCE_HANDLING value."
        return
    fi
    [ ! -z "$GENERIC_RESOURCES" -a "$RESOURCE_HANDLING" == "gres" ] && resources="$resources,$GENERIC_RESOURCES"
    [ ! -z "$GENERIC_RESOURCES" -a "$RESOURCE_HANDLING" != "gres" ] && resources="$resources --gres=$GENERIC_RESOURCES"
    [ ! -z "$CONSTRAINT" ] && constraint="$CONSTRAINT"
    local blacklist=""
    [ -z "$BLACKLIST" ] || blacklist="--exclude $BLACKLIST"
    local whitelist=""
    [ -z "$WHITELIST" ] || whitelist="-w $WHITELIST"
    local account=""
    [ -z "$ACCOUNT" ] || account="--account=$ACCOUNT"
    local comment=""
    [ -z "$COMMENT" ] || comment="--comment=$COMMENT"
    local queue_flag=""
    [ -z "$QUEUE" ] || queue_flag="-p $QUEUE"

    echo $- | grep -q x && xopt="-x"
    [ -z "$JOB_NAME" ] && JOB_NAME=$(basename "$TARGET_BIN")
    sbatch -J "$JOB_NAME" --exclusive --time=${TIME_LIMIT} $resources $constraint $blackist $whitelist $account $comment $queue_flag -D "$PWD" -N "$NNODES" -n "$n" $PSUBMIT_DIRNAME/psubmit-mpiexec-wrapper.sh -t slurm -n "$n" -p "$PPN" -h "$NTH" -g "$NGPUS" -d "$PSUBMIT_DIRNAME" $xopt  -e "$TARGET_BIN" -o "$OPTSCRIPT" -a "\"$ARGS\"" 2>&1 | tee "$outfile"
    
    grep "Batch job submission failed" "$outfile" && exit 0
    local pattern="Submitted batch job "
    grep -q "$pattern" "$outfile"
    if [ $? != "0" ]; then rm -f "$outfile"; exit 0; fi
    submitted=$(grep "$pattern" "$outfile")
    export jobid=$(echo "$submitted" | cut -d ' ' -f 4)
    export jobid_short=$jobid
    rm -f "$outfile"
}

psub_set_paths() {
	psub_common_set_paths
}

psub_set_outfiles() {
    FILE_OUT=$SCRATCH_PWD/slurm-$jobid.out
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

