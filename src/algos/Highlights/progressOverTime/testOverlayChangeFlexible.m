function testOverlayChangeFlexible(type, threshold, areaThreshold, regionMask, colorList)
% testOverlayChangeFlexible
% Visualisiert Veränderungskanten oder Entropiekanten zwischen Bildern
%
% Eingaben:
%   type          - 'base' oder 'sequential'
%   threshold     - Schwelle (optional, für beide)
%   areaThreshold - Fläche
%   regionMask    - logische Maske (optional)
%   colorList     - RGB-Farben (optional)

% === For quick testing ===
type = 'sequential';


% === Standardwerte setzen ===
if nargin < 3 || isempty(threshold), threshold = 0.1; end
if nargin < 4 || isempty(areaThreshold), areaThreshold = 0.006; end
if nargin < 5, regionMask = []; end
if nargin < 6, colorList = []; end

% === Beispielbilder laden ===
folder = fullfile('..','resources','locations','sample_location_0');
files = dir(fullfile(folder, '*.jpg'));
names = sort({files.name});
images = cellfun(@(f) imread(fullfile(folder,f)), names, 'UniformOutput', false);

switch lower(type)
    case 'base'
        overlay = overlayChangeContoursOverTimePrioritized(images, ...
            'StrengthThreshold', threshold, ...
            'AreaThreshold', areaThreshold, ...
            'RegionMask', regionMask, ...
            'ColorList', colorList);
    case 'sequential'
        overlay = overlayChangeContoursSequentially(images, ...
            'StrengthThreshold', threshold, ...
            'AreaThreshold', areaThreshold, ...
            'RegionMask', regionMask, ...
            'ColorList', colorList);
    otherwise
        error('Unbekannter Typ: %s', type);
end


% === Bild im Fenster anzeigen ===
figure;
imshow(overlay);

title(titleStr, 'FontWeight', 'bold');


% === Bild speichern (optional)
%imwrite(overlay, sprintf('output_%s_%s.png', method, type));
end
