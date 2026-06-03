function results = myAudioProcessingCode(signal, fs, options)
%myAudioProcessingCode Process audio signal: filter, analyze spectrum, detect peaks
%   Applies a complete audio analysis pipeline:
%   1. Lowpass filter to remove high-frequency noise
%   2. Compute time-frequency representation via spectrogram
%   3. Detect dominant spectral peaks in the filtered signal
%
%   results = myAudioProcessingCode(signal, fs)
%   results = myAudioProcessingCode(signal, fs, options)
%
%   Inputs:
%     signal  - Column vector of audio samples
%     fs      - Sampling frequency in Hz
%     options - (optional) struct with fields:
%       .cutoffHz    - Lowpass cutoff frequency (default: 5000)
%       .windowLen   - Spectrogram window length (default: 2048)
%       .overlap     - Spectrogram overlap (default: 1024)
%       .minPeakHeight - Minimum peak power (default: 1e3)
%       .minSepHz    - Minimum peak separation in Hz (default: 100)
%
%   Output:
%     results - struct with fields:
%       .filteredSignal - Lowpass-filtered signal
%       .spectrogram    - Power spectrogram matrix (freq x time)
%       .freqAxis       - Frequency axis for spectrogram
%       .timeAxis       - Time axis for spectrogram
%       .peaks          - Detected peaks (struct with .frequencies, .powers)
%       .snr            - Estimated SNR improvement from filtering

    if nargin < 3
        options = struct();
    end

    % Default parameters
    cutoffHz = getFieldOrDefault(options, 'cutoffHz', 5000);
    windowLen = getFieldOrDefault(options, 'windowLen', 2048);
    overlap = getFieldOrDefault(options, 'overlap', 1024);
    minPeakHeight = getFieldOrDefault(options, 'minPeakHeight', 1e3);
    minSepHz = getFieldOrDefault(options, 'minSepHz', 100);

    % Step 1: Lowpass filter to clean the signal
    filteredSignal = designAndApplyFilter(signal, fs, cutoffHz);

    % Step 2: Time-frequency analysis via spectrogram
    [S, F, T] = computeSpectrogram(filteredSignal, fs, windowLen, overlap);

    % Step 3: Detect dominant frequencies in the filtered signal
    peaks = detectSpectralPeaks(filteredSignal, fs, minPeakHeight, minSepHz);

    % Step 4: Estimate SNR improvement
    noiseBefore = estimateNoisePower(signal, fs, cutoffHz);
    noiseAfter = estimateNoisePower(filteredSignal, fs, cutoffHz);
    if noiseAfter > 0
        snrImprovement = 10 * log10(noiseBefore / noiseAfter);
    else
        snrImprovement = inf;
    end

    % Package results
    results.filteredSignal = filteredSignal;
    results.spectrogram = S;
    results.freqAxis = F;
    results.timeAxis = T;
    results.peaks = peaks;
    results.snr = snrImprovement;
end

function val = getFieldOrDefault(s, fieldName, defaultVal)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end

function noisePower = estimateNoisePower(signal, fs, cutoffHz)
%estimateNoisePower Estimate power above cutoff frequency
    N = length(signal);
    Y = fft(signal);
    P = abs(Y(1:floor(N/2)+1)).^2 / N;
    freqs = (0:floor(N/2))' * fs / N;
    highFreqIdx = freqs > cutoffHz;
    noisePower = mean(P(highFreqIdx));
end
