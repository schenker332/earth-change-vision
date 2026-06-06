imgDir = fullfile('resources', 'locations', 'sample_location_1');
imgFiles = dir(fullfile(imgDir, '*.jpg'));
[~, idx] = sort({imgFiles.name});
imagePaths = fullfile(imgDir, {imgFiles(idx).name});

[croppedImages, commonMask] = findCommonVisibleRegion(imagePaths);

%show all
for k = 1:length(croppedImages)
    figure;
    imshow(croppedImages{k});
    title(sprintf('Cropped Image %d', k));
end
