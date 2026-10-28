% Prompt for all parameters, then run all MATLAB fiber-optics models.

matlabRootDir = fileparts(mfilename('fullpath'));
addpath(matlabRootDir);

fprintf('Enter simulation values. Press Enter to accept each default.\n\n');

fprintf('ISOLATOR\n');
isolatorInput_mW = prompt_numeric('Input power (mW)', 10, eps);
isolatorIL_dB = prompt_numeric('Insertion loss (dB)', 0.5, 0);
isolatorISO_dB = prompt_numeric('Reverse isolation (dB)', 30, 0);
isolatorInputAngle_deg = prompt_numeric('Input polarizer angle (degrees)', 0, []);
isolatorRotation_deg = prompt_numeric('Faraday rotation (degrees)', 45, []);
isolatorAnalyzerAngle_deg = prompt_numeric('Output analyzer angle (degrees)', 45, []);

fprintf('\nCIRCULATOR (three ports; cyclic routing 1 -> 2 -> 3 -> 1)\n');
circulatorInputPower_mW = prompt_numeric('Input power per port (mW)', 1, 0);
circulatorInsertionLoss_dB = prompt_numeric('Routed-path insertion loss (dB)', 0.6, 0);
circulatorCrosstalk_dB = prompt_numeric('Unwanted-port attenuation (dB)', 35, 0);

fprintf('\nWDM\n');
wdmChannelCount = prompt_positive_integer('Number of wavelength channels', 4);
wdmWavelength_nm = zeros(1, wdmChannelCount);
wdmDefaultWavelengths_nm = [1530, 1540, 1550, 1560];
for wdmChannelIndex = 1:wdmChannelCount
    if wdmChannelIndex <= numel(wdmDefaultWavelengths_nm)
        wdmDefaultWavelength_nm = wdmDefaultWavelengths_nm(wdmChannelIndex);
    else
        wdmDefaultWavelength_nm = wdmDefaultWavelengths_nm(end) + ...
            10 * (wdmChannelIndex - numel(wdmDefaultWavelengths_nm));
    end
    while true
        wdmWavelength_nm(wdmChannelIndex) = prompt_numeric( ...
            sprintf('Channel %d wavelength (nm)', wdmChannelIndex), ...
            wdmDefaultWavelength_nm, eps);
        if any(wdmWavelength_nm(1:wdmChannelIndex - 1) == ...
                wdmWavelength_nm(wdmChannelIndex))
            fprintf('Wavelengths must be unique.\n');
        else
            break;
        end
    end
end
wdmFiberLength_km = prompt_numeric('Fiber length (km)', 50, 0);
wdmAttenuation_dB_per_km = prompt_numeric('Fiber attenuation (dB/km)', 0.2, 0);
wdmBeta2_ps2_per_km = prompt_numeric('Dispersion beta2 (ps^2/km)', -21.7, []);
wdmModulation_Hz = prompt_numeric('Modulation frequency (GHz)', 18, 0) * 1e9;

wdmOpticalFrequency_Hz = 299792458 ./ (wdmWavelength_nm * 1e-9);
wdmChannelOffset_Hz = wdmOpticalFrequency_Hz - mean(wdmOpticalFrequency_Hz);
if max(abs(wdmChannelOffset_Hz)) + wdmModulation_Hz >= 8e12
    error('WDM channel offsets exceed the configured sample-rate Nyquist limit.');
end
if wdmChannelCount > 1
    wdmChannelSpacing_Hz = min(diff(sort(wdmChannelOffset_Hz)));
else
    wdmChannelSpacing_Hz = 16e12;
end
if wdmModulation_Hz >= 0.45 * wdmChannelSpacing_Hz
    error('WDM modulation exceeds the ideal channel filter bandwidth.');
end

run(fullfile(matlabRootDir, 'Isolator', 'isolator_model.m'));
run(fullfile(matlabRootDir, 'Circulator', 'circulator_model.m'));
run(fullfile(matlabRootDir, 'WDM', 'wdm_model.m'));

fprintf('All MATLAB models completed. See Results/Graphs, Results/Animations, and Results/Data.\n');
