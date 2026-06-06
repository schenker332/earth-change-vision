function croppedRGB = cropToOverlapRegion(alignedRGB)
% CROPTOOVERLAPREGION Schneidet alle Bilder auf ihren gemeinsamen nicht-schwarzen Überlappungsbereich zu.
%   Ermittelt die Pixelbereiche, in denen alle Bilder nicht schwarz sind, berechnet deren
%   zusammenhängende Bounding Box und schneidet anschließend alle RGB-Bilder auf diesen
%   gemeinsamen Bereich zu.
%
% Eingaben:
%   alignedRGB - 1xN Zell-Array mit bereits ausgerichteten RGB-Bildern (HxWx3)
%
% Ausgabe:
%   croppedRGB - 1xN Zell-Array mit zugeschnittenen RGB-Bildern (HxWx3), beschränkt auf den gemeinsamen Bereich
numImages = numel(alignedRGB);
commonMask = true(size(rgb2gray(alignedRGB{1})));

for k = 1:numImages
    gray = rgb2gray(alignedRGB{k});
    mask = gray > 0;
    commonMask = commonMask & mask;
end

props = regionprops(commonMask, 'BoundingBox');
if isempty(props)
    error('No overlapping region with visible content found.');
end

bbox = round(props(1).BoundingBox);
x = bbox(1); y = bbox(2); w = bbox(3); h = bbox(4);
xEnd = min(size(commonMask,2), x+w-1);
yEnd = min(size(commonMask,1), y+h-1);

croppedRGB = cell(1, numImages);
for k = 1:numImages
    croppedRGB{k} = alignedRGB{k}(y:yEnd, x:xEnd, :);
end
end
