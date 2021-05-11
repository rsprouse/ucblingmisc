# `mfa` Docker image

The `mfa` Docker image contains the [Montreal Forced Aligner](https://github.com/MontrealCorpusTools/Montreal-Forced-Aligner) and includes the English pretrained model. This image packages MFA v1.0.1, which is the current stable version. Fixes for multiple bugs are also applied. 

The `mfa_align_single` script has been added as a convenient way to perform alignment of a single audio file. It is safe to run multiple simultaneous processes of `mfa_align_single` without creating name clashes of temporary files created by the aligner.

## Getting the image

To get the image for use with Docker:

```bash
docker pull public.ecr.aws/ucblx/phonlab/mfa:1.0.1
```

To use with singularity:

```bash
singularity pull docker://public.ecr.aws/ucblx/phonlab/mfa:1.0.1
```

Singularity converts the Docker image to its own format. The result is a single file named `mfa_1.0.1.sif`.

## Using the image in Docker

### Using `mfa_align`

The `mfa_align` executable performs alignment of a corpus. It is one of the tools included with MFA, and you can consult the MFA documentation for details on its usage.

To perform alignments with Docker it is necessary to map local files and directories on the host to locations in the container. Use the `-v` option to perform these mappings. One each is needed for the corpus directory, the dictionary file, and the output directory.

```bash
docker run \
    -v /path/to/corpus/:/corpus \    # map local corpus dir to /corpus in container
    -v /path/to/dictfile:/dict \     # map local dictionary file to /dict in container
    -v /path/to/outputdir/:/outdir \ # map local output dir to /outdir in container
    phonlab/mfa:1.0.1 \              # docker image
    mfa_align /corpus /dict english /outdir  # mfa_align command and args
```

### Using `mfa_align_single`

The `mfa_align_single` script is a wrapper for `mfa_align` that uses symlinks to create a mini corpus of one audio file and an associated transcript.

To use the `mfa_align_single` script an input .wav file must be identified, along with the dictionary file and output filename. It is recommended that you map the directory containing the .wav file rather than the .wav file itself. This makes it easier to keep the original filename, which is usually used to identify the transcript file. Normally the transcript file is located in the same directory as the audio file and its name differs only in the extension. When this is the case use the extension (including leading `.`) to identify the transcript file, e.g. `.lab` or `.txt`. If the transcript is not in the same directory as the input audio file or does not follow the naming convention, then you must specify the full path to the transcript file.

```bash
docker run \
    -v /home/ec2-user/corpus/:/audio \
    -v /home/ec2-user/dict.txt:/dict \
    -v /home/ec2-user/myout/:/outdir \
    phonlab/mfa:1.0.1 mfa_align_single \
    /audio/SN109_FIN_STRESS_006.wav .lab /dict english /outdir/SN109_FIN_STRESS_006.TextGrid
```

To get full details of running `mfa_align_single` do:

```bash
docker run phonlab/mfa:1.0.1 mfa_align_single --help
```

## Using the image in singularity

See the 'Getting started' section for instructions on pulling the image into singularity. Running the image in singularity is a little simpler than running in Docker since the local filesystem does not require mapping.

The equivalent of the `mfa_align` Docker command is:

```bash
singularity run \
    /path/to/mfa_1.0.1.sif \              # singularity image
    mfa_align /path/to/corpus /path/to/dict english /path/to/outdir  # mfa_align command and args
```

And the `mfa_align_single` equivalent is:

```bash
singularity run \
    phonlab/mfa:1.0.1 mfa_align_single \
    /path/to/mfa_1.0.1.sif \
    /path/to/SN109_FIN_STRESS_006.wav .lab /path/to/dict english /path/to/outdir/SN109_FIN_STRESS_006.TextGrid
```

## TODO

   - How do we use other pretrained models?
   - Will the container run out of space if the input files are large?
   - How do we debug failed alignments? Where do errors go in docker and in singularity?
   - Do we need to copy additional alignment artifacts, e.g. `oovs_found.txt`, when using `mfa_align_single`?
   - Check ownership of alignment outputs. Ownership by root is not desirable.
   - Keeping docker cleaned up
