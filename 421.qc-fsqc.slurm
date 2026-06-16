#!/bin/bash

#SBATCH --job-name=fsqc
#SBATCH --partition=cpu
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --ntasks-per-node=40
#SBATCH --time=6-24:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=log/%x-%A-%j.out
#SBATCH --error=log/%x-%A-%j.err

# Set up directories
HOME_DIR=/lustre/home/acct-medlf/medlf12/users/dengchijun
DATA_DIR=${HOME_DIR}/projects/ABIDE/ABIDE/data  # BIDS DIR (ABIDE/SAED)
OUT_DIR=${DATA_DIR}/preprocessing/freesurfer8
QC_DIR=${DATA_DIR}/fsqc
SIMG_DIR=${HOME_DIR}/resources/singularity/fsqc_v211.sif

mkdir -p "${QC_DIR}"

# Find all subject folders
subjects=($(find "${OUT_DIR}" -maxdepth 1 -type d -name "sub-*" -exec basename {} \; | sort))

# Split subjects into 20 comma-separated chunks
num_jobs=20
num_subjects=${#subjects[@]}
subjects_per_job=$(( (num_subjects + num_jobs - 1) / num_jobs ))

chunks=()
for ((i=0; i<num_subjects; i+=subjects_per_job)); do
    chunk=$(IFS=,; echo "${subjects[@]:i:subjects_per_job}")
    chunks+=("$chunk")
done

# Function to run fsqc on a chunk
run_fsqc() {
    subject_list="$1"
    # Templateflow command
    cmd="singularity run --cleanenv -B ${OUT_DIR}:/out:ro -B ${QC_DIR}:/qc ${SIMG_DIR} \
        --subjects_dir /out --output_dir /qc \
        --subjects ${subject_list} \
        --screenshots \
        --screenshots_views x=-40 x=-30 x=-20 x=-10 x=0 x=10 x=20 x=30 x=40 \
                            y=-40 y=-30 y=-20 y=-10 y=0 y=10 y=20 y=30 y=40 \
                            z=-40 z=-30 z=-20 z=-10 z=0 z=10 z=20 z=30 z=40 \
        --screenshots_layout 3 9 \
        --surfaces  \
        --skullstrip \
        --skip-existing"

    echo Commandline: ${cmd}
    eval $cmd
}

export -f run_fsqc
export OUT_DIR QC_DIR SIMG_DIR

# Run in parallel (one job per sublist)
parallel -j ${#chunks[@]} run_fsqc ::: "${chunks[@]}"

