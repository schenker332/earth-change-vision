function overlay = computeOverlayMap(img1, img2, alpha, changeMask)
% computeOverlayMap - Erstellt Overlay zweier Bilder mit optionaler Veränderungsmarkierung
%
% Eingaben:
%   img1, img2      - RGB-Bilder (uint8 oder double)
%   alpha           - Transparenzwert (0-1)
%   changeMask      - binäre Maske der Veränderungen (optional)
%
% Ausgabe:
%   overlay         - RGB-Bild mit optionaler Markierung

if nargin < 3, alpha = 0.3; end
if nargin < 4, changeMask = []; end

if ~isequal(size(img1), size(img2))
    img2 = imresize(img2, [size(img1,1), size(img1,2)]);
end

img1 = im2double(img1);
img2 = im2double(img2);

overlay = (1 - alpha) * img1 + alpha * img2;

if ~isempty(changeMask)
    edges = imdilate(edge(changeMask, 'Canny'), strel('diamond', 2));
    redOverlay = cat(3, ones(size(edges)), 0.3*ones(size(edges)), zeros(size(edges)));
    mask3 = repmat(edges, [1 1 3]);
    overlay(mask3) = overlay(mask3) * 0.3 + redOverlay(mask3) * 0.7;
end
end