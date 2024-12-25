% eegplugin_sm() - Plugin to import SM data formats
%
% Usage:
%   >> eegplugin_sm(fig, trystrs, catchstrs);
%
% Inputs:
%   fig        - [integer]  EEGLAB figure
%   trystrs    - [struct] "try" strings for menu callbacks.
%   catchstrs  - [struct] "catch" strings for menu callbacks.
%
% Notes:
%   This plugins consist of the following Matlab files:
%
% Create a plugin:
%   For more information on how to create an EEGLAB plugin see the
%   help message of eegplugin_besa() or visit http://www.sccn.ucsd.edu/eeglab/contrib.html
%
% Author: Sergei Simonov, Medical Computer Systems, Russia, 2024
%
% See also: pop_sm_read(), sm_read()

% Copyright (C) 2024 Medical Computer Systems ltd. http://mks.ru
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function vers = eegplugin_sm(fig, trystrs, catchstrs)

vers = 'sm1.1';
if nargin < 3
    error('eegplugin_sm requires 3 arguments');
end

% add folder to path
% -----------------------
if ~exist('pop_readsm','file')
    p = which('eegplugin_sm');
    p = p(1:strfind(p,'eegplugin_sm.m')-1);
    addpath(p);
end

% find import data menu
% ---------------------
menu = findobj(fig, 'tag', 'import data');

% menu callbacks
% --------------

cb_readsm  = [  trystrs.no_check  '[EEG LASTCOM] = pop_readsm;' catchstrs.new_and_hist ];

uimenu( menu, 'label', 'From MCS .SM file', 'callback', cb_readsm, 'separator', 'on');
