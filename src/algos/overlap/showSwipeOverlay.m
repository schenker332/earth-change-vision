function showSwipeOverlay(originals, cropped)
numImages = numel(cropped);
fig = figure('Name', 'Swipe Comparison: Original vs. Cropped', 'NumberTitle', 'off');

% Initial images
base = originals(1).rgb;
top  = cropped{1};

ax = axes('Parent', fig);
imBase = imshow(base, 'Parent', ax);
hold on;
imTop = imshow(top, 'Parent', ax);
hold off;

% Set clipping rectangle (initial half image)
[H, W, ~] = size(base);
mask = [0 0 W/2 0; H 0 H 0; H H H H; 0 H 0 H]'; % just a mask init
clipRect = rectangle('Position', [0 0 W/2 H], 'EdgeColor', 'none', 'FaceColor', 'none');
set(imTop, 'AlphaData', createAlphaMask(W, H, W/2));

% Slider for swipe
uicontrol('Style', 'slider', 'Min', 1, 'Max', numImages, 'Value', 1, ...
    'SliderStep', [1/(numImages-1) 1/(numImages-1)], ...
    'Units', 'normalized', 'Position', [0.1 0.01 0.3 0.04], ...
    'Callback', @(src, ~) updateImage(round(get(src, 'Value'))));

% Slider for swipe position
uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0.5, ...
    'Units', 'normalized', 'Position', [0.6 0.01 0.3 0.04], ...
    'Callback', @(src, ~) updateMask(get(src, 'Value')));

    function updateImage(idx)
        set(imBase, 'CData', originals(idx).rgb);
        set(imTop,  'CData', cropped{idx});
    end

    function updateMask(v)
        swipeX = round(W * v);
        set(imTop, 'AlphaData', createAlphaMask(W, H, swipeX));
    end

    function alpha = createAlphaMask(w, h, xSplit)
        % Creates binary mask for top image visibility
        alpha = zeros(h, w);
        alpha(:, 1:xSplit) = 1;
    end
end
