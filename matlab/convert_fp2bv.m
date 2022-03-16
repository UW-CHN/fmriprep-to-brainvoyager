function convert_fp2bv(subjectInfo, overwrite)

%% Input Control

if ~exist('overwrite', 'var') || isempty(overwrite)
    overwrite = false;
end

if ~islogical(overwrite)
    error('Overwrite must be a logical data type.');
end

%% Convert fMRIPrep to BrainVoyager Files

for i = 1:length(subjectInfo) % for each subject
    p = subjectInfo(i); % current subject
    
    fprintf('[SUBJECT]: %s\n', p.subject);
    
    fprintf('Converting Anatomical Volumes\n');
    convert_wrapper(p, 'anat');
    
    fprintf('Converting Surfaces\n');
    convert_wrapper(p, 'surf');
    
    fprintf('Converting Volume Time Courses\n');
    convert_wrapper(p, 'vtc');
    
    fprintf('Converting Surface Time Courses\n');
    convert_wrapper(p, 'mtc');
    
    fprintf('Converting Functional Confounds\n');
    convert_wrapper(p, 'confounds');
    
    fprintf('[COMPLETED]: %s\n\n', p.subject);
end

%% Helper Function

function [fun] = get_convert_function(modality)
    switch modality
        case 'anat'; fun = @convert_anat_to_vmr;
        case 'surf'; fun = @convert_surf_to_srf;
        case 'vtc';  fun = @convert_func_to_vtc;
        case 'mtc';  fun = @convert_func_to_mtc;
        case 'confounds'; fun = @convert_confounds_to_sdm;
    end
end

function convert_wrapper(p, modality)
    modality = lower(modality);
    inputFiles = p.(modality); outputFiles = p.save.(modality);
    convert_function = get_convert_function(modality); 

    if length(inputFiles) < 1 % if no files to convert
        fprintf('  No files to convert, skipping conversion process\n');
    else % convert files
        for f = 1:length(inputFiles)
            % if file *does* exist AND do *not* overwrite, skip
            if isfile(outputFiles{f}) && ~overwrite
                fprintf('  Exists: %s\n', outputFiles{f});
            else % all other conditions
                if strcmp(modality, 'surf')
                    trf = read_xfm(p.surf2anat); % extract transformation matrix
                    convert_function(outputFiles{f}, inputFiles{f}, trf);
                else
                    convert_function(outputFiles{f}, inputFiles{f});
                end
                fprintf('  Converted: %s to %s\n', ...
                    inputFiles{f}, outputFiles{f})
            end
        end
    end
end

end