function tforms = estimateTransforms(images)
% ESTIMATETRANSFORMS Schätzt geometrische Transformationen zwischen Graustufenbildern.
%   Ermittelt SURF-Features im Referenzbild und im aktuellen Bild,
%   führt Feature-Matching durch und schätzt eine affine Transformation.
%   Bei zu wenigen Übereinstimmungen wird eine Identitätstransformation verwendet.
%
% Eingaben:
%   images - 1xN Struktur-Array mit Feldern:
%              .gray     Graustufenbild (HxW)
%              .filename Dateiname als String
%
% Ausgabe:
%   tforms - 1xN Array von affine2d-Objekten mit den geschätzten Transformationen
numImages = numel(images);
tforms(numImages) = affine2d(eye(3));
refGray = images(1).gray;
refPoints = detectSURFFeatures(refGray);
[refFeatures, refValidPoints] = extractFeatures(refGray, refPoints);

for k = 2:numImages
    currGray = images(k).gray;
    currPoints = detectSURFFeatures(currGray);
    [currFeatures, currValidPoints] = extractFeatures(currGray, currPoints);

    indexPairs = matchFeatures(currFeatures, refFeatures, 'Unique', true, 'MatchThreshold', 50);

    if size(indexPairs, 1) < 5
        warning('Too few matches for %s. Identity transform used.', images(k).filename);
        tforms(k) = affine2d(eye(3));
        continue;
    end

    matchedCurr = currValidPoints(indexPairs(:,1));
    matchedRef = refValidPoints(indexPairs(:,2));
    tforms(k) = estimateGeometricTransform2D(matchedCurr, matchedRef, 'affine', 'MaxDistance', 5);
end
end

