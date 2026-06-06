function [sortedImages, origIdx] = sortImagesByTimestamp(images)
% SORTIMAGESBYTIMESTAMP  Sortiert Images nach Datum im Dateinamen
%   [sortedImages, sortedFilenames, origIdx] = sortImagesByTimestamp(images)
%   images: Struct-Array mit Feld .filename, z.B. '2020_11.jpg' oder '11_2020.jpg'
%   sortedImages: Die sortierten Image-Structs
%   sortedFilenames: Cell-Array der sortierten Dateinamen
%   origIdx: Indizes der ursprünglichen Reihenfolge

N = numel(images);
times = NaT(1, N);

% Extrahiere Zeitpunkt aus dem Dateinamen
for k = 1:N
    nm = images(k).filename;
    [base, ~] = strtok(nm, '.');
    parts = split(base, {'_', ' '});
    a = str2double(parts{1});
    b = str2double(parts{2});
    if a > 31  % YYYY_MM
        Y = a; M = b;
    else       % MM_YYYY
        M = a; Y = b;
    end
    times(k) = datetime(Y, M, 1);
end

% Sortierung
[~, order] = sort(times);
sortedImages = images(order);
% Erzeuge sortierte Dateinamen
% Originalindizes
origIdx = order;
end