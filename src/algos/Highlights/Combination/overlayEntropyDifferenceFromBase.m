function overlay = overlayEntropyDifferenceFromBase(imageList, varargin)
% overlayEntropyDifferenceFromBase
% Visualisiert Entropieänderungen bezogen auf das erste Bild
% Alle Änderungen werden als Heatmap-Umrisse über Bild 1 gelegt
%
% Optional:
%   'Threshold'     - Entropie-Änderungsschwelle (0–1), default: 0.1
%   'AreaThreshold' - minimale Fläche relativ zur Bildgröße (0–1), default: 0.0005
%   'RegionMask'    - logische Maske, default: []
%   'ColorList'     - RGB-Farben für jede Zeitstufe

p = inputParser;
addRequired(p, 'imageList', @(x) iscell(x) && numel(x) >= 2);
addParameter(p, 'Threshold', 0.1);
addParameter(p, 'AreaThreshold', 0.0005);
addParameter(p, 'RegionMask', []);
addParameter(p, 'ColorList', []);
parse(p, imageList, varargin{:});

images = p.Results.imageList;
threshold = p.Results.Threshold;
areaThreshold = p.Results.AreaThreshold;
regionMask = p.Results.RegionMask;
colorList = p.Results.ColorList;

baseImg = im2double(images{1});
[h, w, ~] = size(baseImg);
overlay = baseImg;

numSteps = numel(images) - 1;
if isempty(colorList)
    colorList = lines(numSteps);
end
if size(colorList, 1) < numSteps
    warning('ColorList zu kurz – zyklisch wiederverwendet');
end

overlayLayer = zeros(h, w, 3);
maskCombined = false(h, w);

for i = 2:numel(images)
    diffMap = computeEntropyDifference(images{1}, images{i}, regionMask);
    normDiff = mat2gray(diffMap);

    % Flächenbasierte Filterung
    mask = filterChangeMask_relativeToImageArea(normDiff, threshold, areaThreshold);
    edges = edge(mask, 'Canny');
    edges = imdilate(edges, strel('diamond', 1));
    newEdges = edges & ~maskCombined;

    c = colorList(mod(i-2, size(colorList,1)) + 1, :);
    for ch = 1:3
        layer = overlayLayer(:,:,ch);
        layer(newEdges) = c(ch);
        overlayLayer(:,:,ch) = layer;
    end

    maskCombined = maskCombined | newEdges;
end

mask3 = repmat(maskCombined, 1, 1, 3);
overlay(mask3) = 0.4 * overlay(mask3) + 0.6 * overlayLayer(mask3);
end
