#!/bin/bash

#SBATCH --job-name=mriqc
#SBATCH --partition=cpu
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --ntasks-per-node=40
#SBATCH --time=6-24:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=log/%x-%A-%j.out
#SBATCH --error=log/%x-%A-%j.err

batch=1

# Set up directories
HOME_DIR=/lustre/home/acct-medlf/medlf12
DATA_DIR=${HOME_DIR}/users/dengchijun/projects/SAED-ASD-TD/data
BIDS_DIR=${DATA_DIR}/raw
OUT_DIR=${DATA_DIR}/mriqc
WORK_DIR=${HOME_DIR}/users/dengchijun/work/mriqc_saed
SIMG_DIR=${HOME_DIR}/users/dengchijun/resources/singularity/mriqc_24.0.2.sif
SCALE_FILE=${HOME_DIR}/users/dengchijun/projects/SAED-ASD-TD/scales/mriqc/mriqc_batch${batch}.csv

mkdir -p "$OUT_DIR"
mkdir -p "$WORK_DIR"

# Function to run MRIQC on one subject group
mapfile -t subject_list < "$SCALE_FILE"

# Function to run MRIQC for one subject
run_mriqc() {
    subject_id="$1"
    cmd="singularity run --cleanenv \
            -B ${BIDS_DIR}:/data:ro \
            -B ${OUT_DIR}:/out \
            ${SIMG_DIR} \
            /data /out participant \
            --participant-label ${subject_id} \
            --work-dir ${WORK_DIR} \
            --omp-nthreads 1 \
            --nprocs 1 \
            --no-sub"
        echo "Running MRIQC for ${subject_id}"
        eval $cmd
}

export -f run_mriqc
export BIDS_DIR OUT_DIR WORK_DIR SIMG_DIR

# Run in parallel with 30 concurrent subjects
printf "%s\n" "${subject_list[@]}" | parallel -j 30 run_mriqc
