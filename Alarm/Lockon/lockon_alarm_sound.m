clear; clc;

%% 1. Parameters
Fs          = 48000;              
total_dur   = 5.0;
f_carrier   = 500;                 % 48000/500 = 96 samples per cycle (exact)
n_channels  = 2;                   
peak_dbfs   = -6;                  
edge_ms     = 0.5;                 
fade_in_ms  = 5;
fade_out_ms = 10;
pad_tail_ms = 100;                 

stage_freqs = [5 10 30 50];
stage_duty  = [0.50 0.50 0.50 1.00];
dur_outer   = 1.75;
dur_mid     = (total_dur - 2*dur_outer) / 2;
stage_dur   = [dur_outer, dur_mid*ones(1,2), dur_outer];

%% 2. Time base & stage edges
N     = round(total_dur * Fs);
n     = (0 : N-1)';
edges = round([0, cumsum(stage_dur)] * Fs);
edges(end) = N;

%% 3. Gate
gate = zeros(N, 1);
for k = 1:numel(stage_freqs)
    idx       = (edges(k)+1) : edges(k+1);
    t_local   = (0 : numel(idx)-1)' / Fs;
    cycle_pos = mod(stage_freqs(k) * t_local, 1);
    gate(idx) = double(cycle_pos < stage_duty(k));
end


L    = max(1, round(edge_ms/1000 * Fs));
gate = filter(ones(1, L)/L, 1, gate);

%% 4. Carrier 
carrier = 1 - 2 * mod(floor(2 * f_carrier * n / Fs), 2);   % +1 first half, -1 second

audio = carrier .* gate;

%% 5. Fades, normalize, pad, stereo, export
fi = round(fade_in_ms/1000  * Fs);
fo = round(fade_out_ms/1000 * Fs);
audio(1:fi)           = audio(1:fi)           .* linspace(0, 1, fi)';
audio(end-fo+1:end)   = audio(end-fo+1:end)   .* linspace(1, 0, fo)';

audio = audio / max(abs(audio)) * 10^(peak_dbfs/20);

audio = [audio; zeros(round(pad_tail_ms/1000 * Fs), 1)];
audio = repmat(audio, 1, n_channels);

audiowrite('lockon_alarm_sound.wav', audio, Fs, 'BitsPerSample', 16);
fprintf('Exported .wav file (%d Hz, %d ch, %.2f s)\n', Fs, n_channels, size(audio,1)/Fs);