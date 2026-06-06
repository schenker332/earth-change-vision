function [tforms, referenceIdxs, edgeWeights, idxPairsBest, inlierCounts, groups, images] = bestref_tree_roi(images, rootMode)
% Eingaben:
%   images        - 1xN Struktur-Array mit Feldern:
%                      .rgb      RGB-Bild (HxWx3)
%                      .gray     Graustufenbild (HxW)
%                      .filename Dateiname als String
%   rootMode      - Modus für die Wurzelwahl im Referenzbaum:
%                      'center', 'leaf', 'max' oder numerischer Index
%
% Ausgabe:
%   tforms         - 1xM Array von projective2d-Objekten für die finalen Transformationen
%   referenceIdxs  - 1xM Vektor mit Indizes der Referenzbilder jeder Komponente
%   edgeWeights    - 1xM Vektor mit Inlier-Zahlen für die gewählten Kanten
%   idxPairsBest   - 1xM Zell-Array mit Indexpaaren der besten Matches
%   inlierCounts   - MxM Matrix mit Anzahl der Inlier für alle Bildpaar-Kombinationen
%   groups         - 1xM Vektor mit Komponentenzugehörigkeit jedes Bildes
%   images         - 1xM Struktur-Array mit Bildern der größten identifizierten Komponente

% BESTREF_TREE_PROJ  Verkettete projektive Transforms & Referenzbaum pro Komponente
%   Erweiterung: Vor Alignment kann der Nutzer ROIs für jedes Bild
%   auswählen. Feature-Extraktion erfolgt nur innerhalb der ROIs.

if nargin<2, rootMode = 'center'; end
%% --- ROI-Auswahl via gemeinsames Overlay ---
N = numel(images);
% erstelle Grauwert-Overlay (Mittelwert)
sz = size(images(1).gray);
acc = zeros(sz);
for k = 1:N
    acc = acc + im2double(images(k).gray);
end
overlay = acc / N;

% overlay anzeigen & EINEN gemeinsamen ROI ziehen
fig = figure('Name','ROI-Auswahl: Overlay aller Bilder','Units','normalized','Position',[0 0 1 1], 'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','none' ...
    );
imshow(overlay,[]);
title('Zeichne ein einziges Rechteck für ALLE Bilder und klicke "Fertig"','FontSize',14);

hROI = drawrectangle('Color','r','LineWidth',2);
btn  = uicontrol(fig,'Style','pushbutton','String','Fertig', ...
    'FontSize',14,'Position',[20 20 100 40], ...
    'Callback',@(src,evt) uiresume(fig));

uiwait(fig);                   % warte auf Done
roiPos = round(hROI.Position); % [x y w h] für alle
close(fig);

% nun für jedes Bild dieselbe ROI-Position verwenden
rois = repmat({roiPos}, N, 1);

%% 1) SURF-Feature-Extraktion innerhalb ROIs
feats  = cell(N,1);
ptsAll = cell(N,1);
for k = 1:N
    Igray = images(k).gray;
    roi = rois{k};  % [x y w h]
    patch = imcrop(Igray, roi);
    ptsROI = detectSURFFeatures(patch, 'MetricThreshold',100);
    locFull = ptsROI.Location + roi(1:2);
    pts = SURFPoints(locFull);
    [f,v] = extractFeatures(Igray, pts);
    feats{k}  = f;
    ptsAll{k} = v;
end

%% 2) Paarweise Matches & direkte Transforms
maxCondAllowed  = 1.4;
maxDetDeviation = 0.8;
W       = zeros(N);
idxAll  = cell(N,N);
Tdir    = cell(N,N);
condRaw = nan(N,N);
detRaw  = nan(N,N);

