% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)

function smtest(test_dir)

dirData = dir(test_dir);
if isempty(dirData)
    disp('No files found for test');
end
pos = 0;
neg = 0;
for i=1:length(dirData)
    fpath = fullfile(dirData(i).folder, dirData(i).name);
    disp('--------------------')
    disp(fpath);
    try
    ecg = smload(fpath);
    pos = pos + 1;
    catch ME
        cprintf('Errors','Error: %s', ME.message);
        neg = neg + 1;
        continue;
    end
end

fprintf('total: %d; success: %d; errors: %d\n', neg+pos, pos, neg);
