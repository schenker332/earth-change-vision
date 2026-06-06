function overlay = overlayChangeContoursSequentially(imageList, varargin)
% overlayChangeContoursSequentially
% Visualisiert Veränderungskanten zwischen aufeinanderfolgenden Bildern,
% alle Kanten werden auf das erste Bild gelegt (älteste Linien haben Vorrang).
%
% Eingabe (Pflicht):
%   imageList - Zell-Array mit RGB-Bildern (mindestens 2)
%
% Optionale Name-Value-Paare:
%   'StrengthThreshold' - Änderungs-Schwelle [0–1], default: 0.1
%   'AreaThreshold'     - minimale Clusterfläche [0–1], default: 0.0005
%   'RegionMask'        - logische Maske oder [], default: gesamtes Bild
%   'ColorList'         - [n x 3] RGB-Farben, default: lines()

% === Eingaben parsen ===
p = inputParser;
addRequired(p, 'imageList', @(x) iscell(x) && numel(x) >= 2);
addParameter(p, 'StrengthThreshold', 0.1);
addParameter(p, 'AreaThreshold', 0.0005);
addParameter(p, 'RegionMask', []);
addParameter(p, 'ColorList', []);
parse(p, imageList, varargin{:});

images = p.Results.imageList;
strengthThreshold = p.Results.StrengthThreshold;
areaThreshold = p.Results.AreaThreshold;
regionMask = p.Results.RegionMask;
colorList = p.Results.ColorList;

% === Initialisierung ===
baseImg = im2double(images{1});
overlay = baseImg;
[h, w, ~] = size(baseImg);

numSteps = numel(images) - 1;
if isempty(colorList)
    colorList = lines(numSteps);
end
if size(colorList, 1) < numSteps
    warning('ColorList zu kurz – Farben werden zyklisch wiederverwendet');
end

colorOverlay = zeros(h, w, 3);
maskCombined = false(h, w);

% === Schritt-für-Schritt Vergleich (i vs i+1) ===
for i = 1:(numel(images) - 1)
    img1 = images{i};
    img2 = images{i+1};

    changeMask = computeChangeMask(img1, img2, ...
        regionMask, strengthThreshold, areaThreshold);

    edges = edge(changeMask, 'Canny');
    edges = imdilate(edges, strel('diamond', 1));
    newEdges = edges & ~maskCombined;

    c = colorList(mod(i-1, size(colorList,1)) + 1, :);
    for ch = 1:3
        channel = colorOverlay(:,:,ch);
        channel(newEdges) = c(ch);
        colorOverlay(:,:,ch) = channel;
    end

    maskCombined = maskCombined | newEdges;
end

% === Ergebnisüberlagerung ===
mask3 = repmat(maskCombined, 1, 1, 3);
overlay(mask3) = 0.4 * overlay(mask3) + 0.6 * colorOverlay(mask3);

% % === Legende anzeigen ===
% figure;
% imshow(overlay);
% title('Kantenverlauf zwischen aufeinanderfolgenden Bildern (älteste zuerst)');
% hold on;

% % Helligkeit im Bereich oben links für Schriftfarbe schätzen
% xPos = 20;
% yPos = 20;
% dy = 20;
% blockSize = 100;
% xEnd = min(xPos + blockSize - 1, w);
% yEnd = min(yPos + blockSize - 1, h);
% legendArea = overlay(yPos:yEnd, xPos:xEnd, :);
% avgBrightness = mean(legendArea(:));
% textColor = 'w';
% if avgBrightness >= 0.5
%     textColor = 'k';
% end

% % Farblegende für Schritte
% for i = 1:numSteps
%     c = colorList(mod(i-1, size(colorList,1)) + 1, :);
%     labelStr = sprintf('Schritt %d (Bild %d → %d)', i, i, i+1);
%     rectangle('Position', [xPos, yPos + (i-1)*dy, 12, 12], ...
%               'FaceColor', c, 'EdgeColor', c);
%     text(xPos + 18, yPos + (i-1)*dy + 10, labelStr, ...
%          'Color', textColor, 'FontSize', 10, 'FontWeight', 'bold');
% end
end
