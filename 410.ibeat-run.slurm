#!/bin/bash

#SBATCH --job-name=infant_batch1
#SBATCH --partition=gpu
#SBATCH -N 1      
#SBATCH --gres=gpu:1  

#SBATCH --time=13-24:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=log/%x-%A-%a-%j.out
#SBATCH --error=log/%x-%A-%a-%j.err

# Load required modules
module load cuda/11.7
module load singularity/4.2.2 

# Batch
batch=1

# Set up directories
HOME_DIR=/home1/dengchijun
DATA_DIR=${HOME_DIR}/projects/SAED-INFANT-IBEAT/data
BIDS_DIR=${DATA_DIR}/raw
OUT_DIR=${DATA_DIR}/preprocessing
SCALE_DIR=${HOME_DIR}/projects/SAED-INFANT-IBEAT/scales/batches/saed_infant_batch${batch}.csv
SIMG_DIR=${HOME_DIR}/resources/singularity/ibeat_v2_r208.sif

# Create directories
mkdir -p "${OUT_DIR}"

# Define and export Singularity command
export SINGULARITY_CMD="singularity run -e --nv \
                        --pwd ${BIDS_DIR} \
                        -B ${BIDS_DIR}:/InfantData:ro \
                        -B ${OUT_DIR}:/OUT_DIR \
                        ${SIMG_DIR}"

# Processing function
process_subject() {
    local subid=$1
    local age=$2
    local gpu_id=0   # Single GPU...  $((RANDOM % 3))  # Randomly select GPU ID (0, 1, or 2)

    echo "Processing subject: ${subid}, Age: ${age} months"
    
    cmd=$(printf "%s " "${SINGULARITY_CMD}" \
        --t1 "${subid}_T1w.nii.gz" \
        --age "${age}" \
        --sub_name "${subid}" \
        --out_dir "/OUT_DIR" \
        --gpu_id "${gpu_id}" | tr -s ' ')
        

    echo "Command: ${cmd}"
    eval "${cmd}"
}


# Export function and variables
export -f process_subject
export BIDS_DIR OUT_DIR WORK_DIR SIMG_DIR

# Main processing loop
echo "Starting serial processing..."
tail -n +1 "${SCALE_DIR}" | while IFS=, read -r subid age; do
    # Skip empty lines or headers if needed
    if [[ -n "$subid" && "$subid" != "subid" ]]; then
        echo "Processing: ${subid}, Age: ${age}"
        process_subject "${subid}" "${age}"
    fi
done
echo "Processing completed."



