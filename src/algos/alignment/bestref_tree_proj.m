function [tforms, referenceIdxs, edgeWeights, idxPairsBest, inlierCounts, groups, images] = bestref_tree_proj(images, rootMode)
% BESTREF_TREE_PROJ  Verkettete projektive Transforms & Referenzbaum pro Komponente
% [tforms, referenceIdxs, edgeWeights, idxPairsBest, inlierCounts, groups] = ...
%    bestref_tree_proj(images, rootMode, fallbackIters)
% images        : struct array mit Feld .gray
% rootMode      : 'max' (Default) oder Index für Root in jeder Komponente
% fallbackIters : (wird hier nicht mehr genutzt)
if nargin<2, rootMode     = 'center';      end
N = numel(images);





% Filter-Parameter
maxCondAllowed  = 1.6;
maxDetDeviation = 1.5;
Google_width = 200;
Google_height = 100;
scale_width = 400;
scale_height = 50;
im = images(1).gray;
[height, width] = size(im);
excludedRegions = [
    1,                          height-Google_height,   Google_width,  Google_height;
    width - scale_width,        height- scale_height,   width,      scale_height;
    ];


for k = 1:N
    I = images(k).gray;

    % 1) alle SURF-Punkte detektieren
    p = detectSURFFeatures(I,'MetricThreshold',2000);

    % 2) alle Punkte in den ausgeschlossenen Regionen rausfiltern
    loc  = p.Location;
    keep = true(size(loc,1),1);
    for r = 1:size(excludedRegions,1)
        reg   = excludedRegions(r,:);
        inReg = loc(:,1) >= reg(1) & loc(:,1) <= reg(1)+reg(3) & ...
            loc(:,2) >= reg(2) & loc(:,2) <= reg(2)+reg(4);
        keep(inReg) = false;
    end
    p = p(keep);

    % 2.5) nur die stärksten bestX Punkte behalten

    % 3) nur auf die übriggebliebenen Punkte die Deskriptoren extrahieren
    [f,v] = extractFeatures(I,p);

    feats{k} = f;
    pts{k}   = v;
end

%% 2) Paarweise Matches & direkte Transforms
W       = zeros(N);
idxAll  = cell(N,N);
Tdir    = cell(N,N);
condRaw = nan(N,N);
detRaw  = nan(N,N);
for j = 1:N
    for i = j+1:N
        % 1) Sehr strenger Matching-Aufruf mit Exhaustive + Unique
        [idx, ~] = matchFeatures( ...
            feats{j}, feats{i}, ...
            'Method',            'Approximate', ...    % exhaustive search
            'Unique',            true,               ... % keine mehrfachen Zuordnungen
            'MaxRatio',          0.55,               ... % stricter Lowe‐Ratio‐Test
            'MatchThreshold',    5);                    % nur sehr ähnliche Deskriptoren

        M = size(idx,1);
        fprintf('Pair %2d→%2d: Matches = %3d\n', j, i, M);


        cnt = 0;
        inl = false(M,1);
        Tji = projective2d(eye(3));
        if M >= 4
            try
                [Ttmp,inR] = estimateGeometricTransform2D(...
                    pts{j}(idx(:,1)), pts{i}(idx(:,2)), 'projective', ...
                    'MaxNumTrials',10000,'Confidence',95,'MaxDistance',5);
                rawIn = sum(inR);
                A   = Ttmp.T(1:2,1:2);
                cnd = cond(A);
                dtr = det(A);
                condRaw(j,i) = cnd; condRaw(i,j)=cnd;
                detRaw(j,i)  = dtr; detRaw(i,j)=dtr;

                fprintf('  cond=%.2f, det=%.2f, inliers=%3d\n', cnd, dtr, rawIn);

                if cnd>=1 && cnd<=maxCondAllowed && abs(dtr-1)<=maxDetDeviation
                    cnt = rawIn;
                    inl = inR;
                    Tji = Ttmp;
                else
                    fprintf('  → Reject %d→%d (außerhalb Kond/Det)\n', j, i);
                end
            catch ME
                fprintf('  → RANSAC failed %d→%d: %s\n', j, i, ME.message);
            end
        else
            fprintf('  → Skip %d→%d (weniger als 6 Matches)\n', j, i);
        end

        W(j,i)=cnt;   W(i,j)=cnt;
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

