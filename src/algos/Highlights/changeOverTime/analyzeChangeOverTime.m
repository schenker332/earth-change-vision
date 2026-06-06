function analyzeChangeOverTime(imageFiles, timeStamps, varargin)
% analyzeChangeOverTime - Compute and visualize change rates between image pairs
%
% USAGE:
%   analyzeChangeOverTime(imageFiles, timeStamps)
%   analyzeChangeOverTime(..., regionMask)
%   analyzeChangeOverTime(..., regionMask, strengthThresh, areaThresh)
%
% INPUTS:
%   imageFiles     - cell array of image file paths (at least two entries)
%   timeStamps     - datetime array matching imageFiles, e.g. [datetime(1984,12,1), datetime(1991,12,1), ...]
%   regionMask     - (optional) logical mask to restrict change analysis (applied after resizing)
%   strengthThresh - (optional) strength threshold for computeChangeMask (default 0)
%   areaThresh     - (optional) area threshold for computeChangeMask (default 0)
%
% NOTE:
%   All images are resized to [512, 512] to ensure consistent comparison across resolutions.

% Parse inputs
nImgs = numel(imageFiles);
if nImgs < 2
    error('At least two images are required.');
end
if numel(timeStamps) ~= nImgs
    error('imageFiles and timeStamps must have the same length.');
end
if nargin < 3, regionMask = []; else regionMask = varargin{1}; end
if nargin < 4, strengthThresh = 0; else strengthThresh = varargin{2}; end
if nargin < 5, areaThresh = 0; else areaThresh = varargin{3}; end

% Resize target size
resizeTo = [512, 512];

% Preallocate metrics
nPairs = nImgs - 1;
changeRates = zeros(nPairs,1);
entropyRates = zeros(nPairs,1);
timeLabels = strings(nPairs,1);
changeMasks = cell(nPairs,1);

for i = 1:nPairs
    % Read and resize images
    img1 = imresize(imread(imageFiles{i}), resizeTo);
    img2 = imresize(imread(imageFiles{i+1}), resizeTo);

    % Compute elapsed time in years
    deltaDays = days(timeStamps(i+1) - timeStamps(i));
    yearsElapsed = deltaDays / 365;
    timeLabels(i) = sprintf('%s–%s', datestr(timeStamps(i), 'yyyy-mm-dd'), datestr(timeStamps(i+1), 'yyyy-mm-dd'));

    % Resize regionMask if provided
    currentRegionMask = regionMask;
    if ~isempty(currentRegionMask)
        currentRegionMask = imresize(currentRegionMask, resizeTo, 'nearest');
    end

    % Compute change mask
    cm = computeChangeMask(img1, img2, currentRegionMask, strengthThresh, areaThresh);
    changeMasks{i} = cm;
    fracChange = sum(cm(:)) / numel(cm);

    % Compute entropy change
    eDiff = computeEntropyDifference(img1, img2, currentRegionMask);
    meanEntropy = mean(eDiff(:));

    % Compute rates
    changeRates(i) = fracChange / yearsElapsed;
    entropyRates(i) = meanEntropy / yearsElapsed;
end

% Sort by change rate
[sortedRates, idxRate] = sort(changeRates, 'ascend');
sortedTimes = timeLabels(idxRate);
sortedEntRates = entropyRates(idxRate);

% Plot bar chart of change rates
figure;
bar(sortedRates);
set(gca, 'XTick', 1:nPairs, 'XTickLabel', sortedTimes, 'XTickLabelRotation', 45);
xlabel('Image Pair');
ylabel('Change Fraction per Year');
title('Change Rate (slowest to fastest)');

% Highlight slowest and fastest
slowIdx = idxRate(1);
fastIdx = idxRate(end);

% Show overlay for slowest change
figure;
img1name = datestr(timeStamps(slowIdx), 'yyyy-mm');
img2name = datestr(timeStamps(slowIdx + 1), 'yyyy-mm');
overlaySlow = computeOverlayMap( ...
    imresize(imread(imageFiles{slowIdx}), resizeTo), ...
    imresize(imread(imageFiles{slowIdx+1}), resizeTo), 0.4, changeMasks{slowIdx});
imshow(overlaySlow);
titleStr = sprintf(['Slowest Change: %s → %s\n' ...
    'Background = %s, Red = Change from %s'], ...
    img1name, img2name, img1name, img2name);
title(titleStr, 'FontSize', 12);

% Show overlay for fastest change
figure;
img1name = datestr(timeStamps(fastIdx), 'yyyy-mm');
img2name = datestr(timeStamps(fastIdx + 1), 'yyyy-mm');
overlayFast = computeOverlayMap( ...
    imresize(imread(imageFiles{fastIdx}), resizeTo), ...
    imresize(imread(imageFiles{fastIdx+1}), resizeTo), 0.4, changeMasks{fastIdx});
imshow(overlayFast);
titleStr = sprintf(['Fastest Change: %s → %s\n' ...
    'Background = %s, Red = Change from %s'], ...
    img1name, img2name, img1name, img2name);
title(titleStr, 'FontSize', 12);

end
