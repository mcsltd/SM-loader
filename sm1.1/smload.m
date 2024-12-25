function r = smload(filename)
% smload  Load SM-file and returns EEG struct

block_iter = BlockIterator(filename);
[block_iter, b0] = block_iter.next();
if b0.type ~=0
    error('SMLOADER:PARSE','Block0 is missing');
end
elements = parse_elements(transpose(char(b0.data)));

% Check file version
ver = get_elements(elements, 'Version');
if ~strcmp(ver.data,'1')
    error('SMLOADER:PARSE', 'Version of SM file %s is not supported', ver)
end

% Check encoding method
method = get_elements(elements, 'EncodingMethod');
if ~strcmp(method.data,'0')
    error('SMLOADER:PARSE', 'Encoding method of SM file %s is not supported', method)
end

% Load event types info
event_types=[];
try
    event_types = get_elements(elements, 'Controller', 'EventTypes', 'EventType');
catch ME
    if strcmp(ME.identifier,'SMLOADER:ELEMENT_NOT_FOUND')
        warning('SMLOADER:LOAD','Events description not found');
    else
        rethrow(ME)
    end
end
event_desriptions = {};
for i = 1: length(event_types)
    evt = event_types(i);
    if (isfield(evt,'attributes'))
        etype = NaN;
        edescr = '';
        for j = 1 : length(event_types(i).attributes)
            if strcmp(event_types(i).attributes(j).atrname, 'type')
                etype = str2double(event_types(i).attributes(j).atrval);
            elseif strcmp(event_types(i).attributes(j).atrname, 'description')
                edescr =event_types(i).attributes(j).atrval;
            end
        end
        if ~isnan(etype)
            event_desriptions{etype} = strtrim(deblank(edescr));
        end
    end
end

%Load signals informataion
signals = [];
try
    signals = get_elements(elements, 'Controller', 'Record',  'Lead', 'Signals');
catch ME
    if strcmp(ME.identifier,'SMLOADER:ELEMENT_NOT_FOUND')
        warning('SMLOADER:LOAD','Signal descriptions not found');
    else
        rethrow(ME)
    end
end
% For each channel make struct siginfo 
% with fields named like parametres and values
tmp = parse_element_data_deep(signals);
signals = tmp.data;
siginfo = cell(length(signals), 1);
for i = 1 : length(signals)
    for j =  1 : length(signals(i).data)
        for k =  1 : length(signals(i).data(j).data)
            siginfo{i}.(lower(signals(i).data(j).data(k).name)) = signals(i).data(j).data(k).data;
        end
    end
end

% Preview. Calculate min and max sample number for each channel
% And save frames descriptions for each channel
for i = 1: length(siginfo)
    siginfo{i}.('frames') = {};
    siginfo{i}.('min_tick') = [];
    siginfo{i}.('max_tick') = [];
end

all_frames = cell(1,16000);
all_events = cell(1,16000);
frame_counter = uint64(0);
event_counter = uint64(0);
while true
    [block_iter, bx] = block_iter.next();
    if isempty(bx); break; end
    if bx.type == 1
        frame_iter = SignalFramelterator(siginfo, bx);
        while true
            [frame_iter, frame] = frame_iter.next();
            if isempty(frame); break; end
            if isempty(siginfo{frame.channel}.min_tick)
                siginfo{frame.channel}.min_tick = frame.start_tick;
                siginfo{frame.channel}.max_tick = frame.start_tick + frame.size - 1;
            else
                siginfo{frame.channel}.max_tick = max([siginfo{frame.channel}.max_tick, frame.start_tick + frame.size-1]);
                siginfo{frame.channel}.min_tick = min([siginfo{frame.channel}.min_tick, frame.start_tick]);
            end
            siginfo{frame.channel}.frames{end+1} = [frame.block_id, frame.id, frame.size, frame.start_tick];
            frame_counter = frame_counter + 1;
            all_frames{frame_counter} = frame;
        end
    elseif bx.type == 2
        ev_iter = EventIterator(siginfo, bx);
        while true
            [ev_iter,ev] = ev_iter.next();
            if isempty(ev); break; end
            event_counter = event_counter + 1;
            all_events{event_counter} =  ev;
        end
    end
