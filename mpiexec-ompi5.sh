#!/bin/bash

time1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_NP%/$PSUBMIT_NP/g")

function num_files_by_mask() {
    local nf=$(ls -1 $1 2>/dev/null | wc -l)
    echo $nf
}

NUL="0"
[ "$PSUBMIT_NP" -gt 10 ] && NUL="00"
[ "$PSUBMIT_NP" -gt 100 ] && NUL="000"
[ "$PSUBMIT_NP" -gt 1000 ] && NUL="0000"
[ "$PSUBMIT_NP" -gt 10000 ] && NUL="00000"

export PSUBMIT_RANK0=
export PSUBMIT_ERANK0=
[ $(num_files_by_mask "out.$PSUBMIT_JOBID.*@1.$NUL.out") == "1" ] && export PSUBMIT_RANK0=$(echo out.$PSUBMIT_JOBID.*@1.$NUL.out)
[ $(num_files_by_mask "out.$PSUBMIT_JOBID.*@1.$NUL.err") == "1" ] && export PSUBMIT_ERANK0=$(echo out.$PSUBMIT_JOBID.*@1.$NUL.err)
if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "$PSUBMIT_RANK0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "$PSUBMIT_ERANK0"
elif [ "$ALL_ARGS" == "--has-err" ]; then
    [ $(num_files_by_mask "out.$PSUBMIT_JOBID.*@1.$NUL.err") != "0" ] && echo TRUE
else

    [ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

    [ -z "$ALL_ARGS" ] || export PSUBMIT_ARGS="$ALL_ARGS"

    [ -z "$NGPUS" ] && NGPUS=0
    [ -z "$PSUBMIT_NTH" ] && PSUBMIT_NTH=1
    export OMP_NUM_THREADS="$PSUBMIT_NTH"

    export PSUBMIT_JOBID PSUBMIT_NP PSUBMIT_NTH PSUBMIT_PPN
    [ -z "$PSUBMIT_PREPROC" ] || source $PSUBMIT_PREPROC
    
    if [ "$TARGET_BIN" != "false" ]; then
        [ -f "hostfile.$PSUBMIT_JOBID" ] && machinefile="-machinefile hostfile.$PSUBMIT_JOBID"
        [ -f "hostfile.$PSUBMIT_JOBID" ] && sed -i 's/:[0-9]*$/ slots=&/;s/://' hostfile.$PSUBMIT_JOBID

        echo ">>> PSUBMIT: mpirun is: " $(which mpirun)
        echo ">>> PSUBMIT: mpiexec is: " $(which mpiexec)
   
        case $TARGET_BIN in
        /*) executable=$TARGET_BIN;;
        ./*) executable="$TARGET_BIN";;
        *) executable=$PSUBMIT_SUBDIR/$TARGET_BIN
           if [ ! -e $executable ]; then
               executable=$(which $TARGET_BIN)
           fi
           ;;
        esac 
        echo ">>> PSUBMIT: executable is: " $executable
        echo ">>> PSUBMIT: PWD=$PWD"
        if [ ! -z "$executable" -o ! -x "$executable" ]; then
            prefix="" 
            output="--output-filename out.$PSUBMIT_JOBID"
            vars="-x MPIEXEC -x MPIOPTS -x OMP_NUM_THREADS -x PATH -x LD_LIBRARY_PATH -x PSUBMIT_JOBID -x PSUBMIT_NP -x PSUBMIT_PPN -x PSUBMIT_NTH"
            [ -z "$machinefile" ] || unset SLURM_JOBID
            if [ -v MPIOPTS ]; then
                export MPIOPTS
                for opt in $(echo $MPIOPTS | tr ',' ' '); do
                    case $opt in
                    CUT_CUDA_OUT=*) optval=$(cut -d= -f2 <<< $opt | tr ':' ' ')
                                    for v in $optval; do
                                        export LD_LIBRARY_PATH=$(sed "s!$v[^:]*:!:!g" <<< $LD_LIBRARY_PATH)
                                    done
                                    ;;
                    UNSET_SLURM_ID) unset SLURM_JOBID;;
                    PREFIX)         prefix="--prefix $(dirname $(dirname $(which mpirun)))";;
                    NO_SPLIT_OUT)   output="";;
                    VARS=*)         optval=$(cut -d= -f2 <<< $opt | tr ':' ' ')
                                    for v in $optval; do
                                        if [ -v $v ]; then
                                            vars="$vars -x $v"
                                            export $v 
                                        fi
                                    done
                                    ;;
                    esac
                done
            fi
    
            time2=$(date +"%s");

            echo $- | grep -q x && omit_setx=true || set -x
            mpirun $vars $prefix $machinefile --bind-to none -np "$PSUBMIT_NP" --map-by ppr:$PSUBMIT_PPN:node $output "$executable" $ALL_ARGS
            { [ -z "$omit_setx" ] && set +x; } 2>/dev/null

            time3=$(date +"%s");
            walltime=$(expr $time3 - $time2)
            [ "$(expr $time3 - $time1)" -lt "2" ] && sleep $(expr 2 - $time3 + $time1)
            echo ">>> PSUBMIT: Walltime: $walltime"
        else
            echo ">>> PSUBMIT: ERROR: can't find or execute the program"
        fi
    fi
    [ -z "$PSUBMIT_RANK0" -a $(num_files_by_mask "out.$PSUBMIT_JOBID.*@1.$NUL.out") == "1" ] && export PSUBMIT_RANK0=$(echo out.$PSUBMIT_JOBID.*@1.$NUL.out)
    [ -z "$PSUBMIT_ERANK0" -a $(num_files_by_mask "out.$PSUBMIT_JOBID.*@1.$NUL.err") == "1" ] && export PSUBMIT_ERANK0=$(echo out.$PSUBMIT_JOBID.*@1.$NUL.err)
    [ -z "$PSUBMIT_POSTPROC" ] || source $PSUBMIT_POSTPROC
fi
