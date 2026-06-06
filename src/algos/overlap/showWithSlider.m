% showWithSlider.m – Display image set with a slider to navigate

function showWithSlider(images)
numImages = numel(images);
fig = figure('Name', 'Aligned and Cropped Images', 'NumberTitle', 'off');
ax = axes('Parent', fig);
im = imshow(images{1}, 'Parent', ax);

uicontrol('Style', 'slider', 'Min', 1, 'Max', numImages, 'Value', 1, ...
    'SliderStep', [1/(numImages-1) 1/(numImages-1)], ...
    'Units', 'normalized', 'Position', [0.25 0.01 0.5 0.05], ...
    'Callback', @(src, ~) set(im, 'CData', images{round(get(src, 'Value'))}));
end
