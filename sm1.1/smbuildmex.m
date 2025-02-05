% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)

% Run this script to achive the max performance for importing SM files.
% Check if mex files are working, if not - buld them and check result.

is_crc32_ok = @()check_mex("smcrc32","x=smcrc32([int8(32)]);");
is_decode_ok = @()check_mex("smdecode","x=smdecode([int8(32)], 1, 2, 0.001);");

if is_crc32_ok() && is_decode_ok()
    disp("Mex files works well. No need to build.");
else
    from_dir = pwd;
    cd([fileparts(which('smbuildmex.m')),'\private'])
    if ~is_crc32_ok()
        mex -R2018a smcrc32.c;
    end
    if ~is_decode_ok()
        mex -R2018a smdecode.c;
    end
    cd(from_dir);
    if is_crc32_ok() && is_decode_ok()
        disp(" Mex files built successfully!");
    else
        disp("Failed to build mex files!");
    end
end