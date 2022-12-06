import os.path as op
import os
import numpy as np
from subprocess import call
from pathlib import Path
# initializaing parameters
scrptPath = Path(os.getcwd())
rootPath = scrptPath.parent.parent
dataPath = op.join(rootPath, 'denoise_A')
parcPath = op.join(rootPath, 'parc/Yeo/fslr32k')
surfFile_L = '/data/brainAtlas/Glasser_et_al_2016_HCP_MMP1.0_kN_RVVG' \
            '/Q1-Q6_RelatedValidation210/MNINonLinear/fsaverage_LR32k' \
            '/Q1-Q6_RelatedValidation210.L.inflated_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.surf.gii'
surfFile_R = '/data/brainAtlas/Glasser_et_al_2016_HCP_MMP1.0_kN_RVVG' \
            '/Q1-Q6_RelatedValidation210/MNINonLinear/fsaverage_LR32k' \
            '/Q1-Q6_RelatedValidation210.R.inflated_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.surf.gii'
labelFile = op.join(parcPath, 'Schaefer2018_400Parcels_Kong2022_17Networks_order.dlabel.nii')
fmriRuns = ['rfMRI_REST1_LR', 'rfMRI_REST1_RL']
fmriFile_tmp = '#fmriRuns#_preproc.dtseries.nii'
subIDFile = op.join(rootPath, 'subjectsID_SAVE.txt')
df = np.loadtxt(subIDFile, dtype=str)

# create border for Parcels_Kong2022_17Networks
# separate file into two hemisphere
left_tmp = op.join(parcPath, 'left_tmp.label.gii')
right_tmp = op.join(parcPath, 'right_tmp.label.gii')
cmd = 'wb_command -cifti-separate {} {} -label {} {} -label {} {}'.format(labelFile, 'COLUMN', 'CORTEX_LEFT', left_tmp, 'CORTEX_RIGHT', right_tmp)
call(cmd, shell=True)
# create border for left and right cortex respectively
border_left = op.join(parcPath, 'L.400Parcels_Kong2022_17Networks.border')
border_right = op.join(parcPath, 'R.400Parcels_Kong2022_17Networks.border')
cmd = 'wb_command -label-to-border {} {} {}'.format(surfFile_L, left_tmp, border_left)
call(cmd, shell=True)
cmd = 'wb_command -label-to-border {} {} {}'.format(surfFile_R, right_tmp, border_right)
call(cmd, shell=True)
# remove temporal file
cmd = 'rm {}'.format(left_tmp)
call(cmd, shell=True)
cmd = 'rm {}'.format(right_tmp)
call(cmd, shell=True)

# merge LR and RL file from REST1 and REST2 respectively, and convert each subject's dense scalar file to parcellated file
for subject in df:
    fmriFile = []
    for run in fmriRuns:
        fmriFile.append(op.join(dataPath, subject, run, fmriFile_tmp.replace('#fmriRuns#', run)))
    fmriFile_merge = op.join(dataPath, subject, run[0:11] +  '.dtseries.nii' )
    cmd = 'wb_command -cifti-merge {} {} {} {} {}'.format(fmriFile_merge, '-cifti', fmriFile[0], '-cifti', fmriFile[1])
    call(cmd, shell=True)

    fmriFile_parc = fmriFile_merge.replace('dtseries', 'ptseries')
    cmd = 'rm ' + fmriFile_parc
    call(cmd, shell=True)
    cmd = 'wb_command -cifti-parcellate {} {} {} {}'.format(fmriFile_merge, labelFile, 'COLUMN', fmriFile_parc)
    call(cmd, shell=True)

    cmd = 'rm ' + fmriFile_merge
    call(cmd, shell=True)
    print(subject)
