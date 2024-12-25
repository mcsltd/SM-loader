classdef SignalFramelterator
    % SignalFramelterator
    % Extractor of frames with samples from
    % SM-file block in iterator style
    %
    % Frame is sruct with fields
    %   id - unique id of frame, equals offset of start position in block
    %   block_id - id of block, where the frame is located
    %   channel - number of channel
    %   start_tick - starting tick number of first sample in frame
    %   frame size - number of samples in frame
    %   bytes data - (optional) array of decoded data of single
    %
    % For iteration call next(), which returns a Frame. When next() returns
    % empty array, it means end of block reached. It's possible to extract
    % frame directly by it's id later with decode() funciton

    properties (Constant = true, Hidden = true)
        FRAME_HEADER_SIZE = 18;
        INT8_MAX = uint8(hex2dec('7f'));
        INT16_MAX = int16(hex2dec('7fff'));
    end
    properties (Access = protected)
        block
        pos
        size
        siginfo
    end
    methods
        function obj = SignalFramelterator(siginfo, block)
            obj.siginfo = siginfo;
            obj.block = block;
            obj.pos = 1;
            obj.size = length(block.data);
        end

        function [obj, frame] = next(obj)
            if obj.size - obj.pos < obj.FRAME_HEADER_SIZE
                frame =[];
                return;
            end
            i = obj.pos-1;
            frame.block_id = obj.block.id;
            frame.id = obj.pos;
            frame.channel = typecast(obj.block.data(i+1:i+2),'uint16') + 1;
            frame.start_tick = typecast(obj.block.data(i+3:i+10),'int64');
            frame.size = int64(typecast(obj.block.data(i+11:i+14),'uint32'));
            frame.raw_size = typecast(obj.block.data(i+15:i+18),'uint32') + obj.FRAME_HEADER_SIZE;
            if obj.pos + frame.raw_size - 1 > obj.size
                error('SMLOADER:PARSE_FRAME','Frame size %d exceeds block boundary', frame.raw_size);
            end
            if (length(obj.siginfo) < frame.channel)
                error('SMLOADER:PARSE_FRAME', 'Unexpected channel: %d ?', frame.channel);
            end
            obj.pos = obj.pos + frame.raw_size;
        end

        function samples = decode(obj, frame)
            if frame.block_id ~= obj.block.id
                error('SMLOADER:DECODE_FRAME','unexpected frame to decode (block_id is invalid)');
            end
            bps = int32(obj.siginfo{frame.channel}.bitspersample);
            uv_per_bit = 1000000*obj.siginfo{frame.channel}.resolution;
            MAX_BYTES = idivide(bps,8,'ceil');
            if MAX_BYTES < 2 || MAX_BYTES > 4
                error('SMLOADER:DECODE_FRAME', 'BitsPerSampled %d for channel %d is not supported', bps, obj.siginfo{frame.channel}.name)
            end

            samples = zeros(1, frame.size, 'single');
            val = int32(0);
            tick_counter = 1;
            next_frame_pos = frame.id + frame.raw_size;
            i = frame.id + obj.FRAME_HEADER_SIZE;
            while i < next_frame_pos && tick_counter < frame.size
                if obj.block.data(i) ~= obj.INT8_MAX
                    val = val + int32(typecast(obj.block.data(i), 'int8'));
                    i = i + 1;
                else
                    i = i + 1;
                    diff = typecast(obj.block.data(i:i+1),'int16');
                    if (diff ~= obj.INT16_MAX) || MAX_BYTES == 2
                        val = val + int32(diff);
                        i = i + 2;
                    else
                        % read 24 bit or 32 bit
                        i = i + 2;
                        if MAX_BYTE == 3
                            diff = idivide(typecast([obj.block.data(i:i+2), uint8(0)],'int32'), 256);
                            i = i + 3;
                        else
                            diff = typecast(obj.block.data(i:i+3),'int32');
                            i = i + 4;
                        end
                        val = val + diff;
                    end
                end
                samples(tick_counter)  = double(val)*uv_per_bit;
                tick_counter = tick_counter + 1;
            end
            if i < frame.raw_size
                warning('SMLOADER:DECODE_FRAME','Unused data in frame (%d bytes). Frame may be corrupted', frame.raw_size - i);
            end
            if tick_counter ~= frame.size
                error('SMLOADER:DECODE_FRAME', 'Not enough data in frame. Frame may be corrupted');
            end
        end
    end %methods
end