function value = prompt_numeric(label, defaultValue, minimumValue)
% Read a finite numeric value from the console, with an optional lower bound.
while true
    rawValue = input(sprintf('%s [%.6g]: ', label, defaultValue), 's');
    if isempty(strtrim(rawValue))
        value = defaultValue;
        return;
    end
    value = str2double(rawValue);
    if ~isfinite(value)
        fprintf('Enter a finite numeric value.\n');
    elseif ~isempty(minimumValue) && value < minimumValue
        fprintf('Enter a value greater than or equal to %.6g.\n', minimumValue);
    else
        return;
    end
end
end
