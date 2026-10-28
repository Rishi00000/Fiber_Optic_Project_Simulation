function value = prompt_positive_integer(label, defaultValue)
% Read a positive integer from the console.
while true
    rawValue = input(sprintf('%s [%d]: ', label, defaultValue), 's');
    if isempty(strtrim(rawValue))
        value = defaultValue;
        return;
    end
    candidate = str2double(rawValue);
    if isfinite(candidate) && candidate >= 1 && candidate == floor(candidate)
        value = candidate;
        return;
    end
    fprintf('Enter a whole number greater than or equal to 1.\n');
end
end
