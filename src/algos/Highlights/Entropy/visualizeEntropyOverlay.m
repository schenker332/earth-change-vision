function visualizeEntropyOverlay(entropyMap, baseImg, ax)
% visualizeEntropyOverlay - Zeigt Entropiekarte als semitransparentes Overlay
% auf der übergebenen Achse (anstatt in neuem Figure).
%
% Eingabe:
%   entropyMap - 2D-Matrix (Entropieänderungen, normalisiert [0,1])
%   baseImg    - RGB-Bild (z. B. img1 oder img2)
%   ax         - Handle auf eine uiaxes-Instanz

if nargin<3 || isempty(ax)
    % Fallback: normales Figure
    ax = axes;
end

% Berechnungen wie gehabt
baseImg = im2double(baseImg);
entropyMap = mat2gray(entropyMap);
overlayColor = cat(3, ones(size(entropyMap)), zeros(size(entropyMap)), zeros(size(entropyMap)));
alphaMap = entropyMap;
result = baseImg .* (1 - alphaMap) + overlayColor .* alphaMap;

% In die UIAxes zeichnen
imshow(result, 'Parent', ax);
title(ax, 'Entropieänderung als Overlay (rot)');
axis(ax, 'off');
end
