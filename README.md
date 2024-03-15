# psubmit
Set of shell scripts to submit batch jobs on various HPC systems in a generalized way.

File `psubmit.opt` is expected to be filled in. See `psubmit.opt.example` for the ideas on creating your own files.

The command line options that add or override settings of `psubmit.opt`:

- `-x` -- print debug trace (rather verbose)
- `-o psubmit_opt_file_name` -- use an alternative file name for the options file
- `-n NNODES` -- mandatory parameter: number of cluster nodes
- `-p PPN` -- number of MPI ranks per node
- `-t NTHREADS` -- number of OpenMP threads per rank
- `-e BINARY` -- override the `TARGET_BIN` settings of `psubmit.opt`
- `-a ARGS` -- arguments (as a single string literal) to pass to BINARY
- `-b preproc_script` -- override the `BEFORE` setting of `psubmit.opt`
- `-f postproc_script` -- override the `AFTER` setting of `psubmit.opt`


