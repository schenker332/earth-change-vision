function changeMask = computeChangeMask(img1, img2, regionMask, ...
        strengthThreshold, areaThreshold)

% COMPUTECHANGEMASK Berechnet eine Änderungsmaske zwischen zwei Bildern.
%   Wandelt die Eingabebilder in Graustufen um, berechnet die absolute Differenz,
%   glättet das Ergebnis, schränkt die Analyse auf die RegionMask ein und
%   wendet einen binären Schwellenwert oder einen Filter basierend auf Stärke-
%   und Flächenschwellenwerten an.
%
% Eingaben:
%   img1              - RGB-Bild vor der Änderung (HxWx3, uint8 oder double)
%   img2              - RGB-Bild nach der Änderung (HxWx3, uint8 oder double)
%   regionMask        - Logische Maske (HxW) zur Einschränkung des Analysebereichs (optional)
%   strengthThreshold - Schwellenwert für Differenzstärke (0-1, optional)
%   areaThreshold     - Schwellenwert für Flächenfilterung relativ zur Bildgröße (0-1, optional)
%
% Ausgabe:
%   changeMask        - Logische Maske (HxW) mit erkannten Änderungen

if nargin < 3, regionMask       = [];  end
if nargin < 4, strengthThreshold = 0;  end
if nargin < 5, areaThreshold     = 0;  end

img1Gray = rgb2gray(im2double(img1));
img2Gray = rgb2gray(im2double(img2));

if isempty(regionMask)
    % „echte“ Bildpixel ≙ Helligkeit > 0 (Toleranz 0.02)
    mask1 = any(im2double(img1) > 0.02, 3);
    mask2 = any(im2double(img2) > 0.02, 3);

    % Nur der Schnitt beider Masken zählt
    regionMask = mask1 & mask2;

    % Ein paar Pixel vom Rand wegnehmen, um Rest-Artefakte zu vermeiden
    regionMask = imerode(regionMask, strel('diamond',2));
end

diffMap = abs(img1Gray - img2Gray);
diffMap = imgaussfilt(diffMap, 1);            % Glättung
diffMap(~regionMask) = 0;                     % alles außerhalb ignorieren

% --- binarisieren wie gehabt ----------------------------------------
if strengthThreshold > 0 || areaThreshold > 0
    changeMask = filterChangeMask_relativeToImageArea( ...
        diffMap,strengthThreshold,areaThreshold);
else
    changeMask = imbinarize(diffMap, graythresh(diffMap));
end
end
