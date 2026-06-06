function entropyDiff = computeEntropyDifference(img1, img2, regionMask)
% computeEntropyDifference - Berechnet Entropieänderung zwischen zwei Bildern
%
% Eingaben:
%   img1, img2     - RGB-Bilder (uint8 oder double)
%   regionMask     - (optional) logische Maske für Bereichsauswertung
%
% Ausgabe:
%   entropyDiff    - nicht normierte Entropiedifferenz (Messwert)

if nargin < 3
    regionMask = [];
end

if ~isequal(size(img1), size(img2))
    img2 = imresize(img2, [size(img1,1), size(img1,2)]);
end

img1Gray = rgb2gray(im2double(img1));
img2Gray = rgb2gray(im2double(img2));

entropy1 = entropyfilt(img1Gray, true(9));
entropy2 = entropyfilt(img2Gray, true(9));

entropyDiff = abs(entropy2 - entropy1);

if ~isempty(regionMask)
    entropyDiff(~regionMask) = 0;
end
end


