function overlayImg = computeOverlayMapColour(img1, img2, colorMode)
% computeOverlayMapColour - Visualisiert Unterschiede zwischen zwei RGB-Bildern
%
% Eingaben:
%   img1, img2   - RGB-Bilder gleicher Szene
%   colorMode    - 'all', 'red', 'green', 'yellow'
%
% Ausgabe:
%   overlayImg   - RGB-Overlay-Bild: rot = alt, grün = neu, gelb = gleich

if nargin < 3
    colorMode = 'all';
end


% Bildgrößen abgleichen
if ~isequal(size(img1), size(img2))
    img2 = imresize(img2, [size(img1,1), size(img1,2)]);
end

img1 = im2double(img1);
img2 = im2double(img2);

% Differenzstärke berechnen
diff = abs(img1 - img2);
diffStrength = mean(diff, 3);

% Helligkeit vergleichen
img1Mean = mean(img1, 3);
img2Mean = mean(img2, 3);

% Schwellen definieren
lowThresh = 0.1;
highThresh = 0.5;

similarMask       = diffStrength < lowThresh;
strongChangeMask  = diffStrength >= highThresh;
weakChangeMask    = diffStrength >= lowThresh;

% Initialisierung
overlayImg = zeros(size(img1));

% Rot – nur in img1 (entfernt oder stark verändert)
if any(strcmpi(colorMode, {'all', 'red'}))
    redMask = (img1Mean > img2Mean) & (weakChangeMask | strongChangeMask);
    overlayImg(:,:,1) = overlayImg(:,:,1) + diffStrength .* redMask;
end

% Grün – neu oder verändert in img2
if any(strcmpi(colorMode, {'all', 'green'}))
    greenMask = (img2Mean > img1Mean) & (weakChangeMask | strongChangeMask);
    overlayImg(:,:,2) = overlayImg(:,:,2) + diffStrength .* greenMask;
end

% Gelb – ähnlich
if any(strcmpi(colorMode, {'all', 'yellow'}))
    overlayImg(:,:,1) = overlayImg(:,:,1) + 0.5 * similarMask;
    overlayImg(:,:,2) = overlayImg(:,:,2) + 0.5 * similarMask;
end

overlayImg = min(overlayImg, 1);
end
