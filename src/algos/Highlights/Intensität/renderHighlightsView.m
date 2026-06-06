function renderHighlightsView(ax, img1, img2, mode, ...
    strengthThresh, areaThresh, colorMode, alpha)
% alpha – Overlay-Transparenz [0…1] (nur Edge); default 0.4

if nargin<8 || isempty(alpha), alpha = 0.4; end

%
% Inputs:
%   ax             - Handle auf eine uiaxes
%   img1, img2     - RGB-Bilder zweier Zeitpunkte
%   mode           - 'transparent', 'color' oder 'rededge'
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

% --- Default-Parameter ---
if nargin<5 || isempty(strengthThresh), strengthThresh = 0.5; end
if nargin<6 || isempty(areaThresh),     areaThresh     = 0.0001; end
if nargin<7 || isempty(colorMode),      colorMode      = 'all'; end



% --- Änderungsmaske berechnen ---
changeMask = computeChangeMask(img1, img2, [], strengthThresh, areaThresh);
% --- Overlay erstellen ---
switch lower(mode)
    case 'umrandung'
        overlay = computeOverlayMap(img1, img2, alpha, changeMask);

    case 'intensität'
        fullColor = computeOverlayMapColour(img1, img2, colorMode);
        mask3     = repmat(changeMask, [1 1 3]);
        overlay   = fullColor;
        overlay(~mask3) = 0.5 * overlay(~mask3);
end

% --- In die UIAxes zeichnen ---
cla(ax, 'reset');
imshow(overlay, 'Parent', ax, 'InitialMagnification', 'fit');
axis(ax, 'off');
end
