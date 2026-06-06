function overlay = overlayEntropyDifferenceSequential(imageList, varargin)
% overlayEntropyDifferenceSequential
% Visualisiert Entropieänderungen zwischen aufeinanderfolgenden Bildern
% und legt sie alle auf Bild 1. Zusätzlich gefiltert nach Stärke & Fläche.
%
% Eingabe:
%   imageList         - Zellarray mit RGB-Bildern
%
% Optionale Name-Value-Paare:
%   'Threshold'       - Änderungsstärke-Schwelle (0–1), default: 0.1
%   'AreaThreshold'   - relative Mindestfläche (0–1), default: 0.0005
%   'RegionMask'      - logische Maske oder [], default: gesamtes Bild
%   'ColorList'       - [n x 3] RGB-Farben, default: lines()

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
    warning('ColorList zu kurz – Farben werden zyklisch wiederverwendet');
end

overlayLayer = zeros(h, w, 3);
maskCombined = false(h, w);

for i = 1:numSteps
    diffMap = computeEntropyDifference(images{i}, images{i+1}, regionMask);
    normDiff = mat2gray(diffMap);

    % Verwende robusten Flächenfilter
    changeMask = filterChangeMask_relativeToImageArea(normDiff, threshold, areaThreshold);

    edges = edge(changeMask, 'Canny');
    edges = imdilate(edges, strel('diamond', 1));
    newEdges = edges & ~maskCombined;

    c = colorList(mod(i-1, size(colorList,1)) + 1, :);
    for ch = 1:3
        channel = overlayLayer(:,:,ch);
        channel(newEdges) = c(ch);
        overlayLayer(:,:,ch) = channel;
    end

    maskCombined = maskCombined | newEdges;
end

% Mischung erzeugen
mask3 = repmat(maskCombined, 1, 1, 3);
overlay(mask3) = 0.4 * overlay(mask3) + 0.6 * overlayLayer(mask3);
end
