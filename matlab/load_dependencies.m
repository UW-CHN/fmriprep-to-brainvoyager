function load_dependencies(paths)
% LOAD_DEPENDENCIES(paths)
%
% Loads fmriprep-to-brainvoyager package dependencies to the current MATLAB
% pathing instance.
%
%
% Arguments:
%   paths               Structure, contains the paths to dependencies as 
%                       fields.
%      
%     gifti             String, path to GIfTI dependency.
%
%     freesurfer        String, path to FreeSurfer dependency.
%
%     neuroelf          String, path to NeuroElf dependency.
%
% 
% Dependencies:
%    GIfTI             https://www.artefact.tk/software/matlab/gifti/
%    FreeSurfer        https://surfer.nmr.mgh.harvard.edu/
%    NeuroElf          https://neuroelf.net/

% Written by Kelly Chang - March 16, 2022

%% Input Control

%%% Exist: Check is 'paths' exists.
if ~exist('paths', 'var') || isempty(paths)
    error('Cannot provide empty ''paths''.');
end

%%% Exists: check if 'paths' has all dependencies as fields.
flds = fieldnames(paths); % extract given paths fieldnames
allDependencies = {'gifti', 'freesurfer', 'neuroelf'};
if ~all(ismember(allDependencies, flds))
    missingFlds = strjoin(setdiff(allDependencies, flds), ', ');
    error('Missing dependency field in ''path'' for: %s', missingFlds);
end

%% Check and Load gifti Dependency

giftiFlag = which('gifti'); % check gifti
if (isempty(paths.gifti) || ~isfolder(paths.gifti))
    error('Unable to locate gifti dependency from given path.');
elseif isempty(giftiFlag)
    addpath(genpath(paths.gifti)); % add gifti to path
end

%% Check and Load neuroelf Dependency

neFlag = which('neuroelf'); % check neuroelf
if (isempty(paths.neuroelf) || ~isfolder(paths.neuroelf))
    error('Unable to locate neuroelf dependency from given path.');
elseif isempty(neFlag)
    addpath(genpath(paths.neuroelf)); % add neuroelf to path
end

%% Check and Load FreeSurfer Dependency

fsMatFlag = which('freesurfer_read_surf'); % check freesurfer matlab
[fsBinFlag,~] = system('mri_convert --help'); % check freesurfer binaries
fsFlag = isempty(fsMatFlag) || (fsBinFlag > 0); % combined freesurfer check

fsMatPath = fullfile(paths.freesurfer, 'matlab'); % freesurfer matlab path
fsBinPath = fullfile(paths.freesurfer, 'bin'); % freesurfer binaries path

if fsFlag && (isempty(paths.freesurfer) || ~isfolder(paths.freesurfer))
    error('Unable to locate FreeSurfer dependency from given path.');
elseif isempty(fsMatFlag) && ~isfolder(fsMatPath)
    error('Unable to locate FreeSurfer''s ''matlab'' subdirectory from given FreeSurfer path.');
elseif (fsBinFlag > 0) && ~isfolder(fsBinPath)
    error('Unable to locate FreeSurfer''s ''bin'' subdirectory from given FreeSurfer path'); 
end

if isempty(fsMatFlag)
    addpath(genpath(fsMatPath)); % add freesurfer matlab scripts to path
end

if (fsBinFlag > 0)
    PATH = getenv('PATH'); % get system PATH
    fsBinPath = format_escaped_path(fsBinPath); % format binaries path
    setenv('PATH', sprintf('%s:%s', PATH, fsBinPath)); % set system PATH
end

%% Final Dependency Check

dependencyFlags = true(1, length(allDependencies) + 1);
dependencyFlags(1) = isempty(which('gifti')); 
dependencyFlags(2) = isempty(which('freesurfer_read_surf')); 
[flag,~] = system('mri_convert --help');
dependencyFlags(3) = flag > 0; 
dependencyFlags(4) = isempty(which('neuroelf')); 

if any(dependencyFlags)
    if dependencyFlags(3)
        dependencyFlags(2) = true; 
        dependencyFlags = dependencyFlags([1, 2, 4]);
    end
    errorDependencies = strjoin(allDependencies(dependencyFlags), ', '); 
    error('Unable to load dependencies: %s', errorDependencies); 
end