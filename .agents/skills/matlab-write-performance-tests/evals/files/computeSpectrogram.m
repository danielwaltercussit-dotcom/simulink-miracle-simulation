function [S, F, T] = computeSpectrogram(signal, fs, windowLen, overlap)
%computeSpectrogram Compute STFT spectrogram using only core MATLAB
%   Manual short-time Fourier transform with Hamming window.
    step = windowLen - overlap;
    nFrames = floor((length(signal) - windowLen) / step) + 1;
    nfft = windowLen;
    S = zeros(nfft/2 + 1, nFrames);
    win = hamming(windowLen);
    for k = 1:nFrames
        idx = (k-1)*step + (1:windowLen);
        frame = signal(idx) .* win;
        Y = fft(frame, nfft);
        S(:, k) = abs(Y(1:nfft/2+1)).^2 / nfft;
    end
    F = (0:nfft/2)' * fs / nfft;
    T = ((0:nFrames-1) * step + windowLen/2) / fs;
end
