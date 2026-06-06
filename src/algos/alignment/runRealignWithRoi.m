function [images, dates, alignedMask, tforms] = runRealignWithRoi(images, dates, alignMask)
% RUNREALIGNWITHROI Führt die Neuausrichtung von Bildern anhand einer ROI-Maske durch.
%   Wendet die übergebene Maske an, erzeugt Graustufenbilder, baut eine Struktur
%   für das Alignment, führt das Referenz-Alignment durch, wendet die Transformationen
%   auf die RGB-Bilder an und erstellt die aktualisierten Bilder, Daten sowie Maske.
%
% Eingaben:
%   images     - 1xN Zell-Array mit RGB-Bildern (HxWx3)
%   dates      - 1xN Zell-Array mit Datums- oder Dateinamen-Strings
%   alignMask  - 1xN logisches oder numerisches Array zur Auswahl der zu alignierenden Bilder
%
% Ausgabe:
%   images       - 1xN Zell-Array mit den ausgerichteten RGB-Bildern (HxWx3)
%   dates        - 1xM Zell-Array mit Dateinamen der erfolgreich ausgerichteten Bilder
%   alignedMask  - 1xN logisches Array, True für ausgerichtete Bilder
%   tforms       - 1xM Array von geometric2dtransformer-Objekten für die Transformationen


mask = alignMask ~= 0;
imagesMasked = images(mask);
datesMasked = dates(mask);


% 1) Graubilder erzeugen
grayImages = cellfun(@(img) rgb2gray(img), imagesMasked, 'UniformOutput', false);

% 2) Struct-Array bauen
S = struct( ...
    'filename', datesMasked, ...
    'rgb',      imagesMasked, ...
    'gray',     grayImages ...
    );


% 3) Alignment durchführen
[tforms, ~, ~, ~, ~, ~, imagesAligned] = bestref_tree_roi(S);

rgbCells = applyTransforms(imagesAligned, tforms);

alignedImages = {rgbCells.rgb};
alignedDates = {rgbCells.filename};
newMask = false(1, numel(images));
for i = 1:numel(alignedDates)
    idx = find(strcmp(dates, alignedDates{i}));
    if ~isempty(idx)
        images{idx} = alignedImages{i};
        newMask(idx) = true;
    end
end
alignedMask = newMask;

end