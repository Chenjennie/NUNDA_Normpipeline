function Normalize_Pipeline(T1VBM,inputscan)
%Notes CYF 03132018
%Normalization pipeline that uses VBM8 to calculate transformation matrices
%from native to MNI space, then applies to multiple images co-registered to
%native T1
warning off all;
try
    
    cfolder=deblank(inputscan);
    cd(cfolder);
    disp(sprintf('Currently processing folder %s\n',cfolder));
    files=spm_select('FPList',cfolder,'.*');
    doscmd=sprintf('gdcm gdcminfo %s',files(1,:));[status,cmdout]=dos(doscmd);
    %Convert enhanced dicom to standard dicom
    if strfind(cmdout,'Enhanced')
        display('Enhanced DICOM detected. Converting to standard DICOMS...\n');
        fullfolder=fullfile(cfolder,'Standard');
        if exist(fullfolder,'dir')~=7
            mkdir(fullfolder);
        end
        
        doscmd=sprintf('emf2sf --out-dir %s %s',fullfolder,files(1,:));
        dos(doscmd);
        cfolder=fullfolder;
    end
    
    %Get header info & convert to NIFTI
    disp(sprintf('Converting DICOMs to NIFTI in %s...\n',cfolder));
    files=spm_select('FPList',cfolder,'.*');
    display('Reading DICOM headers...\n');
    hdr=spm_dicom_headers(files);
    display('Done!\n');
    spm_dicom_convertP50(hdr,'all','flat','nii');
    
    fname=sprintf('%s_04%d_%s.nii',hdr{1,1}.PatientID,hdr{1,1}.SeriesNumber,hdr{1,1}.SeriesDescription);
    movefile(spm_select('FPList',cfolder,'.*.nii'),fullfile(cfolder,fname),'f');
    
    load('/projects/p20394/software/pipeline_external/DEV_StdASL/Normpipecoreg.mat');
    matlabbatch{1,1}.spm.spatial.coreg.estwrite.ref{1}=spm_select('FPList',T1VBM,['^',hdr{1,1}.PatientID,'_origT1.nii$']);
    matlabbatch{1,1}.spm.spatial.coreg.estwrite.source{1}=spm_select('FPList',cfolder,fname);
    try
        spm_jobman('initcfg');
        spm_jobman('run_nogui',matlabbatch);
    end
    warpimages=spm_select('FPList',cfolder,'^r.*.nii');
    mkdir(fullfile(cfolder,'Normalized'));
    outputfolder=fullfile(cfolder,'Normalized');
    
    load('/projects/p20394/software/pipeline_external/DEV_StdASL/NormpipeApplyMat.mat');
    matlabbatch{1,1}.spm.tools.vbm8.tools.defs.field1{1}=spm_select('FPList',T1VBM,'^y.*.nii');
    matlabbatch{1,1}.spm.tools.vbm8.tools.defs.images=cellstr(warpimages);
    try
        spm_jobman('initcfg');
        spm_jobman('run_nogui',matlabbatch);
    end
    
    movefile(spm_select('FPList',cfolder,'^wr.*.nii'),outputfolder,'f');
    
catch err
    disp(err.message);
    disp(err.identifier);
    for k=1:length(err.stack)
        fprintf('In %s at %d\n',err.stack(k).file,err.stack(k).line);
    end
    %exit;
end
return;