function Normalize_Pipeline(T1folder,varargin)
%Notes CYF 03132018
%Normalization pipeline that uses VBM8 to calculate transformation matrices
%from native to MNI space, then applies to multiple images co-registered to
%native T1
warning off all;
try
    if ~exist(fullfile(deblank(T1folder),'../output'))
        mkdir(fullfile(deblank(T1folder),'../output'));
    end
    outputfolder=fullfile(deblank(T1folder),'../output');
    
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
    fname=sprintf('%s_%04d_%s.nii',hdr{1,1}.PatientID,hdr{1,1}.SeriesNumber,hdr{1,1}.SeriesDescription);
    movefile(spm_select('FPList',deblank(T1folder),'.*.nii'),fullfile(deblank(T1folder),fname),'f');
    
    
    load(which('NormpipeVBMest.mat'));
    matlabbatch{1}.spm.tools.vbm8.estwrite.data{1} = spm_select('FPList',deblank(T1folder),'.*.nii');
    matlabbatch{1}.spm.tools.vbm8.estwrite.extopts.dartelwarp.normhigh.darteltpm   = {which('Template_1_IXI550_MNI152.nii')};%070815 changed
    matlabbatch{1}.spm.tools.vbm8.estwrite.opts.tpm       = {which('TPM.nii')};%070815 changed
    try
        spm_jobman('initcfg');
        spm_jobman('run_nogui',matlabbatch);
    end
    
    for k=1:length(varargin)
        cfolder=deblank(varargin{k});
        cd(cfolder);
        disp(sprintf('Currently processing folder %d/%d: %s\n',k,length(varargin),cfolder));
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
    
        load(which('Normpipecoreg.mat'));
        matlabbatch{1,1}.spm.spatial.coreg.estimate.ref{1}=spm_select('FPList',deblank(T1folder),'.*.nii');
        matlabbatch{1,1}.spm.spatial.coreg.estimate.source{1}=spm_select('FPList',cfolder,'.*.nii');
        try
            spm_jobman('initcfg');
            spm_jobman('run_nogui',matlabbatch);
        end
        warpimages{k}=spm_select('FPList',cfolder,'.*.nii');
    end
    
    warpimages{k+1}=spm_select('FPList',T1folder,'^s.*.nii');
    
    load(which('NormpipeApplyMat.mat'));
    matlabbatch{1,1}.spm.tools.vbm8.tools.defs.field1{1}=spm_select('FPList',deblank(T1folder),'^y.*.nii');
    matlabbatch{1,1}.spm.tools.vbm8.tools.defs.images=warpimages;
    try
        spm_jobman('initcfg');
        spm_jobman('run_nogui',matlabbatch);
    end
    
    for k=1:length(varargin)
        cfolder=deblank(varargin{k});
        movefile(spm_select('FPList',cfolder,'^w.*.nii'),outputfolder,'f');
    end
    
    files=strvcat(spm_select('FPList',deblank(T1folder),'^m0wrp.*.nii'),spm_select('FPList',deblank(T1folder),'y_r.*.nii'),spm_select('FPList',deblank(T1folder),'^wmr.*.nii'));
    for n=1:size(files,1)
        movefile(deblank(files(n,:)),outputfolder,'f');
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