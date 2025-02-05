% POP_READEGI - load a EGI EEG file (pop out window if no arguments).
%
% Usage:
%   >> EEG = pop_readsm;             % a window pops up
%   >> EEG = pop_readsm( filename );
%
% Inputs:
%   filename       - EGI file name
% Outputs:
%   EEG            - EEGLAB data structure
%

% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)


function [EEG, com] = pop_readsm(filename)
EEG = [];
com = '';

if nargin < 1
    % ask user
    [filename, filepath] = uigetfile('*.SM;*.sm', ...
        'Choose an SM file -- pop_readesm()');
    drawnow;
    if filename == 0
        return;
    end
    filename = [filepath filename];
end
EEG = smload(filename);
if nargout > 1
    com = sprintf( 'EEG = pop_readsm(%s);', filename);
end
end