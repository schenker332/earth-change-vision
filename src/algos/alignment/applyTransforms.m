function processed = applyTransforms(images, tforms)
% APPLYTRANSFORMS Wendet geometrische Transformationen auf Eingabebilder an.
%   Verwandelt jedes RGB- und Graustufenbild mithilfe der entsprechenden Transformation,
%   berechnet eine gemeinsame Ausgabefläche und überlappende Begrenzungsbox,
%   und schneidet alle transformierten Bilder auf diesen gemeinsamen Bereich zu.
%
% Eingaben:
%   images   - 1xN Struktur-Array mit Feldern:
%                .rgb      RGB-Bild (HxWx3)
%                .gray     Graustufenbild (HxW)
%                .filename Dateiname als String
%   tforms   - 1xN Array von geometric2dtransformer-Objekten für die Transformationen
%
% Ausgabe:
%   processed - 1xN Struktur-Array mit den transformierten Bildern und Dateinamen

N = numel(images);
% 1) Gemeinsamen Canvas berechnen
[H, W, ~] = size(images(1).rgb);
xL = zeros(N,2); yL = zeros(N,2);
for k = 1:N
    [xL(k,:), yL(k,:)] = outputLimits(tforms(k), [1 W], [1 H]);
end
xMin = floor(min(xL(:)));   xMax = ceil(max(xL(:)));
yMin = floor(min(yL(:)));   yMax = ceil(max(yL(:)));
Rout = imref2d([yMax-yMin+1, xMax-xMin+1], [xMin xMax], [yMin yMax]);

% 2) Alle Bilder warpen
warpedRGB  = cell(1,N);
warpedGray = cell(1,N);
for k = 1:N
    warpedRGB{k}  = imwarp(images(k).rgb,  tforms(k), 'OutputView', Rout);
    warpedGray{k} = imwarp(images(k).gray, tforms(k), 'OutputView', Rout);
end

% 3) Pro Bild individuelle Bounding-Box des Nicht-Schwarz-Bereichs
x1_i = zeros(N,1); x2_i = zeros(N,1);
y1_i = zeros(N,1); y2_i = zeros(N,1);
for k = 1:N
    mask = any(warpedRGB{k}~=0,3) & (warpedGray{k}~=0);
    [rows, cols] = find(mask);
    x1_i(k) = min(cols);
    x2_i(k) = max(cols);
    y1_i(k) = min(rows);
    y2_i(k) = max(rows);
end

% 4) Schnitt aller Bounding-Boxen → gemeinsames Rechteck
x1 = min(x1_i);
x2 = max(x2_i);
y1 = min(y1_i);
y2 = max(y2_i);
commonRect = [x1, y1, x2-x1+1, y2-y1+1];

% 5) Crop aller Bilder auf diesen gemeinsamen Bereich
processed = repmat(struct('filename','', 'rgb', [], 'gray', []), 1, N);
for k = 1:N
    processed(k).filename = images(k).filename;
    processed(k).rgb      = imcrop(warpedRGB{k},  commonRect);
    processed(k).gray     = imcrop(warpedGray{k}, commonRect);
end
end