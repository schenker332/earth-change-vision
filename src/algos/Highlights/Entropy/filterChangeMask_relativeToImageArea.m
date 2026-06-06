function filteredMask = filterChangeMask_relativeToImageArea(changeMap, strengthThreshold, areaRatio, minAbsPixels)
% filterChangeMask_relativeToImageArea - Filtert Änderungskarte nach Stärke & Fläche relativ zur Bildgröße
%
% Eingabe:
%   changeMap         - Grauwert- oder Binärbild (0–1 normiert)
%   strengthThreshold - relative Stärke (0–1) bezogen auf Maximalwert
%   areaRatio         - relative Mindestfläche zur Bildgröße (0–1)
%   minAbsPixels      - Mindestanzahl absoluter Pixel (optional)
%
% Ausgabe:
%   filteredMask      - binäre Maske mit gültigen Änderungsregionen

if nargin < 4
    minAbsPixels = 10;
end

% Stärke-Schwellenwert anwenden
maxVal = max(changeMap(:));
binaryMask = changeMap > (strengthThreshold * maxVal);

% Cluster extrahieren
labeled = bwlabel(binaryMask);
stats = regionprops(labeled, 'Area');

if isempty(stats)
    filteredMask = false(size(changeMap));
    return;
end

% Gesamtbildfläche berechnen
totalPixels = numel(changeMap);

% Regionen selektieren nach relativer & absoluter Fläche
areas = [stats.Area];
validLabels = find((areas >= areaRatio * totalPixels) & (areas >= minAbsPixels));

% Ausgabe
filteredMask = ismember(labeled, validLabels);
end