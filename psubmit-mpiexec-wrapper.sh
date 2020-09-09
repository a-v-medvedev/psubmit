#!/bin/bash

function fatal() {
    local str="$1"
    echo ">>> PSUBMIT: FATAL: $str"
    exit 1
}

function info() {
    local str="$1"
    echo ">>> PSUBMIT: $str"
}

function psub_env_check {
    case "$PSUBMIT_BATCH_TYPE" in
    pbs)
        cd $PBS_O_WORKD 
        local CHECK_JOBID=`echo $PBS_JOBID | awk -F. '{print $1}'`
        local CHECK_NP=$PBS_NP
        local CHECK_PPN=$PBS_NUM_PPN
        local CHECK_DIRNAME=$(cd $(dirname "$0") && pwd -P)
        PSUBMIT_JOBID=$CHECK_JOBID
        [ "$CHECK_NP" != "$PSUBMIT_NP" ] && fatal "PSUBMIT_NP value is not correct"
        [ "$CHECK_PPN" != "$PSUBMIT_PPN" ] && fatal "PSUBMIT_PPN value is not correct"
        [ -z "$PSUBMIT_DIRNAME" ] && PSUBMIT_DIRNAME=$CHECK_DIRNAME
        ;;
    slurm)
        local CHECK_JOBID=$SLURM_JOBID
        local CHECK_NNODES=$SLURM_NNODES
        local CHECK_NP=$SLURM_NPROCS
        local CHECK_PPN=$(expr $SLURM_NPROCS / $SLURM_NNODES)
        local CHECK_DIRNAME=$(cd $(dirname "$0") && pwd -P)
        PSUBMIT_JOBID=$CHECK_JOBID
        [ "$CHECK_NP" != "$PSUBMIT_NP" ] && fatal "PSUBMIT_NP value is not correct"
        [ "$CHECK_PPN" != "$PSUBMIT_PPN" ] && fatal "PSUBMIT_PPN value is not correct"
        [ -z "$PSUBMIT_DIRNAME" ] && PSUBMIT_DIRNAME=$CHECK_DIRNAME
        ;;
    lsf)
        local CHECK_JOBID=$LSB_JOBID
        local _tmp=($LSB_MCPU_HOSTS)
        local CHECK_PPN="${_tmp[1]}"
        local CHECK_NNODES=0
        local CHECK_NP=0
        for n in $(sort < $LSB_DJOB_HOSTFILE | uniq); do CHECK_NNODES=$(expr "$CHECK_NNODES" \+ 1); CHECK_NP=$(expr "$CHECK_NP" \+ "$CHECK_PPN"); done
        local CHECK_DIRNAME=$(cd $(dirname "$0") && pwd -P)
        PSUBMIT_JOBID=$CHECK_JOBID
        [ "$CHECK_NP" != "$PSUBMIT_NP" ] && fatal "PSUBMIT_NP value is not correct"
        [ "$CHECK_PPN" != "$PSUBMIT_PPN" ] && fatal "PSUBMIT_PPN value is not correct"
        [ -z "$PSUBMIT_DIRNAME" ] && PSUBMIT_DIRNAME=$CHECK_DIRNAME
        ;;
    vbbs)
        local CHECK_DIRNAME=$(cd $(dirname "$0") && pwd -P)
        [ "$CHECK_DIRNAME" != "$PSUBMIT_DIRNAME" ] && fatal "PSUBMIT_DIRNAME value is not correct"
        ;;
    direct)
        local CHECK_DIRNAME=$(cd $(dirname "$0") && pwd -P)
        [ "$CHECK_DIRNAME" != "$PSUBMIT_DIRNAME" ] && fatal "PSUBMIT_DIRNAME value is not correct"
        ;;
    esac
}

function add_element {
    local list="$1"
    local elem="$2"
    local ppn="$3"
    [ -z "$list" ] || list=$list","
    echo "${list}${elem}:$ppn"
}

