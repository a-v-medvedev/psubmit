#!/bin/bash

function usage() {
    echo "Usage: " $(basename $0) "-n NUM_NODES [-p PROC_PER_NODE] [-o options_file] [-a args] [-e executable_bunary] [-x] [-b preproc_script] [-f postproc_script]"; exit 1;
}

if [ -z "$1" ]; then usage; fi
NNODES=1
PPN="-"
NTH="1"
OPTSCRIPT=./psubmit.opt
ARGS=""

while getopts ":n:p:t:o:a:b:f:e:x" opt; do
  case $opt in
    n)
      NNODES=$OPTARG
      ;;
    p)
      PPN_CMDLINE=$OPTARG
      ;;
    t) 
      NTH_CMDLINE=$OPTARG
      ;;
    e)
      TARGET_BIN_CMDLINE=$OPTARG
      ;;
    o)
      OPTSCRIPT=$OPTARG
      ;;
    a)
      ARGS="$OPTARG"
      ;;
    x)
      PSUBMIT_DBG="ON" 
      ;;
    b) 
      export PSUBMIT_PREPROC="$OPTARG"
      ;;
    f) 
      export PSUBMIT_POSTPROC="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done


PSUBMIT_DIRNAME=$(cd $(dirname "$0") && pwd -P)

# All these options can be overriden by psubmit.opt script
QUEUE=test
TIME_LIMIT=10
INIT_COMMANDS=""
INJOB_INIT_COMMANDS=""
TARGET_BIN="hostname"
MPIEXEC="generic"
BATCH="slurm"

if [ -f "$OPTSCRIPT" ]; then
    . "$OPTSCRIPT"
else
    echo "Cannot open options script:" "$OPTSCRIPT"
    exit 1
fi

[ -z "$PPN_CMDLINE" ] || PPN="$PPN_CMDLINE"
[ -z "$NTH_CMDLINE" ] || NTH="$NTH_CMDLINE"
[ -z "$TARGET_BIN_CMDLINE" ] || TARGET_BIN="$TARGET_BIN_CMDLINE"
export TARGET_BIN

if [ "$PPN" == "-" ]; then
    echo "FATAL: PPN is not defined neither in command line nor in opts file"
    exit 1
fi

[ -z "$BEFORE" -a -z "$PSUBMIT_PREPROC" ] || export PSUBMIT_PREPROC="$BEFORE"

[ -z "$AFTER" -a -z "$PSUBMIT_POSTPROC" ] || export PSUBMIT_POSTPROC="$AFTER"

n=$(expr $NNODES \* $PPN)

export MPIEXEC=$PSUBMIT_DIRNAME/mpiexec-${MPIEXEC}.sh
export BATCH=$PSUBMIT_DIRNAME/psub_${BATCH}.sh

if [ -f "$BATCH" ]; then
    . "$BATCH"
else
    echo "FATAL: Cannot open batch system script:" "$BATCH"
    exit 1
fi

trap psub_cleanup INT TERM

if [ ! -z "$INIT_COMMANDS" ]; then
    eval "$INIT_COMMANDS"
fi

check_bash_func_declared() {
    if [ `type -t $1`"" != 'function' ]; then   
        echo "FATAL: $1 bash function is not defined!"
        exit 1
    fi
}

check_bash_func_declared psub_submit
check_bash_func_declared psub_set_paths
check_bash_func_declared psub_set_outfiles
check_bash_func_declared psub_move_outfiles
check_bash_func_declared psub_make_stackfile
check_bash_func_declared psub_cleanup
check_bash_func_declared psub_check_job_status
check_bash_func_declared psub_check_job_done
check_bash_func_declared psub_cancel

[ ! -z "$PSUBMIT_DBG" ] && set -x 

psub_submit
psub_set_paths
psub_set_outfiles

echo "Job ID $jobid_short" 
echo -ne "Queue: $QUEUE"
[ ! -z "$QUEUE_SUFFIX" ] && echo -ne "[$QUEUE_SUFFIX]"
[ ! -z "$NODETYPE" ] && echo -ne " nodetype: $NODETYPE"
echo -ne "\n"

ncancel="0"
while [ ! -f "$FILE_OUT" ]; do
    [ $(expr "$ncancel" % 10) == "0" ] && psub_check_job_status
    if [ "$jobstatus" == "C" -o "$jobstatus" == "NONE" ]; then 
	    if [ "$ncancel" -gt "100" ]; then 
            if [ "$jobstatus" == "C" ]; then echo "No file $FILE_OUT. Can't continue"; fi
            if [ "$jobstatus" == "NONE" ]; then echo "No file $FILE_OUT and no job in joblist. Can't continue"; fi
            exit 1
        fi
	    ncancel=`expr $ncancel \+ 1`
    fi
    sleep 0.1
done

sleep 0.5
psub_check_job_status

while true
do
    psub_check_job_done
    [ "$jobdone" == "1" ] && break

    psub_check_job_status
    if [ "$jobstatus" == "NONE" ]; then psub_check_job_done; break; fi
    if [ "$jobstatus" == "C" ]; then psub_check_job_done; break; fi
    if [ "$jobstatus" == "DONE" ]; then break; fi
    if [ "$jobstatus" == "E" ]; then psub_check_job_done; break; fi
    sleep 0.1
done

psub_move_outfiles
psub_make_stackfile


