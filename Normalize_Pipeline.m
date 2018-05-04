function Normalize_Pipeline(smri_directory,varargin)
%Notes CYF 03132018
%Normalization pipeline that uses VBM8 to calculate transformation matrices
%from native to MNI space, then applies to multiple images co-registered to
%native T1
warning off all;
try
    for x=1:size(varargin,2)
        cfolder=char(deblank(varargin(x)));
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
        
        files=spm_select('FPList',cfolder,'.*.nii');
        if size(files,1)>1
            for a=1:size(files,1)
                seplocs=strfind(files(a,:),'-');
                fnum=files(a,seplocs(end):end);
                fname=sprintf('%s_04%d_%s%s',hdr{1,1}.PatientID,hdr{1,1}.SeriesNumber,strrep(hdr{1,1}.SeriesDescription,' ','_'),fnum);
                movefile(files(a,:),fullfile(cfolder,fname),'f');
            end
        else
            fname=sprintf('%s_04%d_%s.nii',hdr{1,1}.PatientID,hdr{1,1}.SeriesNumber,strrep(hdr{1,1}.SeriesDescription,' ','_'));
            movefile(files,fullfile(cfolder,fname),'f');
        end
        
        load(which('Normpipecoreg.mat'));
        files=spm_select('FPList',cfolder,'.*.nii');
        matlabbatch{1,1}.spm.spatial.coreg.estwrite.ref{1}=spm_select('FPList',smri_directory,'^head.nii$');
        matlabbatch{1,1}.spm.spatial.coreg.estwrite.source{1}=files(1,:);
        if size(files,1)>1,matlabbatch{1,1}.spm.spatial.coreg.estwrite.other=cellstr(files(2:end,:));
        else matlabbatch{1,1}.spm.spatial.coreg.estwrite.other{1}=[];
        end
        try
            spm_jobman('initcfg');
            spm_jobman('run',matlabbatch);
        end
        warpimages=spm_select('FPList',cfolder,'^r.*.nii');
        mkdir(fullfile(cfolder,'Normalized'));
        outputfolder=fullfile(cfolder,'Normalized');
        
        load(which('NormpipeApplyMat.mat'));
        matlabbatch{1,1}.spm.tools.vbm8.tools.defs.field1{1}=spm_select('FPList',smri_directory,'^anat2tpl.warp.field.nii');
        matlabbatch{1,1}.spm.tools.vbm8.tools.defs.images=cellstr(warpimages);
        try
            spm_jobman('initcfg');
            spm_jobman('run',matlabbatch);
        end
        files=spm_select('FPList',cfolder,'^wr.*.nii');
        for a=1:size(files,1)
            movefile(deblank(files(a,:)),outputfolder,'f');end
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