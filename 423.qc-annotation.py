#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
@author: Deng Chijun
"""

import os
import matplotlib.pyplot as plt
import matplotlib.image as mpimg

def plot_and_save_surfaces(subid, basedir, savedir):
    sub_dir = os.path.join(basedir, subid)
    img_files = [
        'lh.pial.left.png',
        'rh.pial.right.png',
        'lh.pial.right.png',
        'rh.pial.left.png'
    ]

    images = []
    for fname in img_files:
        fpath = os.path.join(sub_dir, fname)
        if not os.path.isfile(fpath):
            print(f"Warning: {fpath} not found for {subid}. Skipping...")
            return
        images.append(mpimg.imread(fpath))

    fig, axs = plt.subplots(2, 2, figsize=(8, 8))
    axs = axs.flatten()
    for i in range(4):
        axs[i].imshow(images[i])
        axs[i].axis('off')
        axs[i].set_title(img_files[i], fontsize=8)

    plt.tight_layout()
    save_path = os.path.join(savedir, f"{subid}.png")
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved: {subid}")

# process all sub- folders
root_dir = '/lustre/home/acct-medlf/medlf12/users/dengchijun/projects'
for cohort in ['SAED', 'ABIDE/ABIDE']:
    # dir
    basedir = f"{root_dir}/{cohort}/data/fsqc/surfaces"
    savedir = f"{root_dir}/{cohort}/data/fsqc/annotation_agg"
    os.makedirs(savedir, exist_ok=True)
    
    # List all subject
    sub_folders = sorted([f for f in os.listdir(basedir) if f.startswith("sub-") and os.path.isdir(os.path.join(basedir, f))])
    
    for subid in sub_folders:
        plot_and_save_surfaces(subid, basedir, savedir)
        
        
        
        