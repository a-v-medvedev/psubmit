#!/bin/bash

if [ -z "$1" -o -z "$2" ]; then echo "Usage: " $(basename $0) "-n NUM_NODES -p PROC_PER_NODE [-o options_file] [-a args]"; exit 1; fi

NNODES=1
PPN=1
OPTSCRIPT=./psubmit.opt
ARGS=""

while getopts ":n:p:o:a:x" opt; do
  case $opt in
    n)
      NNODES=$OPTARG
      ;;
    p)
      PPN=$OPTARG
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
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

n=`expr $NNODES \* $PPN`

PSUBMIT_DIRNAME=$(cd $(dirname "$0") && pwd -P)

# All these options can be overriden by psubmit.opt script
QUEUE=test
TIME_LIMIT=10
INIT_COMMANDS=""
INJOB_INIT_COMMANDS=""
TARGET_BIN="hostname"
MPIEXEC="generic"
#MPIEXEC=./mpiexec-generic.sh
BATCH="slurm"

if [ -f "$OPTSCRIPT" ]; then
    . "$OPTSCRIPT"
else
    echo "Cannot open options script:" "$OPTSCRIPT"
    exit 1
fi

export MPIEXEC=$PSUBMIT_DIRNAME/mpiexec-${MPIEXEC}.sh
export BATCH=$PSUBMIT_DIRNAME/psub_${BATCH}.sh

if [ -f "$BATCH" ]; then
    . "$BATCH"
else
    echo "Cannot open batch system script:" "$BATCH"
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
    sleep 1
done

psub_move_outfiles


