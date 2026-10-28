% Run all MATLAB fiber-optics models and generate Results/Graphs plots.

matlabRootDir = fileparts(mfilename('fullpath'));
run(fullfile(matlabRootDir, 'Isolator', 'isolator_model.m'));
run(fullfile(matlabRootDir, 'Circulator', 'circulator_model.m'));
run(fullfile(matlabRootDir, 'WDM', 'wdm_model.m'));

fprintf('All MATLAB models completed. Plots are in Results/Graphs.\n');
