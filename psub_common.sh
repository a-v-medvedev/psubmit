function psub_check_if_exited() {
	cat "$FILE_OUT" | awk -v NNODES=1 '/Exiting.../ { done++; if (done == NNODES) { exit 1; } } { next; }'
}

function psub_update_oldjobstatus() {
    [ -z "$jobstatus" ] && return 0
    if [ "$jobstatus" != "$oldjobstatus" ]; then echo "Job status: $jobstatus"; fi
    oldjobstatus=$jobstatus
}

function psub_common_set_paths() {
    PSUBMIT_PWD="$PWD"
    PSUBMIT_HOME="$HOME"
}

function psub_common_signal_timeout() {
    [ ! -f "$FILE_OUT" -o "$jobid" == "" ] && return
    local results="$PSUBMIT_RESDIR"
    local stackfile="$results/stacktrace.$jobid_short"
    [ ! -d "$results" ] && return
    [ -e "$stackfile" ] && return
    echo ">> STATUS: TIMEOUT" >> "$stackfile"
    return 0
}

function psub_common_move_outfiles() {
    [ ! -f "$FILE_OUT" -o "$jobid" == "" ] && return
    local dir="$PSUBMIT_PWD"
    local home="$PSUBMIT_HOME"
    [ -z "$PSUBMIT_RESDIR" ] && return
    [ -e "$PSUBMIT_RESDIR" ] && rm -rf "$PSUBMIT_RESDIR"
    mkdir -p $PSUBMIT_RESDIR
    if [ -f $FILE_OUT ]; then 
        mv $FILE_OUT $PSUBMIT_RESDIR
        oldpwd=$(pwd)
        cd $dir/
        ln -s $(basename $FILE_OUT) batch.${jobid_short}.out
        cd $oldpwd
    fi
    [ -f psubmit_wrapper_output.$jobid_short ] && mv psubmit_wrapper_output.$jobid_short $PSUBMIT_RESDIR
    [ -f hostfile.$jobid_short ] && mv hostfile.$jobid_short $PSUBMIT_RESDIR
    local rank0=""
    local erank_not_empty=""
    local r=$(ls -1d $dir/out.$jobid_short.* 2> /dev/null)
    local rr=$(ls -1d $dir/out.$jobid_short 2> /dev/null)
    if [ "$r" != "" -o "$rr" != "" ]; then
        [ -z "$r" ] || mv $dir/out.${jobid_short}.* $PSUBMIT_RESDIR
        [ -z "$rr" ] || mv $dir/out.${jobid_short} $PSUBMIT_RESDIR
        PSUBMIT_NP=$(expr $NNODES \* $PPN); PSUBMIT_JOBID=$jobid_short
        local f=$(. "$MPIEXEC" --show-rank0-out)
        local fe=$(. "$MPIEXEC" --show-rank0-err)
        [ ! -z "$f" -a -f "$PSUBMIT_RESDIR/$f" ] && { ln -s "$f" "$dir/$(basename $PSUBMIT_RESDIR)/rank0"; rank0="TRUE";}
        [ ! -z "$fe" -a -f "$PSUBMIT_RESDIR/$fe" ] && { ln -s "$fe" "$dir/$(basename $PSUBMIT_RESDIR)/erank0"; }
        erank_not_empty=$(. "$MPIEXEC" --has-err)
    fi
    r=$(ls -1d $dir/err.$jobid_short.* 2> /dev/null)
    if [ "$r" != "" ]; then
        erank_not_empty=$(. "$MPIEXEC" --has-err)
        mv $dir/err.$jobid_short.* $PSUBMIT_RESDIR
        PSUBMIT_NP=$(expr $NNODES \* $PPN); PSUBMIT_JOBID=$jobid_short
        local fe=$(. "$MPIEXEC" --show-rank0-err)
        [ ! -z "$fe" -a -f "$PSUBMIT_RESDIR/$fe" ] && { ln -s "$fe" "$dir/$(basename $PSUBMIT_RESDIR)/erank0"; }
    fi
    r=$(ls -1d $dir/*.${jobid_short}.* $dir/*.${jobid_short} 2> /dev/null)
    if [ "$r" != "" ]; then
        for f in $r; do
            x=$(basename $f | grep '^[^.]*\.'${jobid_short}'\.[^.]*$')
            [ -z "$x" ] || mv "$f" $PSUBMIT_RESDIR
            x=$(basename $f | grep '^.*\.'${jobid_short}'$')
            if [ "$x" != "$(basename $PSUBMIT_RESDIR)" ]; then
                [ -z "$x" ] || mv "$f" $PSUBMIT_RESDIR
            fi
        done
    fi
    echo "Results collected:" "$(basename $PSUBMIT_RESDIR)/"
    [ -z "$rank0" ] || echo "Rank 0 output:" $(basename $PSUBMIT_RESDIR)/rank0
    [ -z "$erank_not_empty" ] || echo "Rank 0 errout:" $(basename $PSUBMIT_RESDIR)/erank0
    echo "Batch system output:" $(basename $PSUBMIT_RESDIR)/$(basename $FILE_OUT)
    echo "Psubmit wrapper output:" $(basename $PSUBMIT_RESDIR)/psubmit_wrapper_output.$jobid_short
    if true; then
        echo -ne "\n--- Batch system output: ---\n"
        tail -n15 $PSUBMIT_RESDIR/$(basename $FILE_OUT)
        echo -ne "\n--- Psubmit wrapper output: ---\n"
        tail -n15 $PSUBMIT_RESDIR/psubmit_wrapper_output.$jobid_short
        if [ ! -z "$rank0" -a "$(cat $PSUBMIT_RESDIR/rank0 | wc -l)" != "0" ]; then
            echo -ne "\n--- Rank 0 output: ---\n" && tail -n15 $PSUBMIT_RESDIR/rank0;
        fi 
        [ -z "$erank_not_empty" ] || { echo -ne "\n--- Rank 0 errout: ---\n" && tail -n15 $PSUBMIT_RESDIR/erank0; }
        [ -z "$erank_not_empty" ] || echo -ne "\n--- NOTE: THERE ARE ERROR OUTPUT FILES\n"
    fi
    return 0
}

function psub_common_make_stackfile() {
	local stackdir=$PSUBMIT_RESDIR
    if [ -d "$PSUBMIT_RESDIR/out.$jobid_short" ]; then
		stackdir="$PSUBMIT_RESDIR/out.$jobid_short"
	fi
	rm -f __result.$jobid_short __stack.$jobid_short
	touch __stack.$jobid_short
	rm -f stacktrace.$jobid_short
	for f in $(find "$stackdir" -type f); do
		local ST
        egrep "(: Assertion .* failed.)" $f >> __result.$jobid_short && ST=1
        if [ -z "$ST" ]; then
    		egrep "(>> TIMEOUT)|(>> FATAL SIGNAL: [0-9]*)|(>> EXCEPTION)" $f >> __result.$jobid_short && ST=1;
        fi
		if [ ! -z "$ST" ]; then 
            if grep -q 'Stack trace:' $f ; then
			    echo "File: $f" >> __stack.$jobid_short
			    echo "" >> __stack.$jobid_short
			    cat $f | awk '/Stack trace:/{STAT=1} /-------------------------------------------/{ if (STAT==2) STAT=3; if (STAT==1) STAT=2; } STAT>0 { print; if (STAT==3) STAT=0 }' >> __stack.$jobid_short 
                echo "" >> __stack.$jobid_short
            fi
		fi
	done
    local lines=$(wc -l __result.$jobid_short | cut -d' ' -f1)
	if [ "$lines" != "0" ]; then
		local R=$(sort -u < __result.$jobid_short | head -n1)
		case "$R" in
			*">> T"*) echo -ne ">> STATUS: TIMEOUT\n\n" >> stacktrace.$jobid_short;;
			*">> E"*) echo -ne ">> STATUS: EXCEPTION\n\n" >> stacktrace.$jobid_short;;
			*">> F"*) echo -ne ">> STATUS: CRASH\n\n" >> stacktrace.$jobid_short;;
			*": As"*) echo -ne ">> STATUS: ASSERT\n\n" >> stacktrace.$jobid_short;;
			*) echo -ne "STATUS: ???\n\n" >> stacktrace.$jobid_short;;
		esac
		echo "$R" >> stacktrace.$jobid_short
		echo >> stacktrace.$jobid_short
		cat __stack.$jobid_short >> stacktrace.$jobid_short
		mv stacktrace.$jobid_short $PSUBMIT_RESDIR
	fi
	rm -f __result.$jobid_short __stack.$jobid_short
    return 0
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
    
