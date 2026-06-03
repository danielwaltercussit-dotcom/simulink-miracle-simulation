function filtered = designAndApplyFilter(signal, fs, cutoffHz)
%designAndApplyFilter Design a windowed-sinc FIR lowpass and apply it
%   Uses only core MATLAB (no toolboxes). Designs a 256-tap FIR filter
%   using a Hamming-windowed sinc, then applies zero-phase filtering.
    order = 256;
    fc = cutoffHz / (fs/2);  % Normalized cutoff
    n = (-(order/2):(order/2))';
    h = fc * sinc(fc * n);
    h = h .* hamming(order + 1);
    h = h / sum(h);
    % Zero-phase filtering (forward-backward)
    filtered = filter(h, 1, signal);
    filtered = flipud(filter(h, 1, flipud(filtered)));
end
