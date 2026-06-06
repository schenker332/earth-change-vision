function testOverlayChangeContoursOverTimePrioritized( ...
    strengthThreshold, areaThreshold, regionMask, colorList)

% === Defaultwerte setzen, wenn nichts übergeben ===
if nargin < 1 || isempty(strengthThreshold)
    strengthThreshold = 0.1;
end
if nargin < 2 || isempty(areaThreshold)
    areaThreshold = 0.08;
end
if nargin < 3
    regionMask = [];
end
if nargin < 4
    colorList = [];  % wird automatisch in der Funktion gesetzt
end


% === Beispielbilder laden ===
folder = fullfile('..','resources','locations','sample_location_1');
files = dir(fullfile(folder, '*.jpg'));

% Extrahiere Jahreszahl (nicht stabil, ambesten richtig übergeben)
names = {files.name};
[~, idx] = sort(names);
filenames = names(idx);




% === Bildreihe einlesen ===
imageList = cell(1, numel(filenames));
for i = 1:numel(filenames)
    imageList{i} = imread(fullfile(folder, filenames{i}));
end

% === RegionMask generieren falls gewünscht (z. B. manuell eingrenzen) ===
if isequal(regionMask, 'sample')
    imgSize = size(imageList{1});
    regionMask = false(imgSize(1), imgSize(2));
    regionMask(100:300, 150:350) = true;  % Beispielregion
end

% === Hauptfunktion aufrufen ===
overlay = overlayChangeContoursOverTimePrioritized(imageList, ...
    'StrengthThreshold', strengthThreshold, ...
    'AreaThreshold', areaThreshold, ...
    'RegionMask', regionMask, ...
    'ColorList', colorList);

% === Speichern (optional) ===
imwrite(overlay, 'output_overlayContours.png');

end