for j = 1:N
    for i = j+1:N
        [idx, scores] = matchFeatures( ...
            feats{j}, feats{i}, ...
            'Method',            'Approximate', ...
            'Unique',            true,               ...
            'MaxRatio',          0.6,               ...
            'MatchThreshold',    10);

        keepFraction = 0.90;
        [~, order]   = sort(scores);
        cutoff       = max(1, round(numel(order) * keepFraction));
        idx          = idx(order(1:cutoff), :);
        M   = numel(idx);
        fprintf('Pair %2d→%2d: Matches = %3d\n', j, i, M);

        cnt = 0; inl = false(M,1);
        Tji = projective2d(eye(3));
        if M >= 4
            try
                [Ttmp,inR] = estimateGeometricTransform2D(ptsAll{j}(idx(:,1)), ptsAll{i}(idx(:,2)), 'projective', ...
                    'MaxNumTrials',2000,'Confidence',99,'MaxDistance',3);
                rawIn = sum(inR);
                A   = Ttmp.T(1:2,1:2);
                cnd = cond(A);
                dtr = det(A);
                condRaw(j,i)=cnd; condRaw(i,j)=cnd;
                detRaw(j,i)=dtr; detRaw(i,j)=dtr;
                fprintf('  cond=%.2f, det=%.2f, inliers=%3d\n', cnd, dtr, rawIn);

                if cnd>=1 && cnd<=maxCondAllowed && abs(dtr-1)<=maxDetDeviation
                    cnt = rawIn;
                    inl = inR;
                    Tji = Ttmp;
                    fprintf('  → Accept %d→%d \n', j, i);
                else
                    fprintf('  → Reject %d→%d (außerhalb Kond/Det)\n', j, i);
                end
            catch ME
                fprintf('  → RANSAC failed %d→%d: %s\n', j, i, ME.message);
            end
        else
            fprintf('  → Skip %d→%d (weniger als 8 Matches)\n', j, i);
        end

        W(j,i)       = cnt;
        W(i,j)       = cnt;
        idxAll{j,i}  = idx(inl,:);
        idxAll{i,j}  = fliplr(idx(inl,:));
        Tdir{j,i}    = Tji;
        try
            Tdir{i,j} = projective2d(inv(Tji.T));
        catch
            Tdir{i,j} = projective2d(eye(3));
        end
    end
end
inlierCounts = W;

%% 3) Komponenten erkennen
groups = conncomp(graph(W>0));
numComponents = max(groups);

%% 4) MST + Verkettung pro Komponente
tforms        = repmat(projective2d(eye(3)),1,N);
referenceIdxs = zeros(1,N);
edgeWeights   = zeros(1,N);
idxPairsBest  = cell(1,N);
usedCond      = nan(1,N);
usedDet       = nan(1,N);

for g = 1:numComponents
    nodes = find(groups==g);
    subW  = W(nodes,nodes);
    Tspan = minspantree(graph(subW));

    Aspan = adjacency(Tspan);
    deg   = sum(Aspan,2);
    leaves= find(deg==1);

    % Root-Wahl (wie zuvor)
    if isnumeric(rootMode) && any(nodes==rootMode)
        root = rootMode;
    elseif strcmp(rootMode,'leaf') && ~isempty(leaves)
        root = nodes(leaves(1));
    elseif strcmp(rootMode,'center')
        dist = distances(Tspan);
        ecc  = max(dist,[],2);
        [~,ci] = min(ecc);
        root  = nodes(ci);
    elseif strcmp(rootMode,'max')
        [~,r] = max(sum(subW,2));
        root = nodes(r);
    else
        root = nodes(1);
    end

    referenceIdxs(root)=root;
    edgeWeights(root)=0;
    idxPairsBest{root}=[];
    tforms(root)=projective2d(eye(3));
    usedCond(root)=cond(tforms(root).T(1:2,1:2));
    usedDet(root)=det(tforms(root).T(1:2,1:2));

    queue = root;
    while ~isempty(queue)
        u = queue(1); queue(1)=[];
        uLoc = find(nodes==u);
        for vLoc = neighbors(Tspan,uLoc)'
            v = nodes(vLoc);
            if referenceIdxs(v)==0
                referenceIdxs(v)=u;
                edgeWeights(v)=W(v,u);
                idxPairsBest{v}=idxAll{v,u};
                tforms(v)=projective2d(Tdir{v,u}.T*tforms(u).T);
                usedCond(v)=cond(tforms(v).T(1:2,1:2));
                usedDet(v)=det(tforms(v).T(1:2,1:2));
                queue(end+1)=v;
            end
        end
    end
end

%% 5) Finaler Report
fprintf('\n=== Final component assignments ===\n');
fprintf(' Img | Comp | Parent | Inliers |  cond  |  det\n');
for j=1:N
    fprintf(' %3d | %2d | %3d | %4d    | %6.2f | %6.2f\n', ...
        j, groups(j), referenceIdxs(j), inlierCounts(j,j), usedCond(j), usedDet(j));
end
fprintf('\n=== Connected components (all) ===\n');
for g=1:numComponents
    fprintf(' Component %d: %s\n', g, mat2str(find(groups==g)));
end

%% Optional: Größte Komponente extrahieren (unverändert)
grpSizes = histcounts(groups,1:(numComponents+1));
[~,bigIdx] = max(grpSizes);
bigNodes = find(groups==bigIdx);
images = images(bigNodes);
tforms = tforms(bigNodes);
edgeWeights = edgeWeights(bigNodes);
idxPairsBest = idxPairsBest(bigNodes);
refOld = referenceIdxs(bigNodes);
refNew = arrayfun(@(x)find(bigNodes==x,1), refOld);
referenceIdxs = refNew;
end