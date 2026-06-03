function result = processImage(img)
%processImage Apply convolution-based image processing (no toolboxes)
%   Applies a Gaussian blur via 2D convolution and edge enhancement.
    % Gaussian kernel (sigma=2)
    k = 13;
    [x, y] = meshgrid(-(k-1)/2:(k-1)/2);
    kernel = exp(-(x.^2 + y.^2) / (2*2^2));
    kernel = kernel / sum(kernel, 'all');
    % Blur
    blurred = conv2(img, kernel, 'same');
    % Edge enhancement (Laplacian)
    lap = [0 -1 0; -1 4 -1; 0 -1 0];
    edges = conv2(blurred, lap, 'same');
    result = blurred + 0.3 * edges;
end
