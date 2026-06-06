function overlay = overlayChangeContoursOverTimePrioritized(imageList, varargin)
% overlayChangeContoursOverTimePrioritized
% Visualisiert Veränderungskanten über Zeit (älteste Linien behalten Vorrang)
%
% Eingabe (Pflicht):
%   imageList       - Zell-Array mit RGB-Bildern (mind. 2)
%
% Name-Value-Pairs (optional):
%   'StrengthThreshold' - Änderungsschwelle (0–1), default: 0.1
%   'AreaThreshold'     - minimale Regionfläche relativ zum Bild (0–1), default: 0.0005
%   'RegionMask'        - logische Matrix oder [] für ganzes Bild
%   'ColorList'         - [n x 3] RGB-Farben, z. B. [1 0 0; 0 1 0; 0 0 1]

% === Pflicht prüfen ===
assert(iscell(imageList) && numel(imageList) >= 2, ...
    'imageList muss ein Zell-Array mit mindestens 2 Bildern sein.');

% === Optionalparameter parsen ===
p = inputParser;
addParameter(p, 'StrengthThreshold', 0.1);
addParameter(p, 'AreaThreshold', 0.0005);
addParameter(p, 'RegionMask', []);
addParameter(p, 'ColorList', []);
parse(p, varargin{:});

strengthThreshold = p.Results.StrengthThreshold;
areaThreshold = p.Results.AreaThreshold;
regionMask = p.Results.RegionMask;
colorList = p.Results.ColorList;

% === Basisbild ===
baseImg = imageList{1};
overlay = im2double(baseImg);
[h, w, ~] = size(baseImg);

% === Farben vorbereiten ===
numSteps = numel(imageList) - 1;
if isempty(colorList)
    colorList = lines(numSteps);  % Default: MATLAB-Farbschema
end
if size(colorList, 1) < numSteps
    warning('ColorList zu kurz – Farben werden zyklisch wiederverwendet');
end

% === Layer vorbereiten ===
colorOverlay = zeros(h, w, 3);
maskCombined = false(h, w);

% === Kantenverarbeitung ===
for i = 2:numel(imageList)
    currImg = imageList{i};

    changeMask = computeChangeMask(baseImg, currImg, ...
        regionMask, strengthThreshold, areaThreshold);

    edges = edge(changeMask, 'Canny');
    edges = imdilate(edges, strel('diamond', 1));
    newEdges = edges & ~maskCombined;

    c = colorList(mod(i-2, size(colorList,1)) + 1, :);

    for ch = 1:3
        channel = colorOverlay(:,:,ch);
        channel(newEdges) = c(ch);
        colorOverlay(:,:,ch) = channel;
    end

    maskCombined = maskCombined | newEdges;
end

% === Overlay erzeugen ===
mask3 = repmat(maskCombined, 1, 1, 3);
overlay(mask3) = 0.4 * overlay(mask3) + 0.6 * colorOverlay(mask3);

% === Anzeige vorbereiten ===
figure;
imshow(overlay);
title('Veränderungskanten über Zeit (älteste zuerst, farbig kodiert)');
hold on;

% === Position der Legende ===
xPos = 20;
yPos = 20;
dy = 20;

% === Helligkeit im Legendenbereich schätzen (100x100-Pixelblock)
blockSize = 100;
xEnd = min(xPos + blockSize - 1, size(overlay,2));
yEnd = min(yPos + blockSize - 1, size(overlay,1));
legendArea = overlay(yPos:yEnd, xPos:xEnd, :);
avgBrightness = mean(legendArea(:));  % Mittelwert über RGB

% === Einheitliche Schriftfarbe bestimmen
if avgBrightness < 0.5
    textColor = 'w';
else
    textColor = 'k';
end

% === Legende zeichnen
for i = 2:numel(imageList)
    c = colorList(mod(i-2, size(colorList,1)) + 1, :);
    labelStr = sprintf('Schritt %d (Bild %d → %d)', i-1, 1, i);

    rectangle('Position', [xPos, yPos + (i-2)*dy, 12, 12], ...
        'FaceColor', c, 'EdgeColor', c);

    text(xPos + 18, yPos + (i-2)*dy + 10, labelStr, ...
        'Color', textColor, 'FontSize', 10, 'FontWeight', 'bold');
end

end
