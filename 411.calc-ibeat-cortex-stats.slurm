#!/bin/bash

#SBATCH --job-name=ibeat_stats
#SBATCH --partition=cpu
#SBATCH -N 1      

#SBATCH --time=6-24:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=log/%x-%A-%a-%j.out
#SBATCH --error=log/%x-%A-%a-%j.err

## Calculate cortical metrics of iBEAT-derived surfaces using Freesurfer functions
# @author: Deng Chijun

# === Configuration ===
ROOT_DIR="/lustre/home/acct-medlf/medlf12/users/dengchijun/projects/SAED-INFANT-IBEAT/data"
IBEAT_DIR="${ROOT_DIR}/preprocessing"
OUT_DIR="${ROOT_DIR}/stats"
MAX_JOBS=20

# === Setup FreeSurfer ===
export FREESURFER_HOME="/lustre/home/acct-medlf/medlf12/users/dengchijun/resources/packages/freesurfer_v8/freesurfer"
source "$FREESURFER_HOME/SetUpFreeSurfer.sh"
export SUBJECTS_DIR="${OUT_DIR}"

# === Copy fsaverage ONCE ===
if [ ! -d "${SUBJECTS_DIR}/fsaverage" ]; then
    cp -r "${FREESURFER_HOME}/subjects/fsaverage" "${SUBJECTS_DIR}/"
fi

# === List of Subjects ===
subjects=$(find "${IBEAT_DIR}" -maxdepth 1 -type d -name 'sub-*' | while read -r dir; do
    count=$(find "$dir" -maxdepth 1 -type f -name '*.vtk' | wc -l)
    if [ "$count" -eq 6 ]; then
        basename "$dir"
    fi
done)

# === Function to Process One Subject ===
process_subject() {
    subject=$1
    echo "[$(date)] Start processing $subject"

    # Freesurfer file structure
    mkdir -p "${SUBJECTS_DIR}/${subject}/surf"
    mkdir -p "${SUBJECTS_DIR}/${subject}/mri"
    mkdir -p "${SUBJECTS_DIR}/${subject}/label"

    # Copy surface.vtk files
    cp "${IBEAT_DIR}/${subject}"/*.vtk "${SUBJECTS_DIR}/${subject}/surf/"
    cp "${IBEAT_DIR}/${subject}/T1.nii.gz" "${SUBJECTS_DIR}/${subject}/mri/"

    for hemi in lh rh; do

        # Convert surface to freesurfer format
        # InnerSurf -> .white
        mris_convert ${SUBJECTS_DIR}/${subject}/surf/T1-iso-skullstripped-rmcere-tissue.${hemi}.InnerSurf.PhysicalSpace.vtk \
                     ${SUBJECTS_DIR}/${subject}/surf/${hemi}.white
       
        # OuterSurf -> .pial
        mris_convert ${SUBJECTS_DIR}/${subject}/surf/T1-iso-skullstripped-rmcere-tissue.${hemi}.OuterSurf.PhysicalSpace.vtk \
                     ${SUBJECTS_DIR}/${subject}/surf/${hemi}.pial

        # Change work dir to surf
        cd ${SUBJECTS_DIR}/${subject}/surf || exit 1

        # Copy smoothwm file
        cp ${hemi}.white ${hemi}.smoothwm

        # Inflate white surface
        mris_inflate ${hemi}.white ${hemi}.inflated

        # Curvature
        mris_curvature -seed 1234 -thresh .999 -n -a 5 -w -distances 10 10 ${hemi}.inflated

        # Sphere
        mris_sphere -seed 1234 ${hemi}.inflated ${hemi}.sphere

        # Register
        mris_register -curv ${hemi}.sphere \
                      ${FREESURFER_HOME}/average/${hemi}.folding.atlas.acfb40.noaparc.i12.2016-08-02.tif \
                      ${hemi}.sphere.reg

        # Annotation register
        mri_surf2surf \
            --srcsubject fsaverage \
            --trgsubject  ${subject} \
            --hemi ${hemi} \
            --sval-annot ${SUBJECTS_DIR}/fsaverage/label/${hemi}.aparc.annot \
            --tval "${SUBJECTS_DIR}/${subject}/label/${hemi}.aparc.annot"

        # Calculate cortical metrics
        # White surface area
        mris_place_surface --area-map ${hemi}.white ${hemi}.area

        # Pial surface area
        mris_place_surface --area-map ${hemi}.pial ${hemi}.area.pial

        # Thickness
        mris_place_surface --thickness ${hemi}.white ${hemi}.pial 20 5 ${hemi}.thickness

        # Curv
        mris_place_surface --curv-map ${hemi}.white 2 10 ${hemi}.curv

        # Volume
        mris_convert --volume2 ${hemi}.white ${hemi}.pial nolabel ${hemi}.volume

    done
    echo "[$(date)] Finished processing $subject"
}

export -f process_subject
export SUBJECTS_DIR FREESURFER_HOME

# === Parallel Execution ===
parallel -j $MAX_JOBS process_subject ::: $subjects
