function peaks = detectSpectralPeaks(signal, fs, minPeakHeight, minSepHz)
%detectSpectralPeaks Find dominant frequencies via FFT and manual peak detection
%   Uses only core MATLAB (no toolboxes).
    N = length(signal);
    Y = fft(signal);
    P = abs(Y(1:floor(N/2)+1)).^2 / N;
    P(2:end-1) = 2 * P(2:end-1);
    f = (0:floor(N/2))' * fs / N;
    % Manual peak detection: local maxima above threshold
    minSepBins = round(minSepHz / (fs / N));
    isPeak = false(size(P));
    for i = 2:length(P)-1
        if P(i) > P(i-1) && P(i) > P(i+1) && P(i) > minPeakHeight
            isPeak(i) = true;
        end
    end
    % Enforce minimum separation
    peakIdx = find(isPeak);
    keep = true(size(peakIdx));
    for i = 2:length(peakIdx)
        if peakIdx(i) - peakIdx(find(keep(1:i-1), 1, 'last')) < minSepBins
            if P(peakIdx(i)) <= P(peakIdx(i-1))
                keep(i) = false;
            else
                keep(i-1) = false;
            end
        end
    end
    peakIdx = peakIdx(keep);
    peaks = struct('frequencies', f(peakIdx)', 'powers', P(peakIdx)');
end