function is_any_char {
    local str="$1"
    local chars="$2"
    local cnt=$(expr index "$str" "$chars")
    [ "$cnt" != "0" ] && return 0 || return 1
}

function psub_get_nodelist {
    case "$PSUBMIT_BATCH_TYPE" in
    pbs)
        local NODELIST=""
        for n in $(sort < $PBS_NODEFILE | uniq); do $(add_element "$NODELIST" "$n" "$PSUBMIT_PPN"); done
        export PSUBMIT_NODELIST=$NODELIST
        ;;
    slurm)
        local NODELIST=""
        if is_any_char "$SLURM_JOB_NODELIST" "[,"; then
            for e in $(echo $SLURM_JOB_NODELIST | sed 's/,\([^0-9]\)/ \1/g'); do
                if is_any_char "$e" "["; then
                    local main="`echo $e | sed 's/^\(.*\)\[.*$/\1/'`"
                    local var="`echo $e | sed 's/^.*\[\(.\+\)\]$/\1/;s/,/ /g'`"
                    for i in $var; do
                        if is_any_char "$i" "-"; then
                            local begin="$(echo $i | cut -d- -f1)"
                            local end="$(echo $i | cut -d- -f2)"
                            for n in $(seq -w $begin $end); do
                                NODELIST=$(add_element "$NODELIST" "$main$n" "$PSUBMIT_PPN")
                            done
                        else
                            NODELIST=$(add_element "$NODELIST" "$main$i" "$PSUBMIT_PPN")
                        fi
                    done
                else
                    NODELIST=$(add_element "$NODELIST" "$main$e" "$PSUBMIT_PPN")
                fi
            done
        else
            NODELIST=$SLURM_JOB_NODELIST:$PSUBMIT_PPN
        fi
        export PSUBMIT_NODELIST=$NODELIST
        ;;
    lsf)
        local NODELIST=""
        for n in $(sort < $LSB_DJOB_HOSTFILE | uniq); do NODELIST=$(add_element "$NODELIST" "$n" "$PSUBMIT_PPN"); done
        export PSUBMIT_NODELIST=$NODELIST
        ;;
    vbbs)
        # Assume PSUBMIT_NODELIST comes with env
        ;;
    direct)
        local NODELIST="$(hostname):$PSUBMIT_PPN"
        export PSUBMIT_NODELIST=$NODELIST
        ;;
    esac

}


while getopts ":t:i:n:p:d:o:a:x" opt; do
  case $opt in
    t) export PSUBMIT_BATCH_TYPE="$OPTARG"
      ;;
    i) export PSUBMIT_JOBID="$OPTARG"
      ;;
    p) export PSUBMIT_PPN="$OPTARG"
      ;;
    n) export PSUBMIT_NP="$OPTARG"
      ;;
    d) export PSUBMIT_DIRNAME="$OPTARG"
      ;;
    o) OPTIONSFILE="$OPTARG"
      ;;
    a) ARGS="$OPTARG"
      ;;
    x) PSUBMIT_DBG=1 
      ;;
  esac
done

[ -z "$PSUBMIT_DBG" ] || set -x

psub_env_check

info "PSUBMIT_JOBID=$PSUBMIT_JOBID PSUBMIT_DIRNAME=$PSUBMIT_DIRNAME"
info "args: $*"

exec 1>psubmit_wrapper_output.$PSUBMIT_JOBID
exec 2>&1

info "PWD=$PWD"

if [ -f "$OPTIONSFILE" ]; then
. "$OPTIONSFILE"
fi

[ -z "$MPIEXEC" ] && MPIEXEC="./mpiexec-generic.sh"
[ -z "$TARGET_BIN" ] && TARGET_BIN="hostname"

[ -z "$INJOB_INIT_COMMANDS" ] || eval "$INJOB_INIT_COMMANDS"

psub_get_nodelist
info "Nodelist $PSUBMIT_NODELIST"

. "$MPIEXEC" $ARGS

info "Exiting..."

