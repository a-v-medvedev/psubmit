# psubmit
Set of shell scripts to submit batch jobs on various HPC systems in a generalized way.

File `psubmit.opt` is expected to be filled in. See `psubmit.opt.example` for the ideas on creating your own files.

The command line options that add or override settings of `psubmit.opt`:

- `-x` -- print debug trace (rather verbose)
- `-o psubmit_opt_file_name` -- use an alternative file name for the options file
- `-n NNODES` -- number of cluster nodes (assumed 1 if omitted)
- `-p PPN` -- number of MPI ranks per node
- `-t NTHREADS` -- number of OpenMP threads per rank
- `-e BINARY` -- override the `TARGET_BIN` settings of `psubmit.opt`
- `-a ARGS` -- arguments (as a single string literal) to pass to BINARY
- `-b preproc_script` -- override the `BEFORE` setting of `psubmit.opt`
- `-f postproc_script` -- override the `AFTER` setting of `psubmit.opt`
- `-l key=value:key=value:..` -- set up some parameters using key/value pair syntax
- `-u DIR` -- set up the subdirectory for `psubmit.opt` and `TARGET_BINARY` files
- `-s` -- omit the procedure of looking for stack trace files after execution

Please note, that options `-n`, `-p` and `-t` not only override the values given in `psubmit.opt` file, but also the values set in the `-l` option.

The parameters that can be set in a key-value form:

- `nnodes=NUM` -- overrides NNODES setting of psubmit.opt (but `-n NUM` option is of higher priority) 
- `ppn=NUM` -- overrides PPN setting of psubmit.opt (but `-p NUM` option is of higher priority)
- `nth=NUM` -- overrides NTH setting of psubmit.opt (but `-t NUM` option is of higher priority)
- `ngpus=NUM` -- overrides NGPUS setting of psubmit.opt
- `queue=STRING` -- overrides QUEUE setting of psubmit.opt
- `constraint=STRING` -- overrides CONSTRAINT setting of psubmit.opt
- `account=STRING` -- overrides ACCOUNT setting of psubmit.opt
- `nodetype=STRING` -- overrides NODETYPE setting of psubmit.opt
- `time=NUM` -- overrides TIME\_LIMIT setting of psubmit.opt
- `gres=STRING` -- overrides GENERIC\_RESOURCES setting of psubmit.opt
- `mpiexec=STRING` -- overrides MPIEXEC setting of psubmit.opt
- `batch=STRING` -- overrides BATCH setting of psubmit.opt
- `before=STRING` -- overrides BEFORE setting of psubmit.opt
- `after=STRING` -- overrides AFTER setting of psubmit.opt
- `subdir=STRING` -- overrides the command line option `-u DIR` 

