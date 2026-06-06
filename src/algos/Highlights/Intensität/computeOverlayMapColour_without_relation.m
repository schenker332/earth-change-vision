function overlayImg = computeOverlayMapColour_without_relation(img1, img2, colorMode)
% computeOverlayMapColour - Visualisiert Veränderungen zwischen zwei RGB-Bildern
%
%   overlayImg = computeOverlayMapColour(img1, img2, colorMode)
%
%   Eingaben:
%     img1, img2  - RGB-Bilder der gleichen Szene zu verschiedenen Zeitpunkten
%     colorMode   - 'all', 'red', 'green', 'yellow'
%                  'red'   = nur alt (nur in img1 vorhanden)
%                  'green' = nur neu (nur in img2 vorhanden)
%                  'yellow'= nur gleich (ähnlich in beiden)
%                  'all'   = alle drei anzeigen
%
%   Ausgabe:
%     overlayImg  - RGB-Overlay-Bild mit Farbkodierung je nach Änderung

if nargin < 3
    colorMode = 'all'; % Standard
end

% Bildgrößen anpassen falls nötig
if ~isequal(size(img1), size(img2))
    img2 = imresize(img2, [size(img1,1), size(img1,2)]);
end

% In double konvertieren
img1 = im2double(img1);
img2 = im2double(img2);

% Differenz und Masken berechnen
diff = abs(img1 - img2);
threshold = 0.1;

% Masken
similarMask  = all(diff < threshold, 3);  % ähnlich → gelb
onlyInImg1   = all(img1 > 0.1, 3) & all(img2 < 0.1, 3); % alt → rot
onlyInImg2   = all(img2 > 0.1, 3) & all(img1 < 0.1, 3); % neu → grün

% Leeres Overlay
overlayImg = zeros(size(img1));

% ROT = nur in img1 vorhanden (alt)
if any(strcmpi(colorMode, {'all', 'red'}))
    overlayImg(:,:,1) = img1(:,:,1) .* onlyInImg1;
end

% GRÜN = nur in img2 vorhanden (neu)
if any(strcmpi(colorMode, {'all', 'green'}))
    overlayImg(:,:,2) = img2(:,:,2) .* onlyInImg2;
end

% GELB = beide ähnlich (gleich geblieben)
if any(strcmpi(colorMode, {'all', 'yellow'}))
    overlayImg(:,:,1) = overlayImg(:,:,1) + 0.5 * similarMask;
    overlayImg(:,:,2) = overlayImg(:,:,2) + 0.5 * similarMask;
end

% Auf Wertebereich begrenzen
overlayImg = min(overlayImg, 1);
end