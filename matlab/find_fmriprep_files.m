function [subjectFiles] = find_fmriprep_files(fmriPrepPath, subjectSubset)
%% [subjectFiles] = FIND_FMRIPREP_FILES(fmriprepPath)

% Written by Kelly Chang - February 15, 2022

%% Input Control

%%% Exist: Check is 'fmriPrepPath' exists. 
if ~exist('fmriPrepPath', 'var') || isempty(fmriPrepPath)
    error('Cannot provide empty ''fmriPrepPath''.');
end

%%% Exists: Check if 'fmriPrepPath' exists on disk.
if ~isfolder(fmriPrepPath)
    error('Unable to locate directort ''%s''.', fmriPrepPath);
end

%%% Exists: Check if 'subjectList' exists.
if ~exist('subjectSubset', 'var') || isempty(subjectSubset)
    subjectSubset = {}; 
end

%%% Format: Check 'subjectList' data type.
if ischar(subjectSubset)
    subjectSubset = {subjectSubset}; 
end

%% File Type Patterns

% valid fMRIPrep surfaces file types
surfTypes = {'midthickness', 'pial', 'smoothwm'}; 

% file types and corresponding matching regular expression patterns.
filePat.anat = ['anat\', filesep, '[\w-]+_desc-preproc_T1w\.nii\.gz'];
filePat.surf = ['anat\', filesep, '[\w-]+_(', strjoin(surfTypes,'|'), ')\.surf\.gii'];
filePat.vtc = ['func\', filesep, '[\w-]+_desc-preproc_bold\.nii\.gz'];
filePat.mtc = ['func\', filesep, '[\w-]+_bold\.func\.gii'];
filePat.confounds = ['func\', filesep, '[\w-]+_desc-confounds_timeseries\.tsv'];
filePat.surf2anat = ['anat\', filesep, '[\w-]+_from-fsnative_to-T1w_mode-image_xfm\.txt'];

%% Locate fMRIPrep Files by Subject

subjectList = dir(fullfile(fmriPrepPath, 'sub-*'));
subjectList = subjectList([subjectList.isdir]);
subjectList = {subjectList.name}; % extract subject labels

if ~isempty(subjectSubset) % extract subject subset (optional)
    subjectIndx = ismember(subjectList, subjectSubset); 
    subjectList = subjectList(subjectIndx); 
end

subjectList = fullfile(fmriPrepPath, subjectList);

for i = 1:length(subjectList) % for each subject
    [~,subjectName] = extract_fileparts(subjectList{i});
    
    fileList = dir(fullfile(subjectList{i}, '**', '*.*'));
    fileList = fileList(~[fileList.isdir]); % exclude directories
    fileList = fullfile({fileList.folder}, {fileList.name});
    
    clear s; s.subject = subjectName; % temporary structure
    p = structfun(@(x) fileList(regexp_contains(fileList,x)), ...
        filePat, 'UniformOutput', false); 
    if ~isempty(p.surf2anat); p.surf2anat = char(p.surf2anat); end
    subjectFiles(i) = structassign(s, p);
end

%% Create BrainVoyager Derivatives Directories and File Names

[basePath,~,~] = extract_fileparts(fmriPrepPath);
bvPath = fullfile(basePath, 'brainvoyager'); 
mkfolder(bvPath); % create brainvoyager directory

for i = 1:length(subjectFiles) % for each subject
    p = subjectFiles(i); % current subject
    
    out = struct(); % initialize 
    
    % subject brainvoyager directory
    out.subject = fullfile(bvPath, p.subject);
    
    if ~isempty(p.anat) || ~isempty(p.surf)
        anatDir = fullfile(out.subject, 'anat');
        mkfolder(anatDir); % create anatomical directory
        
        % brainvoyager volumetric anatomical file names
        bvAnat = convert_filenames(p.anat, 'anat');
        out.anat = fullfile(anatDir, bvAnat); 
        
        % brainvoyager surface file names
        bvSurf = convert_filenames(p.surf, 'surf'); 
        out.surf = fullfile(anatDir, bvSurf); 
    end
    
    if ~isempty(p.vtc) || ~isempty(p.mtc)
        % brainvoyager volumetric functional file names
        vtcSession = cellfun(@(x) extract_bids(x,'ses',true), p.vtc, ...
            'UniformOutput', false);
        bvVtc = convert_filenames(p.vtc, 'vtc'); 
        out.vtc = cellfun(@(x,y) fullfile(out.subject,x,y), ...
            vtcSession, bvVtc, 'UniformOutput', false);
        
        % brainvoyager surface functional file names
        mtcSession = cellfun(@(x) extract_bids(x,'ses',true), p.mtc, ...
            'UniformOutput', false);
        bvMtc = convert_filenames(p.mtc, 'mtc'); 
        out.mtc = cellfun(@(x,y) fullfile(out.subject,x,y), ...
            mtcSession, bvMtc, 'UniformOutput', false);
        
        % brainvoyager functional confounds file names
        confoundSession = cellfun(@(x) extract_bids(x,'ses',true), ...
            p.confounds, 'UniformOutput', false);
        bvConfounds = convert_filenames(p.confounds, 'confounds'); 
        out.confounds = cellfun(@(x,y) fullfile(out.subject,x,y), ...
            confoundSession, bvConfounds, 'UniformOutput', false); 
        
        funcFile = cat(2, out.vtc, out.mtc, out.confounds);
        funcDir = cellfun(@extract_fileparts, funcFile, 'UniformOutput', false);
        cellfun(@mkfolder, unique(funcDir)); % create functional directories
    end
    
    subjectFiles(i).save = out;
end

%% Helper Functions

function [tf] = regexp_contains(str, pat)
    patternMatch = regexp(str, pat, 'once');
    tf = ~cellfun(@isempty, patternMatch);
end


function [targetStruct] = structassign(targetStruct, inputStruct)
    flds = fieldnames(inputStruct);
    for f = 1:length(flds) % for each field
        targetStruct.(flds{f}) = inputStruct.(flds{f});
    end
end

function mkfolder(filepath)
    if ~isfolder(filepath)
        mkdir(filepath);
    end
end

function [saveNames] = convert_filenames(fileNames, modality) 
    if ischar(fileNames); fileNames = {fileNames}; end
    
    [~,baseNames,~] = cellfun(@extract_fileparts, fileNames, ...
        'UniformOutput', false);
    
    cstrcat = @(fn,ext) cellfun(@(x) [x,ext], fn, 'UniformOutput', false); 
    
    switch lower(modality)
        case 'anat'
            saveNames = cstrcat(baseNames, '.vmr');
        case 'surf'
            saveNames = regexprep(baseNames, '\.surf', '.srf'); 
        case 'vtc'
            saveNames = cstrcat(baseNames, '.vtc'); 
        case 'mtc'
            saveNames = regexprep(baseNames, '\.func', '.mtc');
        case 'confounds'
            saveNames = cstrcat(baseNames, '.sdm'); 
    end
end

end