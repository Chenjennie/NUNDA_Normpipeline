function T1VBM(T1folder)

warning off all;
try
    if ~exist(fullfile(deblank(T1folder),'output'))
        mkdir(fullfile(deblank(T1folder),'output'));
    end
    outputfolder=fullfile(deblank(T1folder),'output');
    
    cd(deblank(T1folder));
    files=spm_select('FPList',deblank(T1folder),'.*');
    doscmd=sprintf('gdcm gdcminfo %s',files(1,:));[status,cmdout]=dos(doscmd);
    %Convert enhanced dicom to standard dicom
    if strfind(cmdout,'Enhanced')
        display('Enhanced DICOM detected. Converting to standard DICOMS...\n');
        fullfolder=fullfile(deblank(T1folder),'Standard');
        if exist(fullfolder,'dir')~=7
            mkdir(fullfolder);
        end
        
        doscmd=sprintf('emf2sf --out-dir %s %s',fullfolder,files(1,:));
        dos(doscmd);
        T1folder=fullfolder;
    end
    
    %Get header info & convert to NIFTI
    disp('Converting T1 DICOMs to NIFTI...\n');
    files=spm_select('FPList',deblank(T1folder),'.*');
    display('Reading DICOM headers...\n');
    hdr=spm_dicom_headers(files);
    display('Done!\n');
    spm_dicom_convertP50(hdr,'all','flat','nii');
    fname=sprintf('%s_origT1.nii',hdr{1,1}.PatientID);
    movefile(spm_select('FPList',deblank(T1folder),'.*.nii'),fullfile(deblank(outputfolder),fname),'f');
        
    load('/projects/p20394/software/pipeline_external/DEV_StdASL/NormpipeVBMest.mat');
    matlabbatch{1}.spm.tools.vbm8.estwrite.data{1} = spm_select('FPList',deblank(outputfolder),fname);
    matlabbatch{1}.spm.tools.vbm8.estwrite.extopts.dartelwarp.normhigh.darteltpm   = {which('Template_1_IXI550_MNI152.nii')};%070815 changed
    matlabbatch{1}.spm.tools.vbm8.estwrite.opts.tpm       = {which('TPM.nii')};%070815 changed
        matlabbatch{1}.spm.tools.vbm8.estwrite.extopts.dartelwarp.normhigh.darteltpm
        matlabbatch{1}.spm.tools.vbm8.estwrite.opts.tpm

    try
        spm_jobman('initcfg');
        spm_jobman('run_nogui',matlabbatch);
    end
    
catch err
    disp(err.message);
    disp(err.identifier);
    for k=1:length(err.stack)
        fprintf('In %s at %d\n',err.stack(k).file,err.stack(k).line);
    end
    %exit;
end
return;
