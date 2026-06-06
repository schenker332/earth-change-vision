% In runSegmentation.m
function [rgbA, rgbB, classNames, colorNames, percentA, percentB, percentDiff] = runSegmentation(imageA, imageB, tformsA, tformsB)
    load("trainedUnet.mat", "net");

    % Bilder laden
    I1 = imread(imageA);
    I2 = imread(imageB);

    % Segmentierungsparameter
    patchSize = 256;
    unifiedClassNames = {'Wasser','Vegetation','Gebäude','Bebaute Fläche','Offenland'};
    unifiedColorMap   = [0 0 255;0 128 0;255 0 0;128 128 128;255 255 153]/255;
    colorNames        = {'Blau','Grün','Rot','Grau','Gelb'};

    % Segmentieren
    [fullLabelsA, overlayA, ~] = segmentImage(I1, net, patchSize, unifiedClassNames, unifiedColorMap);
    rgbA = labelsToRGB(fullLabelsA, unifiedColorMap);

    [fullLabelsB, overlayB, ~] = segmentImage(I2, net, patchSize, unifiedClassNames, unifiedColorMap);
    rgbB = labelsToRGB(fullLabelsB, unifiedColorMap);

    [trafA, trafB] = transformSegment(overlayA, overlayB, tformsA, tformsB);
    [rgbA, rgbB] = transformSegment(rgbA, rgbB, tformsA, tformsB);
    
    nC = numel(unifiedClassNames);
    countsA = zeros(nC,1);
    countsB = zeros(nC,1);
    % rgbA/rgbB sind uint8 oder double in [0,1]? Konvertiere zu 0–255:
    if isfloat(rgbA)
        tmpA = uint8(rgbA*255);
        tmpB = uint8(rgbB*255);
    else
        tmpA = rgbA;
        tmpB = rgbB;
    end
    cmap255 = uint8(unifiedColorMap*255);
    for k = 1:nC
        col = cmap255(k,:);
        maskA = tmpA(:,:,1)==col(1) & tmpA(:,:,2)==col(2) & tmpA(:,:,3)==col(3);
        maskB = tmpB(:,:,1)==col(1) & tmpB(:,:,2)==col(2) & tmpB(:,:,3)==col(3);
        countsA(k) = nnz(maskA);
        countsB(k) = nnz(maskB);
    end
    
    % Prozentwerte
    totalA    = sum(countsA);
    totalB    = sum(countsB);
    epsilon         = 1e-9;  
    
    % Prozentanteile in A und B (in %)
    percentA  = 100 * countsA ./ (totalA + epsilon);
    percentB  = 100 * countsB ./ (totalB + epsilon);

    percentDiff = (percentB ./ (percentA + epsilon) - 1) * 100;

    % Rückgabe
    classNames   = unifiedClassNames;
    colorNames   = colorNames;
end

function [out1, out2] = transformSegment(img1, img2, tform1, tform2)
% TRANSFORMSEGMENT  Warp & common-crop for exactly two RGB images
%   [out1, out2] = transformSegment(img1, img2, tform1, tform2)
%   img1, img2: HxWx3 RGB images
%   tform1, tform2: projective2d objects
%   out1, out2: cropped RGB images in their common visible region

    % Compute output canvas based on both transforms
    [H, W, ~] = size(img1);
    [xL1, yL1] = outputLimits(tform1, [1 W], [1 H]);
    [xL2, yL2] = outputLimits(tform2, [1 W], [1 H]);
    xMin = floor(min([xL1, xL2])); xMax = ceil(max([xL1, xL2]));
    yMin = floor(min([yL1, yL2])); yMax = ceil(max([yL1, yL2]));
    Rout = imref2d([yMax-yMin+1, xMax-xMin+1], [xMin xMax], [yMin yMax]);

    % Warp both RGB images
    out1 = imwarp(img1, tform1, 'OutputView', Rout);
    out2 = imwarp(img2, tform2, 'OutputView', Rout);

    blackMask = all(out1 == 0, 3) | all(out2 == 0, 3);
    for c = 1:3
        out1Channel = out1(:,:,c);
        out2Channel = out2(:,:,c);
        out1Channel(blackMask) = 0;
        out2Channel(blackMask) = 0;
        out1(:,:,c) = out1Channel;
        out2(:,:,c) = out2Channel;
    end
    
    % 3) Pro Bild Bounding-Box des nicht-schwarzen Bereichs ermitteln
    mask1 = any(out1~=0, 3);
    mask2 = any(out2~=0, 3);
    
    [rows1, cols1] = find(mask1);
    [rows2, cols2] = find(mask2);
    
    % falls einer der Masken leer ist, kein Zuschneiden
    if isempty(rows1) || isempty(rows2)
        commonRect = [1, 1, size(out1,2), size(out1,1)];
    else
        % Koordinaten für Bild 1
        x1_1 = min(cols1);  x2_1 = max(cols1);
        y1_1 = min(rows1);  y2_1 = max(rows1);
        % Koordinaten für Bild 2
        x1_2 = min(cols2);  x2_2 = max(cols2);
        y1_2 = min(rows2);  y2_2 = max(rows2);
    
        % Gemeinsame Bounding-Box
        x1 = min(x1_1, x1_2);
        x2 = max(x2_1, x2_2);
        y1 = min(y1_1, y1_2);
        y2 = max(y2_1, y2_2);
    
        commonRect = [x1, y1, x2 - x1 + 1, y2 - y1 + 1];
    end
    
    % 4) Beide Bilder auf die gemeinsame Region zuschneiden
    out1 = imcrop(out1, commonRect);
    out2 = imcrop(out2, commonRect);
end


function rgbLabels = labelsToRGB(fullLabels, colorMap)
% LABELSTORGB  Convert a categorical H×W label image into an H×W×3 RGB image
%   rgbLabels = labelsToRGB(fullLabels, colorMap)
%     fullLabels : categorical array of size H×W, categories 1..C
%     colorMap   : C×3 double, each row in [0,1]
%     rgbLabels  : H×W×3 uint8

    idx = double(fullLabels);           % map each pixel to 1..C
    [H,W] = size(idx);
    rgbLabels = zeros(H,W,3,'uint8');

    for c = 1:size(colorMap,1)
        mask = (idx == c);
        % scale [0–1] to [0–255]
        color255 = uint8(round(colorMap(c,:)*255));
        for ch = 1:3
            chan = rgbLabels(:,:,ch);
            chan(mask) = color255(ch);
            rgbLabels(:,:,ch) = chan;
        end
    end
end