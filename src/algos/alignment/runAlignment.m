function [imgs, dates, alignedMask, tforms] = runAlignment(folderPath)
% RUNALIGNMENT  Lädt, sortiert, aligned, normalisiert und liefert Zell-Arrays
%   [imgs, dates, alignedMask] = runAlignment(folderPath)
%
% Inputs:
%   folderPath  Pfad zu Deinem Bilder-Ordner
%
% Outputs:
%   imgs   1×N cell array mit den finalen M×P×3 uint8 RGB-Bildern
%   dates  1×N cell array mit den Dateinamen (ohne ".jpg")

% 2) Preprocess & sort
[images, ~] = loadAndPreprocessing(folderPath);

[imagesSorted, ~] = sortImagesByTimestamp(images);
[tforms, ~, ~, ~, ~, ~, imagesAligned] = bestref_tree_proj(imagesSorted, 'center');

rgbCells = applyTransforms(imagesAligned, tforms);
imgs  = {rgbCells.rgb};

% Dateinamen ohne ".jpg"
rawNames = {rgbCells.filename};
dates    = cellfun(@(f) f(1:end-4), rawNames, 'UniformOutput', false);
% Dateilisten vergleichen: welche der sortierten Bilder haben es
% tatsächlich in rgbCells geschafft?
allFiles      = {imagesSorted.filename};
alignedFiles  = {rgbCells.filename};
alignedMask   = ismember(allFiles, alignedFiles);

% am Ende der Funktion
imgsAll  = {imagesSorted.rgb};     % Original-Reihenfolge
ai       = 1;
for k = 1:numel(imgsAll)
    if alignedMask(k)
        imgsAll{k} = imgs{ai};     % transformierte Version
        ai = ai + 1;
    end
end
imgs  = imgsAll;                   % gebe komplette Liste zurück
dates = cellfun(@(f) f(1:end-4), {imagesSorted.filename}, 'uni', false);


end