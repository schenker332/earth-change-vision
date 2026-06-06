function overlapApp()
folderPath = uigetdir(pwd, 'Select Folder from "Datasets"');
if folderPath == 0
    disp('No folder selected.');
    return;
end

imgFiles = dir(fullfile(folderPath, '*.jpg'));
[~, sortIdx] = sort({imgFiles.name});
imgFiles = imgFiles(sortIdx);
imageNames = {imgFiles.name};

[selection, ok] = listdlg('ListString', imageNames, 'SelectionMode', 'multiple', ...
    'Name', 'Select Images to Align & Crop', 'PromptString', 'Select the images:');

if ~ok
    disp('No images selected.');
    return;
end

selectedFiles = imgFiles(selection);
selectedPaths = fullfile(folderPath, {selectedFiles.name});

targetSize = [1064 1570];
images = struct('filename', {}, 'rgb', {}, 'gray', {});

for k = 1:length(selectedPaths)
    colorImg = imread(selectedPaths{k});
    resizedRGB = imresize(colorImg, targetSize);
    grayImg = rgb2gray(resizedRGB);
    preprocessedGray = adapthisteq(grayImg);

    images(k).filename = selectedFiles(k).name;
    images(k).rgb = resizedRGB;
    images(k).gray = preprocessedGray;
end

tforms = estimateTransforms(images);
alignedRGB = applyTransforms(images, tforms);
croppedRGB = cropToOverlapRegion(alignedRGB);

showSwipeOverlay(images, croppedRGB);

end

function showSideBySide(originals, cropped)
numImages = numel(cropped);
fig = figure('Name', 'Original vs. Aligned and Cropped', 'NumberTitle', 'off');

ax1 = subplot(1,2,1);
im1 = imshow(originals(1).rgb, 'Parent', ax1);
title(ax1, ['Original: ', originals(1).filename]);

ax2 = subplot(1,2,2);
im2 = imshow(cropped{1}, 'Parent', ax2);
title(ax2, 'Aligned and Cropped');

uicontrol('Style', 'slider', 'Min', 1, 'Max', numImages, 'Value', 1, ...
    'SliderStep', [1/(numImages-1) 1/(numImages-1)], ...
    'Units', 'normalized', 'Position', [0.25 0.01 0.5 0.05], ...
    'Callback', @(src, ~) updateImages(round(get(src, 'Value'))));

    function updateImages(idx)
        set(im1, 'CData', originals(idx).rgb);
        title(ax1, ['Original: ', originals(idx).filename]);
        set(im2, 'CData', cropped{idx});
    end
end
