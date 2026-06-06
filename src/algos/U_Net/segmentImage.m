function [fullLabels, overlayFull, totalCounts] = segmentImage(...
    fullImage, net, patchSize, unifiedClassNames, unifiedColorMap)

% SEGMENTIMAGE Führt semantische Segmentierung eines Bildes in Patches durch.
%   Unterteilt das vollständige Bild in Patches der Größe patchSize, segmentiert jedes
%   Patch mit dem angegebenen U-Net, vereinheitlicht die Klassenzuordnung, erstellt
%   ein überlagertes RGB-Ergebnisbild und zählt die Pixel pro Klasse.
%
% Eingaben:
%   fullImage           - RGB-Bild (HxWx3, uint8 oder double)
%   net                 - Vortrainiertes U-Net-Modell für semanticseg
%   patchSize           - Skalare Patch-Größe in Pixeln
%   unifiedClassNames   - Zell-Array mit einheitlichen Klassennamen (Strings)
%   unifiedColorMap     - N×3 Matrix mit RGB-Farben für die Klassenüberlagerung
%
% Ausgaben:
%   fullLabels          - HxW kategorisches Array mit Klassenzuordnung pro Pixel
%   overlayFull         - RGB-Bild (HxWx3) mit überlagertem Segmentierungsergebnis
%   totalCounts         - Vektor mit Pixel-Anzahl pro Klasse (Länge Anzahl Klassen)

[imgH, imgW, ~] = size(fullImage);
numRows = floor(imgH / patchSize);
numCols = floor(imgW / patchSize);

% Preallocate
overlayFull = fullImage;
totalCounts = zeros(numel(unifiedClassNames),1);
% Create an empty categorical map with the given class set:
fullLabels = repmat( ...
    categorical({''}, unifiedClassNames), ...
    imgH, imgW );

for row = 0:numRows-1
    for col = 0:numCols-1
        y = row*patchSize + 1;
        x = col*patchSize + 1;
        % extract patch
        patch = fullImage(y:y+patchSize-1, x:x+patchSize-1, :);

        % segment + unify classes
        rawLabels = semanticseg(patch, net);
        labels    = mapToUnifiedClasses(rawLabels);

        % accumulate counts
        for k = 1:numel(unifiedClassNames)
            totalCounts(k) = totalCounts(k) + nnz(labels == unifiedClassNames{k});
        end

        % overlay patch back into the RGB image
        patchOverlay = labeloverlay(patch, labels, ...
            'Colormap', unifiedColorMap, ...
            'Transparency', 0.4);
        overlayFull(y:y+patchSize-1, x:x+patchSize-1, :) = patchOverlay;

        % store the raw labels into the full map
        fullLabels(y:y+patchSize-1, x:x+patchSize-1) = labels;
    end
end

% For any border pixels beyond exact multiples of patchSize, you can
% optionally run one final partial patch or leave as '' (background).
end