%% Ausgabe der Matrizen
fprintf('\n--- Pairwise Inlier-Counts (rows: j, cols: i) ---\n');
disp(inlierCounts);
fprintf('--- Pairwise Condition Numbers (condRaw) ---\n');
disp(condRaw);
fprintf('--- Pairwise Determinants (detRaw) ---\n');
disp(detRaw);

%% 3) Komponenten erkennen (ohne Fallback)
groups = conncomp(graph(W>0));
numComponents = max(groups);

%% 4) MST + Verkettung pro Komponente
tforms        = repmat(projective2d(eye(3)),1,N);
referenceIdxs = zeros(1,N);
edgeWeights   = zeros(1,N);
idxPairsBest  = cell(1,N);
usedCond      = nan(1,N);
usedDet       = nan(1,N);

for g=1:numComponents
    nodes = find(groups==g);
    subW  = W(nodes,nodes);
    Tspan = minspantree(graph(subW));

    % Root-Auswahl
    Aspan  = adjacency(Tspan);
    deg    = sum(Aspan,2);
    leaves = find(deg==1);
    if isnumeric(rootMode) && any(nodes==rootMode)
        root = rootMode;
    elseif strcmp(rootMode,'leaf') && ~isempty(leaves)
        root = nodes(leaves(1));
    elseif strcmp(rootMode,'center')
        dist = distances(Tspan);
        ecc  = max(dist,[],2);
        [~,ci] = min(ecc);
        root = nodes(ci);
    elseif strcmp(rootMode,'max')
        [~,r] = max(sum(subW,2));
        root = nodes(r);
    else
        root = nodes(leaves(1));
    end

    % Initialisiere Root
    referenceIdxs(root) = root;
    edgeWeights(root)   = 0;
    idxPairsBest{root}  = [];
    tforms(root)        = projective2d(eye(3));
    usedCond(root)      = cond(tforms(root).T(1:2,1:2));
    usedDet(root)       = det(tforms(root).T(1:2,1:2));

    % Baum-Traversal
    queue = root;
    while ~isempty(queue)
        u = queue(1); queue(1) = [];
        uIdx = find(nodes==u);
        for vLoc = neighbors(Tspan,uIdx)'
            v = nodes(vLoc);
            if referenceIdxs(v)==0
                referenceIdxs(v) = u;
                edgeWeights(v)   = W(v,u);
                idxPairsBest{v}  = idxAll{v,u};
                tforms(v)        = projective2d(Tdir{v,u}.T * tforms(u).T);
                usedCond(v)      = cond(tforms(v).T(1:2,1:2));
                usedDet(v)       = det(tforms(v).T(1:2,1:2));
                queue(end+1)     = v;
            end
        end
    end
end

%% 5) Finaler Report
fprintf('\n=== Final component assignments ===\n');
fprintf(' Img | Comp | Parent | Inliers |  cond  |  det\n');
for j=1:N
    fprintf(' %3d | %2d | %3d | %4d    | %6.2f | %6.2f\n', ...
        j, groups(j), referenceIdxs(j), edgeWeights(j), usedCond(j), usedDet(j));
end
fprintf('\n===Connected components (all) ===\n');


for g=1:numComponents
    fprintf(' Component %d: %s\n', g, mat2str(find(groups==g)));
end

%% 6) (Optional) Nur größte Komponente zurückgeben
grpSizes = histcounts(groups, 1:(numComponents+1));
[~,big] = max(grpSizes);
bigNodes = find(groups==big);
fprintf('\n=== LARGEST COMPONENT ONLY (Component %d with %d images) ===\n', big, numel(bigNodes));
fprintf('Images in largest component: %s\n', mat2str(bigNodes));

images        = images(bigNodes);
tforms        = tforms(bigNodes);
referenceIdxs = referenceIdxs(bigNodes);
edgeWeights   = edgeWeights(bigNodes);
idxPairsBest  = idxPairsBest(bigNodes);
end