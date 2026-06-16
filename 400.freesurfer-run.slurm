#!/bin/bash

#SBATCH --job-name=t1w_freesurfer_batch1
#SBATCH --partition=cpu
#SBATCH -N 1
#SBATCH -n 40
#SBATCH --ntasks-per-node=40
#SBATCH --time=6-24:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=log/%x-%A-%a-%j.out
#SBATCH --error=log/%x-%A-%a-%j.err

# ---------------------
# Set batch number
batch=1

# Set up directories
HOME_DIR=/lustre/home/acct-medlf/medlf12/users/dengchijun
DATA_DIR=${HOME_DIR}/projects/SAED-ASD-TD/data
BIDS_DIR=${DATA_DIR}/raw
OUT_DIR=${DATA_DIR}/preprocessing/freesurfer8
SCALE_FILE=${HOME_DIR}/projects/SAED-ASD-TD/scales/anat/t1w_batch${batch}.csv

# Create output directory
mkdir -p "${OUT_DIR}"

# Setup FreeSurfer
export FREESURFER_HOME=${HOME_DIR}/resources/packages/freesurfer_v8/freesurfer
export SUBJECTS_DIR=${OUT_DIR}
source ${FREESURFER_HOME}/SetUpFreeSurfer.sh

# ---------------------
# Function to run recon-all for a single subject
run_recon() {
  subid="$1"
  img="${BIDS_DIR}/${subid}/anat/${subid}_T1w.nii.gz"

  if [[ ! -f "$img" ]]; then
    img="${BIDS_DIR}/${subid}/anat/${subid}_run-01_T1w.nii.gz"
  fi
  if [[ ! -f "$img" ]]; then
    img="${BIDS_DIR}/${subid}/anat/${subid}_run-02_T1w.nii.gz"
  fi
  if [[ ! -f "$img" ]]; then
    echo "No T1w image found for ${subid}"
    return
  fi

  echo "Running FreeSurfer for ${subid}"
  recon-all -s "${subid}" -i "${img}" -all
}

export -f run_recon
export BIDS_DIR OUT_DIR FREESURFER_HOME SUBJECTS_DIR

# ---------------------
# Run recon in parallel (5 jobs at a time)
cut -d',' -f1 "$SCALE_FILE" | parallel -j 5 run_recon

