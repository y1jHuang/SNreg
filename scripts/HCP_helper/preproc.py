# this is the preprocessing line for HCP resting-state fMRI data
from HCP_helpers import *
exportFigs = True
config.rootPath = '/data/HCP'
# config is a global variable used by several functions
# Where does the HCP data live?
config.DATADIR = os.path.join(config.rootPath, 'hcp3T')

# list available runs
fmriRuns = ['rfMRI_REST1_LR', 'rfMRI_REST1_RL']

# which file to use for the functional data?
# the code #fMRIrun# will be replaced by the appropriate run
config.fmriFileTemplate = '#fMRIrun#_Atlas_MSMAll_hp2000_clean.dtseries.nii'
# parcellation for FC matrix
config.parcellationName = 'Glasser'  # used for easy reference
config.parcellationFile = '/data/brainAtlas/Glasser_et_al_2016_HCP_MMP1.0_kN_RVVG/HCP_PhaseTwo/Q1' \
                          '-Q6_RelatedValidation210/MNINonLinear/fsaverage_LR32k/Q1-Q6_RelatedValidation210' \
                          '.CorticalAreas_dil_Final_Final_Areas_Group_Colors.32k_fs_LR.dlabel.nii'
config.nParcels = 360
config.isCifti = True
# other naming conventions
config.movementRelativeRMSFile = 'Movement_RelativeRMS.txt'
config.movementRegressorsFile = 'Movement_Regressors_dt.txt'
# it is advisable to run the analyses on a cluster with sge
config.queue = False
parallelEnvironment = 'smp'  # 'openmp'

# load subjectsID
df = np.loadtxt(os.path.join(config.rootPath, 'subjectsID_SAVE.txt'), dtype=str)

#
checkPreproc = True
# turn this off to avoid lots of i/o, if you know all the subjects have been preprocessed already

# what2do has 6 possible values (it should be run with each)
# VA, VB, or VC:  volume, pipeline A, B or C
# SA, SB, or SC: surface, pipeline A, B or C
for what2do in ['SA']:
    print('\n------------\n' + what2do + '\n------------\n')
    if what2do[0] == 'S':
        # which file to use for the functional data?
        # the code #fMRIrun# will be replaced by the appropriate run
        # config.fmriFileTemplate = '#fMRIrun#_Atlas_MSMAll.dtseries.nii'
        # parcellation for FC matrix
        config.parcellationName = 'Glasser'  # used for easy reference
        #config.parcellationFile = '/scratch/duboisjx/data/parcellations/Glasser2016/Parcels.dlabel.nii'
        config.nParcels = 360
        config.isCifti = True
    elif what2do[0] == 'V':
        # which file to use for the functional data?
        # the code #fMRIrun# will be replaced by the appropriate run
        # config.fmriFileTemplate = '#fMRIrun#.nii.gz'
        # parcellation for FC matrix
        config.parcellationName = 'shen2013'
        config.parcellationFile = '/scratch/duboisjx/data/parcellations/shenetal_neuroimage2013_new/shen_2mm_268_parcellation.nii.gz'
        config.nParcels = 268
        config.isCifti = False
        config.maskParcelswithGM = False
        # add suffix indicating whether the parcels are masked with GM
        if config.maskParcelswithGM:
            config.parcellationName = config.parcellationName + '_GM'

    config.pipelineName = what2do[1:]
    # output directory
    outDir = op.join(config.outDir, 'preproc_'+config.pipelineName, config.parcellationName)
    if not op.isdir(outDir):
        makedirs(outDir)

    config.overwrite = True
    Operations = config.operationDict[config.pipelineName]
    if config.pipelineName in ['C', 'C0', 'D', 'D0', 'E', 'E0']:
        config.useFIX = True
    else:
        config.useFIX = False

    if checkPreproc:
        # for rep in range(3):  # pass through thrice to ensure no jobs failed
            config.scriptlist = list()
            keepSub = np.zeros((len(df)), dtype=np.bool_)
            iSub = 0
            print('Going through {} subjects, checking whether preprocessing was done'.format(df.shape[0]))
            printProgressBar(0, df.shape[0], prefix='Progress:', suffix='Complete', length=50)
            for subject in df:
                config.subject = subject
                iRun = 0
                for config.fmriRun in fmriRuns:
                    # if '2' in config.fmriRun:
                    #     config.Operations = Operations[0:4]
                    # else:
                    config.Operations = Operations
                    keepSub[iSub] = runPipelinePar(launchSubproc=False)
                    # # cifti smoothing, fwhm = 2.55
                    # surfFile_L = config.subject + '.L' + '.midthickness_MSMAll.32k_fs_LR.surf.gii'
                    # surfPath_L = op.join(config.DATADIR, config.subject, 'MNINonLinear', 'fsaverage_LR32k', surfFile_L)
                    # surfFile_R = config.subject + '.R' + '.midthickness_MSMAll.32k_fs_LR.surf.gii'
                    # surfPath_R = op.join(config.DATADIR, config.subject, 'MNINonLinear', 'fsaverage_LR32k', surfFile_R)
                    # prefix = config.session + '_' if hasattr(config, 'session') else ''
                    # oriFile = prefix + config.fmriRun + '_preproc'
                    # smoothFile = oriFile + '_smooth'
                    # surfKernal = 2.55
                    # volKernal = 2
                    # cmd = 'wb_command -cifti-smoothing {} {} {} {} {} -left-surface {} -right-surface {}'.format(
                    #       op.join(outpath(), oriFile + '.dtseries.nii'), surfKernal, volKernal, 'COLUMN',
                    #       op.join(outpath(), smoothFile + '.dtseries.nii'), surfPath_L, surfPath_R)
                    # call(cmd, shell=True)
                    if not keepSub[iSub]:
                        break
                    iRun = iRun + 1
                iSub = iSub + 1
                printProgressBar(iSub, df.shape[0], prefix='Progress:', suffix='Complete', length=50)
            # launch array job (if there is something to do)
            if len(config.scriptlist) > 1:
                if config.isCifti:
                    config.sgeopts = '-l mem_free=13G'.format(parallelEnvironment)
                else:
                    config.sgeopts = '-l mem_free=25G -pe {} 6'.format(parallelEnvironment)
                JobID = fnSubmitJobArrayFromJobList()
                print(
                'Running array job {} ({} sub jobs)'.format(JobID.split('.')[0],JobID.split('.')[1].split('-')[1].split(':')[0]))
                config.joblist.append(JobID.split('.')[0])
                checkProgress(pause=60, verbose=False)
            else:
                # if nothing needs to be done, no need to check again
                break
    else:
        keepSub = np.ones((len(df)), dtype=np.bool_)
        print('Keeping {}/{} subjects'.format(np.sum(keepSub), len(df)))
