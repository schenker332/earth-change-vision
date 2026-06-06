function [croppedImages, commonMask] = findCommonVisibleRegion(imagePaths)
% findCommonVisibleRegion - Lädt Bilder aus einem Ordner,
% schneidet sie auf eine robuste gemeinsame Region zu und speichert sie.
%
% Kombination aus gewichteter Maskenüberlappung + Bestbild-Referenz

% === Schritt 1: Ordner auswählen ===
baseDir = fullfile('resources', 'aligned_locations');
locationList = dir(baseDir);
locationList = locationList([locationList.isdir] & ~startsWith({locationList.name}, '.'));
names = {locationList.name};

% Auswahlfenster anzeigen
[selectionIdx, ok] = listdlg( ...
    'PromptString', 'Wähle einen Ort aus:', ...
    'SelectionMode', 'single', ...
    'ListString', names ...
    );

if ~ok
    disp('❌ Keine Auswahl getroffen. Abbruch.');
    return;
end

% Pfad zum gewählten Unterordner
imageDir = fullfile(baseDir, names{selectionIdx});

if imageDir == 0
    disp('❌ Kein Ordner ausgewählt. Abbruch.');
    return;
end

% === Schritt 2: Bilddateien einsammeln (mehrere Formate erlaubt) ===
files = [ ...
    dir(fullfile(imageDir, '*.png')); ...
    dir(fullfile(imageDir, '*.jpg')); ...
    dir(fullfile(imageDir, '*.jpeg')); ...
    dir(fullfile(imageDir, '*.tif')); ...
    dir(fullfile(imageDir, '*.tiff')) ...
    ];

if isempty(files)
    error('❌ Keine unterstützten Bilddateien im Ordner gefunden.');
end

imagePaths = fullfile({files.folder}, {files.name});
numImages = length(imagePaths);

% === Schritt 3: Bilder laden & Masken erstellen ===
images = cell(1, numImages);
masks = cell(1, numImages);
maskSizes = zeros(1, numImages);

for k = 1:numImages
    images{k} = imread(imagePaths{k});
    masks{k} = computeValidContentMask(images{k}, k);
    maskSizes(k) = sum(masks{k}(:));
end

% === Schritt 4: Bestes Bild als Referenz auswählen ===
[~, bestIdx] = max(maskSizes);
refMask = masks{bestIdx};

% === Schritt 5: Bilder mit zu geringer Overlap verwerfen ===
overlapThreshold = 0.7;
validIndices = [];

for k = 1:numImages
    overlap = sum(masks{k}(:) & refMask(:)) / sum(refMask(:));
    if overlap >= overlapThreshold
        validIndices(end+1) = k;
    else
        fprintf('⚠️ Bild %d ausgeschlossen (%.1f%% Overlap)\n', k, 100*overlap);
    end
end

if isempty(validIndices)
    error('❌ Kein ausreichend überlappendes Bild gefunden.');
end

% === Schritt 6: Gewichtetes Mittel bilden (z. B. ≥ 70 % Zustimmung) ===
selectedMasks = masks(validIndices);
maskStack = cat(3, selectedMasks{:});
meanMask = mean(maskStack, 3);
agreementThreshold = 0.7;
commonMask = meanMask >= agreementThreshold;

% Maske glätten und verbessern
commonMask = imclose(commonMask, strel('disk', 5));
commonMask = imfill(commonMask, 'holes');
commonMask = bwareaopen(commonMask, 500);

% BoundingBox berechnen
[rowIdx, colIdx] = find(commonMask);
if isempty(rowIdx)
    error('❌ Kein gemeinsamer sichtbarer Bereich gefunden.');
end
y = min(rowIdx); yEnd = max(rowIdx);
x = min(colIdx); xEnd = max(colIdx);

% === Schritt 7: Zuschneiden und Speichern ===
croppedImages = cell(1, numImages);
outputFolder = fullfile(imageDir, 'cropped_output');
if ~exist(outputFolder, 'dir'); mkdir(outputFolder); end

for k = 1:numImages
    % Überspringe ungültige Bilder
    if ~ismember(k, validIndices)
        continue;
    end
    croppedImages{k} = images{k}(y:yEnd, x:xEnd, :);
    [~, name, ~] = fileparts(imagePaths{k});
    outFile = fullfile(outputFolder, ['crop_' name '.png']);
    imwrite(croppedImages{k}, outFile);
    fprintf('✅ Bild %d gespeichert: %s\n', k, outFile);
end

% Maske zuschneiden
commonMask = commonMask(y:yEnd, x:xEnd);

% === Schritt 8: Anzeige ===
refImage = croppedImages{validIndices(1)};
maskedImage = refImage;

if size(refImage,3) == 3
    for c = 1:3
        channel = maskedImage(:,:,c);
        channel(~commonMask) = 0;
        maskedImage(:,:,c) = channel;
    end
else
    maskedImage(~commonMask) = 0;
end

figure;
subplot(1,2,1); imshow(commonMask); title('Gemeinsam sichtbare Maske');
subplot(1,2,2); imshow(maskedImage); title('Gemeinsamer Bereich im Referenzbild');

disp('🎉 Fertig! Gespeicherte Bilder im Ordner:');
disp(outputFolder);
end


function mask = computeValidContentMask(img, k)
% computeValidContentMask - Erstellt eine Binärmaske aller "nicht-schwarzen" Pixel

% In Grauwert umwandeln
if size(img, 3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end

% Schwellwert festlegen
mask = gray > 30;

% Nachbearbeitung: Lücken füllen, kleine Objekte entfernen
mask = imclose(mask, strel('disk', 7));
mask = imfill(mask, 'holes');
mask = bwareaopen(mask, 1000);

% Nur größte Region behalten
cc = bwconncomp(mask);
if cc.NumObjects > 0
    numPixels = cellfun(@numel, cc.PixelIdxList);
    [~, idx] = max(numPixels);
    mask(:) = 0;
    mask(cc.PixelIdxList{idx}) = 1;
end

% Vorschau (optional)
if nargin > 1 && k <= 5
    figure;
    subplot(1,2,1); imshow(gray); title(sprintf('Grauwert-Bild %d', k));
    subplot(1,2,2); imshow(mask); title('Maske: gültige Pixel');
end
end