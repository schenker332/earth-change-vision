function renderEntropyView(ax, img1, img2, visMode, strengthThresh, areaThresh)
% renderEntropyView - Zeichnet die Entropie-Analyse in die gegebene UIAxes
%
% Inputs:
%   ax             - Handle auf eine uiaxes
%   img1, img2     - RGB-Bilder der beiden Zeitpunkte
%   visMode        - 'heatmap', 'overlay' oder 'surface'
%   strengthThresh - relative Stärke-Schwelle (0–1)
%   areaThresh     - relative Flächen-Schwelle (0–1)
blackMask = all(img1 == 0, 3) | all(img2 == 0, 3);
for c = 1:3
    img1Channel = img1(:,:,c);
    img2Channel = img2(:,:,c);
    img1Channel(blackMask) = 0;
    img2Channel(blackMask) = 0;
    img1(:,:,c) = img1Channel;
    img2(:,:,c) = img2Channel;
end
% Bilder und Parameter sind als Argumente übergeben
% Entropiedifferenz berechnen + normalisieren
raw    = computeEntropyDifference(img1, img2, []);
rawN   = mat2gray(raw);

% Maske basierend auf Stärke & Fläche anwenden
mask       = filterChangeMask_relativeToImageArea(rawN, strengthThresh, areaThresh);
entropyMap = rawN;
entropyMap(~mask) = 0;

% UIAxes zurücksetzen
cla(ax, 'reset');

% Visualisieren je nach Modus
switch lower(visMode)
    case 'heatmap'
        imshow(entropyMap, [], 'Parent', ax);
        colormap(ax, 'jet'); colorbar(ax);
        view(ax, 2);

    case 'overlay'
        visualizeEntropyOverlay(entropyMap, img1, ax);
        view(ax, 2);

    case 'surface'
        visualizeEntropySurface(entropyMap, ax);
        % view(ax,3) innerhalb der Funktion

    otherwise
        error('Ungültiger visMode: %s', visMode);
end

axis(ax, 'off');
end
