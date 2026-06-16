#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
@author: Deng Chijun
"""

import os
import subprocess
from glob import glob
import pandas as pd
from concurrent.futures import ProcessPoolExecutor, as_completed

## Global parameters
N_PARALLEL = 32       
N_CORES = '1'        

root_dir = '/lustre/home/acct-medlf/medlf12/users/dengchijun/projects/geneseq'
prs_dir = f'{root_dir}/code/PRScsx/PRScsx.py'
plink2 = f'{root_dir}/plink2/plink2'
ref_dir = f'{root_dir}/ld_ref'
pop = 'EUR'
bim_prefix = f'{root_dir}/genotype/step9_rsid_unique'
phi = '1e-2'

gwas_dir = f'{root_dir}/GWAS_TRIATS/EUR/hg38'
gwas_info = pd.read_csv(f'{root_dir}/GWAS_TRIATS/EUR/sample_sizes.csv', index_col=0)
files = [f for f in os.listdir(gwas_dir) if f.endswith(".txt")]

## Worker function
def run_prscsx(fname):
    # --- Thread control (must be inside worker) ---
    os.environ['MKL_NUM_THREADS'] = N_CORES
    os.environ['NUMEXPR_NUM_THREADS'] = N_CORES
    os.environ['OMP_NUM_THREADS'] = N_CORES

    sst_file = os.path.join(gwas_dir, fname)
    trait = fname.removesuffix('.hg38.txt')
    n_gwas = gwas_info.loc[trait, 'N']

    out_dir = f'{root_dir}/PRS/PRScsx/EUR/{trait}'
    os.makedirs(out_dir, exist_ok=True)

    # PRS-CSX
    cmd = f"""
    python {prs_dir} \
        --ref_dir={ref_dir} \
        --bim_prefix={bim_prefix} \
        --sst_file={sst_file} \
        --n_gwas={n_gwas} \
        --pop={pop} \
        --phi={phi} \
        --out_dir={out_dir} \
        --out_name={trait} \
        --seed=42
    """

    print(f"[{trait}] Running PRS-CSX")
    subprocess.run(cmd, shell=True, check=True)

    # Merge weights
    weight_files = sorted(glob(f"{out_dir}/{trait}_*pst_eff_*chr*.txt"))
    merged_weights = f"{out_dir}/{trait}_PRSCSX_weights.txt"

    with open(merged_weights, "w") as fout:
        for wf in weight_files:
            with open(wf) as fin:
                fout.writelines(fin)
                
    # PLINK score
    plink_cmd_sum = [
        plink2,
        "--bfile", bim_prefix,
        "--score", merged_weights, "2", "4", "6", "cols=+scoresums",
        "--out", f"{out_dir}/PRS_sum_score_{trait}"
    ]

    subprocess.run(plink_cmd_sum, check=True)

    print(f"[{trait}] Finished successfully")
    return trait


## Parallel execution
if __name__ == "__main__":
    print(f"Running PRS-CSX with {N_PARALLEL} parallel jobs")

    with ProcessPoolExecutor(max_workers=N_PARALLEL) as executor:
        futures = {executor.submit(run_prscsx, f): f for f in files}

        for fut in as_completed(futures):
            fname = futures[fut]
            try:
                trait = fut.result()
                print(f"[DONE] {trait}")
            except Exception as e:
                print(f"[FAILED] {fname}: {e}")

    print("ALL PRS calculations finished")