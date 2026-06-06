% test_analyzeChange.m – Für interaktiven Aufruf

disp('📂 Wähle mindestens 2 Bilder aus...');
[fileNames, folderPath] = uigetfile({'*.jpg;*.png;*.jpeg','Bilddateien (*.jpg, *.png)'}, ...
    'Wähle mindestens 2 Bilder', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    disp('❌ Keine Bilder ausgewählt. Abbruch.');
    return;
end

if ischar(fileNames)
    fileNames = {fileNames};
end

if numel(fileNames) < 2
    disp('❌ Bitte mindestens 2 Bilder auswählen!');
    return;
end

imageFiles = fullfile(folderPath, fileNames);

% Zeit extrahieren
timeStamps = NaT(size(imageFiles));
for i = 1:numel(imageFiles)
    [~, name, ~] = fileparts(imageFiles{i});
    
    % Extract year and month using regular expression
    tokens = regexp(name, '(\d{4})[_-](\d{1,2})', 'tokens', 'once');
    
    if isempty(tokens)
        warning('❗️Filename "%s" does not match yyyy_mm format. Skipping.', name);
        continue;
    end

    year = str2double(tokens{1});
    month = str2double(tokens{2});
    
    try
        timeStamps(i) = datetime(year, month, 1);
    catch
        warning('❌ Invalid date from filename: %s', name);
    end
end


[timeStamps, sortIdx] = sort(timeStamps);
imageFiles = imageFiles(sortIdx);

regionMask = [];           % ganze Bilder
strengthThresh = 0.1;
areaThresh = 0.001;

% ✅ Hauptfunktion aufrufen
analyzeChangeOverTime(imageFiles, timeStamps, regionMask, strengthThresh, areaThresh);

