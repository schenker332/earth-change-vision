function [images, filenames] = loadAndPreprocessing(folderPath)
% LOADANDPREPROCESSING  Load images from folder ohne Resize und Normalize
%   [images, filenames] = loadAndPreprocessing(folderPath)
%   folderPath: Pfad zum Ordner mit .jpg/.png
%   images: struct array mit Feldern
%     .filename : Dateiname
%     .rgb      : Original-RGB-Bild (uint8)
%     .gray     : Graustufenbild (uint8)
%   filenames: Cell-Array aller eingelesenen Dateinamen

% 1) Suche JPG- und PNG-Dateien
jpgFiles = dir(fullfile(folderPath, '*.jpg'));
pngFiles = dir(fullfile(folderPath, '*.png'));
imgFiles = [jpgFiles; pngFiles];
if isempty(imgFiles)
    error('Keine Bilder in %s gefunden.', folderPath);
end

% 2) Sortieren nach Dateiname
[~, sortedIdx] = sort({imgFiles.name});
imgFiles = imgFiles(sortedIdx);
N = numel(imgFiles);

% 3) Initialisiere Ausgabestruktur
images = repmat(struct('filename','', 'rgb', [], 'gray', []), 1, N);

fprintf('Lade %d Bilder aus %s\n', N, folderPath);

% 4) Einlesen und Graustufen erzeugen
for k = 1:N
    fname = imgFiles(k).name;
    I_rgb = imread(fullfile(folderPath, fname));   % RGB-Bild im Originalformat
    I_gray = rgb2gray(I_rgb);                      % einfache Graustufe

    images(k).filename = fname;
    images(k).rgb      = I_rgb;
    images(k).gray     = I_gray;
end

fprintf('Fertig: %d Bilder geladen.\n', N);

% 5) Array mit allen Dateinamen
filenames = {images.filename};
end