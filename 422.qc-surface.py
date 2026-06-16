#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
@author: Deng Chijun
"""

import nibabel.freesurfer.io as fsio
import pyvista as pv
import os
import numpy as np


# root_dir
HOME_DIR = '/lustre/home/acct-medlf/medlf12/users/dengchijun'

for cohort in ['SAED-ASD-TD', 'ABIDE/ABIDE']:

    DATA_DIR = f'{HOME_DIR}/projects/{cohort}/data'
    FS_DIR = f'{DATA_DIR}/preprocessing/freesurfer8'

    # savedir
    savedir = f'{DATA_DIR}/fssurf'
    os.makedirs(savedir, exist_ok=True)

    # Get list of subject folders starting with 'sub-'
    subs = [d for d in os.listdir(FS_DIR) if d.startswith('sub-') and os.path.isdir(os.path.join(FS_DIR, d))]

    for sub in subs:
        print(f'Visualizing {sub}')

        # File paths
        lh_pial_path = f'{FS_DIR}/{sub}/surf/lh.pial'
        lh_white_path = f'{FS_DIR}/{sub}/surf/lh.white'
        rh_pial_path = f'{FS_DIR}/{sub}/surf/rh.pial'
        rh_white_path = f'{FS_DIR}/{sub}/surf/rh.white'

        # Load and convert FreeSurfer surfaces to PyVista
        def load_mesh(path):
            coords, faces = fsio.read_geometry(path)
            faces_pv = np.hstack((np.full((faces.shape[0], 1), 3), faces)).astype(np.int32)
            mesh = pv.PolyData(coords, faces_pv)
            mesh.compute_normals(inplace=True, auto_orient_normals=True)
            return mesh

        lh_white = load_mesh(lh_white_path)
        lh_pial = load_mesh(lh_pial_path)
        rh_white = load_mesh(rh_white_path)
        rh_pial = load_mesh(rh_pial_path)

        # Setup 2x4 plotter
        plotter = pv.Plotter(shape=(2, 4), window_size=(2300, 1000))
        plotter.set_background("white")

        # Panel function
        def add_surface(mesh, row, col, title, view_vec):
            plotter.subplot(row, col)
            plotter.add_text(title, font_size=12)
            plotter.add_mesh(mesh, color='lightgray', smooth_shading=True)
            plotter.view_vector(view_vec)
            plotter.camera.zoom(1.4)

        # Add 8 panels
        add_surface(lh_white, 0, 0, 'LH White Lateral', [-1, 0, 0])
        add_surface(lh_white, 0, 1, 'LH White Medial', [1, 0, 0])
        add_surface(lh_pial, 0, 2, 'LH Pial Lateral', [-1, 0, 0])
        add_surface(lh_pial, 0, 3, 'LH Pial Medial', [1, 0, 0])

        add_surface(rh_white, 1, 0, 'RH White Lateral', [1, 0, 0])
        add_surface(rh_white, 1, 1, 'RH White Medial', [-1, 0, 0])
        add_surface(rh_pial, 1, 2, 'RH Pial Lateral', [1, 0, 0])
        add_surface(rh_pial, 1, 3, 'RH Pial Medial', [-1, 0, 0])

        plotter.show()
        plotter.screenshot(f"{savedir}/{sub}.png", window_size=(2300, 1000))
        plotter.close()