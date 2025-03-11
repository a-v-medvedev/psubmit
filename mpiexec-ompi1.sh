dir=out.$PSUBMIT_JOBID
rm -rf "$dir"

time1=$(date +"%s")

ALL_ARGS=$(eval echo '' $*)
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_JOBID%/$PSUBMIT_JOBID/g")
ALL_ARGS=$(echo $ALL_ARGS | sed "s/%PSUBMIT_NP%/$PSUBMIT_NP/g")

NUL="0"
[ "$PSUBMIT_NP" -gt 10 ] && NUL="00"
[ "$PSUBMIT_NP" -gt 100 ] && NUL="000"
[ "$PSUBMIT_NP" -gt 1000 ] && NUL="0000"
[ "$PSUBMIT_NP" -gt 10000 ] && NUL="00000"
export PSUBMIT_RANK0="out.${PSUBMIT_JOBID}.1.$NUL"
export PSUBMIT_ERANK0="err.${PSUBMIT_JOBID}.1.$NUL"

if [ "$ALL_ARGS" == "--show-rank0-out" ]; then
    echo "$PSUBMIT_RANK0"
elif [ "$ALL_ARGS" == "--show-rank0-err" ]; then
    echo "$PSUBMIT_ERANK0"
elif [ "$ALL_ARGS" == "--has-err" ]; then
    if [ ! -z "$(ls -1d err.$PSUBMIT_JOBID.1.* 2>/dev/null)" ]; then
        allnull=1; for i in err.$PSUBMIT_JOBID.1.*; do [ "$(cat $i | wc -l)" == "0" ] || allnull=0; done;
        [ "$allnull" == "1" ] || echo TRUE
    fi
else

    [ "$ALL_ARGS" == "--" ] && ALL_ARGS=""

    [ -z "$ALL_ARGS" ] || export PSUBMIT_ARGS="$ALL_ARGS"

    # The line below is to cut off CUDA from the environment
    #LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed 's!/opt/cuda[^:]*:!:!g'`

    export PSUBMIT_JOBID PSUBMIT_NP
    [ -z "$PSUBMIT_PREPROC" ] || source $PSUBMIT_PREPROC

    if [ "$TARGET_BIN" != "false" ]; then
        echo ">>> PSUBMIT: mpirun is: " $(which mpirun)
        case $TARGET_BIN in
        /*)  executable=$TARGET_BIN;;
        ./*) executable="$TARGET_BIN";;
        *)   executable=$PSUBMIT_SUBDIR/$TARGET_BIN
             if [ ! -e $executable ]; then
                 executable=$(which $TARGET_BIN)
             fi
             ;;
        esac
        echo ">>> PSUBMIT: Executable is: " $executable
        if [ ! -z "$executable" -o ! -x "$executable" ]; then
            echo ">>> PSUBMIT: Executable is: " $(which $executable)
            
            time2=$(date +"%s");

            echo $- | grep -q x && omit_setx=true || set -x
            mpirun --bind-to core -np "$PSUBMIT_NP" --map-by ppr:$PSUBMIT_PPN:node -output-filename out.$PSUBMIT_JOBID "$executable" $ALL_ARGS
            { [ -z "$omit_setx" ] && set +x; } 2>/dev/null

            time3=$(date +"%s");
            [ "$(expr $time3 - $time1)" -lt "2" ] && sleep $(expr 2 - $time3 + $time1)
            echo ">>> PSUBMIT: Walltime: $walltime"
        else
            echo ">>> PSUBMIT: ERROR: can't find or execute the program"
        fi
    fi
	[ -z "$PSUBMIT_POSTPROC" ] || source $PSUBMIT_POSTPROC
fi
