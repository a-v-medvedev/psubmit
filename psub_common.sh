function psub_check_if_exited() {
	cat "$FILE_OUT" | awk -v NNODES=1 '/Exiting.../ { done++; if (done == NNODES) { exit 1; } } { next; }'
}

function psub_update_oldjobstatus() {
    if [ "$jobstatus" != "$oldjobstatus" ]; then echo "Job status: $jobstatus"; fi
    oldjobstatus=$jobstatus
}

function psub_common_set_paths() {
    SCRATCH_PWD="$PWD"
    SCRATCH_HOME="$HOME"
}

function psub_common_move_outfiles() {
    [ ! -f "$FILE_OUT" -o "$jobid" == "" ] && return
    local dir="$SCRATCH_PWD"
    local home="$SCRATCH_HOME"
    mkdir -p $dir/results.$jobid_short
    mv $FILE_OUT $dir/results.$jobid_short
    mv psubmit_wrapper_output.$jobid_short $dir/results.$jobid_short
    local rank0=""
    local erank0=""
    local errfiles=""
    local r=$(ls -1 $dir/out.$jobid_short* 2> /dev/null)
    if [ "$r" != "" ]; then
        mv $dir/out.$jobid_short* $dir/results.$jobid_short
        PSUBMIT_NP=$(expr $NNODES \* $PPN)
        PSUBMIT_JOBID=$jobid_short
        local f=$(. "$MPIEXEC" --show-rank0-out)
        if [ "$f" != "" ]; then
            if [ -f "$dir/results.$jobid_short/$f" ]; then
                ln -s "$dir/results.$jobid_short/$f" "$dir/results.$jobid_short/rank0"
                rank0="TRUE"
            fi
        fi
    fi
    r=$(ls -1 $dir/err.$jobid_short* 2> /dev/null)
    if [ "$r" != "" ]; then
        mv $dir/err.$jobid_short* $dir/results.$jobid_short
        PSUBMIT_NP=$(expr $NNODES \* $PPN)
        PSUBMIT_JOBID=$jobid_short
        f=$(. "$MPIEXEC" --show-rank0-err)
        if [ "$f" != "" ]; then
            if [ -f "$dir/results.$jobid_short/$f" ]; then
                ln -s "$dir/results.$jobid_short/$f" "$dir/results.$jobid_short/erank0"
                erank0="TRUE"
            fi
        fi
        errfiles="TRUE"
    fi
    r=$(ls -1 $home/stack.* 2> /dev/null)
    if [ "$r" != "" ]; then
        mv  $home/stack.* $dir/results.$jobid_short
    fi
    r=$(ls -1 $dir/*.${jobid_short}.* 2> /dev/null)
    if [ "$r" != "" ]; then
        mv  $dir/*.${jobid_short}.* $dir/results.$jobid_short
    fi
    echo "Results collected:" $dir/results.$jobid_short
    [ -z "$rank0" ] || echo "Rank 0 output:" $dir/results.$jobid_short/rank0
    [ -z "$erank0" ] || echo "Rank 0 errout:" $dir/results.$jobid_short/erank0
    echo "Batch system output:" $dir/results.$jobid_short/`basename $FILE_OUT`
    echo "Psubmit wrapper output:" $dir/results.$jobid_short/psubmit_wrapper_output.$jobid_short
    if true; then
        echo -ne "\n--- Batch system output: ---\n"
        tail -n15 $dir/results.$jobid_short/$(basename $FILE_OUT)
        echo -ne "\n--- Psubmit wrapper output: ---\n"
        tail -n15 $dir/results.$jobid_short/psubmit_wrapper_output.$jobid_short
        [ -z "$rank0" ] || ( echo -ne "\n--- Rank 0 output: ---\n" && tail -n15 $dir/results.$jobid_short/rank0 )
        [ -z "$erank0" ] || ( echo -ne "\n--- Rank 0 errout: ---\n" && tail -n15 $dir/results.$jobid_short/erank0 )
        [ -z "$errfiles" ] || ( echo -ne "\n--- NOTE: THERE ARE ERROR OUTPUT FILES\n" && cat $dir/results.$jobid_short/err.$jobid_short.* | head )
    fi
}

function psub_common_cleanup() {
    echo "CLEANUP..."
    psub_cancel
    sleep 1
    psub_move_outfiles
    rm -f "$OUTFILE" 
    echo "CLEANUP DONE"
    exit 1
}
    