end % while
all_frames = all_frames(1:frame_counter);
all_events = all_events(1:event_counter);
gmin_tick = siginfo{1}.min_tick;
gmax_tick = siginfo{1}.max_tick;
freq = siginfo{1}.freq;
if ~all(extractfiled(siginfo,'max_tick') == gmax_tick)
    error('SMLOADER:LOAD', 'Records with variative channel''s stop time are not supported')
end
if ~all(extractfiled(siginfo,'min_tick') == gmin_tick) ~= 0
    error('SMLOADER:LOAD', 'Records with variative channel''s start time are not supported')
end
if ~all(extractfiled(siginfo,'freq') == freq) ~= 0
    error('SMLOADER:LOAD', 'Records with variative channel''s sample rates are not supported')
end


nbchan = length(siginfo);
pnts = gmax_tick - gmin_tick + 1;
EEG = eeg_emptyset;
EEG.setname = filename;
EEG.comments = [ 'Information will be placed here later' ];
EEG.pnts = double(pnts);
EEG.nbchan = nbchan;
EEG.trials = 1;
EEG.srate = double(freq);
EEG.xmin = double(gmin_tick/freq);
EEG.xmax = double(gmax_tick/freq);
EEG.ref = 'common';
EEG.data = zeros(nbchan, pnts, 1, 'single');
%EEG.times =  [EEG.xmin: 1000.0/siginfo{1}.freq:EEG.xmax];
for i = 1 : nbchan
    EEG.chanlocs(i).labels = siginfo{i}.name;
end

% Placing EEG.data
offset = -gmin_tick + 1;
for i = 1 : length(all_frames)
    frame = all_frames{i};
    block = block_iter.extract_block(frame.block_id);
    frame_iter = SignalFramelterator(siginfo, block);
    xxx = frame_iter.decode(frame);
    EEG.data(frame.channel, offset+frame.start_tick:offset+frame.start_tick+frame.size-1) = xxx;
end

% Placing EEG.event
% TODO, check should i sort events by latency
for i = 1 : event_counter
    urev.type = event_desriptions{all_events{i}.type};
    urev.channel = siginfo{all_events{i}.channel}.name;
    urev.latency = all_events{i}.start_tick + offset;
    urev.creation_time = string(datetime(all_events{i}.crtime, 'ConvertFrom','posixtime','Format','dd-MMM-uuuu HH:mm:ss'));
    urev.payload = all_events{i}.body;
    ev = urev;
    ev.urevent = i;
    if i == 1
        EEG.urevent = urev;
        EEG.event = ev;
    else
        EEG.urevent(end+1) = urev;
        EEG.event(end+1) = ev;
    end
end
r = EEG;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function res = extractfiled(cs, name)
res = zeros(1, length(cs), class(cs{1}.(name)));
for i = 1 :length(cs)
    res(i) = cs{i}.(name);
end
end

function e = parse_element_data_deep(e)
if isempty(e.data)
    return;
end
data = parse_elements(e.data);
if ~isempty(data)
    e.data = data;
    for i = 1 : length(e.data)
        e.data(i) = parse_element_data_deep(e.data(i));
    end
    return
else
    % not an element
    if e.data(end) == char(0)
        % строка
        if length(e.data)>1
            e.data = char(e.data(1:end-1));
        else
            e.data = '';
        end
    elseif regexpi(e.data,'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$')
        % uuid - оставляем строкой
    else
         % uuid - число
        val =  str2double(e.data);
        if ~isnan(val)
            e.data = val;
        else
            warning('unexpected type of data: %s for element %s', e.data, e.name);
        end
    end
end
end
