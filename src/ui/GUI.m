%==========================================================================
% GUI – Satellite Change Visualization Application
%==========================================================================
%
% Beschreibung:
%   Diese Klasse implementiert die grafische Benutzeroberfläche zur
%   Visualisierung von Satellitenbild-Serien und Veränderungen über die Zeit.
%   Features:
%     • Auswahl und Ausrichtung (Alignment) von Locations
%     • Ansichten: Zeitraffer, Veränderungs-Highlights, Fortschritts-Plot,
%       Segmentierung
%     • ROI-Auswahl und automatischer Zuschnitt (Crop)
%
%==========================================================================
classdef GUI < matlab.apps.AppBase
    % GUI - Satellite Change Visualization Application

    %% -------------------- UI-Komponenten --------------------
    % Definiert alle grafischen Elemente und Layouts der Benutzeroberfläche
    properties (Access = public)
        UIFigure                matlab.ui.Figure

        LeftPanel               matlab.ui.container.Panel
        LocationLabel           matlab.ui.control.Label
        LocationList            matlab.ui.control.ListBox
        LocationScroll          matlab.ui.container.Panel      %  ⇐ NEU
        LocationGrid            matlab.ui.container.GridLayout %  ⇐ NEU
        AddLocationBtn          matlab.ui.control.Button       %  ⇐ NEU

        ViewSelectionGroup      matlab.ui.container.ButtonGroup
        TimelapseButton         matlab.ui.control.ToggleButton
        ProgressButton          matlab.ui.control.ToggleButton
        HighlightsButton        matlab.ui.control.ToggleButton
        SegmentationButton      matlab.ui.control.ToggleButton




        ROIButton               matlab.ui.control.Button
        CropToggleButton        matlab.ui.control.StateButton % ToggleButton für Crop-Ansicht



        % --- Bildauswahl-Panel rechts ---
        ImageSelectionPanel      matlab.ui.container.Panel
        ImageSelectionScroll     matlab.ui.container.Panel
        AlignedGrid              matlab.ui.container.GridLayout
        NotAlignedGrid           matlab.ui.container.GridLayout
        AlignedMask  logical = [];      % true == fürs Alignment verwendet
        SelectedMask logical = [];      % aktuell vom Nutzer angewählt
        ShowRawThumbs logical = true;   % true → untransformierte Bilder


        LocationsPath = fullfile('resources', 'locations');
        AlignedPath = fullfile('resources', 'aligned_locations');
        CurrentLocation = '';


        tforms = [];  % Transformationen für die Bilder der aktuellen Location
        ChoosenLocation

        % View-Objekte
        TimelapseViewObj
        HighlightsViewObj
        ProgressViewObj
        SegmentationViewObj

    end

    %% -------------------- Shared Daten (für Views) ----------------------
    % Gemeinsame Zustandsvariablen für Bilddaten, Indizes und Crop-Logik
    properties (Access = public)
        CurrentLocationImages = {};
        CurrentLocationDates = {};
        CurrentImageIndex = 1;
        ShowCrop         logical = false    % aktueller Toggle-Status
        CroppedImages    cell    = {}       % Cache der zugeschnittenen Bilder
        CropBBox         double  = []       % Bounding-Box [x y w h] der letzten Ermittlung

    end

    %% -------------------- Methoden (private) ------------------
    % Interne Hilfsfunktionen zum Laden, Ausrichten und Aktualisieren der Daten

    methods (Access = private)

        function showStartupDialog(app)
            % Öffnet modalen Dialog zur Auswahl oder Hinzufügen einer Location

            dlg = uifigure( ...
                'Name',        'Wähle Location', ...
                'Theme',       'dark', ...
                'Color',       [1 1 1], ...
                'WindowState', 'maximized', ...
                'WindowStyle', 'modal', ...
                'Scrollable',  'on' ...
                );

            % Finde echte Location-Ordner mit JPGs
            raw  = dir(app.LocationsPath);
            dirs = raw([raw.isdir] & ~ismember({raw.name},{'.','..'}));
            keep = arrayfun(@(d) ~isempty(dir(fullfile(app.LocationsPath,d.name,'*.jpg'))), dirs);
            locs = dirs(keep);
            n    = numel(locs);

            maxRows   = 3;
            thumbCols = ceil(n/maxRows);
            totalCols = thumbCols + 1;
            g = uigridlayout(dlg, [maxRows, totalCols]);
            g.RowHeight   = repmat({'1x'},1,maxRows);
            g.ColumnWidth = [repmat({'1x'},1,thumbCols), {'fit'}];

            % Thumbnails + Buttons
            idx = 1;
            for col = 1:thumbCols
                for row = 1:maxRows
                    if idx > n, break; end

                    pnl = uipanel(g);
                    pnl.Layout.Row    = row;
                    pnl.Layout.Column = col;
                    ig = uigridlayout(pnl, [2,1]);
                    ig.RowHeight = {'1x', 30};
                    ig.Padding   = [5 5 5 5];

                    % Vorschaubild
                    ax = uiaxes(ig);
                    ax.Layout.Row = 1;
                    ax.XTick = []; ax.YTick = []; ax.Box = 'off';
                    folder = fullfile(app.LocationsPath, locs(idx).name);
                    imgs   = dir(fullfile(folder,'*.jpg'));
                    [~, li] = max([imgs.datenum]);
                    im = imread(fullfile(folder, imgs(li).name));
                    imshow(im, 'Parent', ax, 'InitialMagnification','fit');

                    % Auswahl-Button
                    name = locs(idx).name;
                    btn  = uibutton(ig, 'Text', name);
                    btn.Layout.Row = 2;
                    btn.ButtonPushedFcn = @(~,~) app.onStartupLocationSelected(name, dlg);

                    idx = idx + 1;
                end
            end

            % ➕-Button zum Hinzufügen
            addBtn = uibutton(g, 'Text','➕ Location hinzufügen', 'FontWeight','bold');
            addBtn.Layout.Row    = [1, maxRows];
            addBtn.Layout.Column = totalCols;
            addBtn.ButtonPushedFcn = @(~,~) app.onStartupLocationSelected('', dlg);
        end

        function onStartupLocationSelected(app, name, dlg)
            % Lädt ausgewählte Location, führt Alignment durch und initialisiert Views
            app.CropToggleButton.Value = false;   % setzt den Toggle-Button zurück
            app.ShowCrop = false;                 % interne Flag ebenfalls zurücksetzen
            app.CroppedImages = {};               % Cache leeren
            app.CropBBox = [];                    % Bounding-Box zurücksetzen
            % Pfad ermitteln
            if isempty(name)
                fp = uigetdir(pwd, 'Select Location Folder');
                if fp==0, return; end

                % ► Ordner­name ermitteln
                [~, locName] = fileparts(fp);

                % ► Bilder in unser Projekt kopieren (resources\locations\<locName>)
                destDir = fullfile(app.LocationsPath, locName);
                if ~exist(destDir,'dir')
                    mkdir(destDir);
                    % nur JPG/JPEG kopieren
                    srcFiles = dir(fullfile(fp, '*.jp*g'));
                    if isempty(srcFiles)
                        uialert(app.UIFigure, ...
                            'Der gewählte Ordner enthält keine JPG-Dateien.', ...
                            'Keine Bilder gefunden');
                        return;
                    end
                    for k = 1:numel(srcFiles)
                        copyfile(fullfile(srcFiles(k).folder, srcFiles(k).name), destDir);
                    end
                end

                fp = destDir;   % ab hier immer Pfad innerhalb der Projektstruktur
            else
                locName = name;
                fp = fullfile(app.LocationsPath, name);
            end


            alignedDir = fullfile(app.AlignedPath, locName);
            if ~isempty(locName) && exist(alignedDir,'dir')
                app.UIFigure.Visible = 'on';
                figure(app.UIFigure);
                note = uiprogressdlg(app.UIFigure, ...
                    'Title', 'Transformation läuft', ...
                    'Message', 'Bitte warten, Transformation wird durchgeführt ...', ...
                    'Indeterminate', 'on');
                drawnow;
                % --- schon aligned ---
                S = load(fullfile(alignedDir,'metadata.mat'));  % oder jsondecode
                rgbImages     = S.rgbImages;
                dates         = S.dates;
                if isfield(S,'alignedMask')
                    app.AlignedMask = S.alignedMask;
                    app.SelectedMask = app.AlignedMask;   % standardmäßig alle gültigen Bilder wählen
                    app.tforms = S.tforms;  % Transformationen für die Bilder der aktuellen Location
                else
                    % ► Altbestand: wir nehmen an, dass alle Bilder gültig sind
                    app.AlignedMask = true(1, numel(rgbImages));

                    % und schreiben die Maske gleich nach, damit es beim nächsten Start passt
                    save(fullfile(alignedDir,'metadata.mat'), 'alignedMask', '-append');
                    app.SelectedMask = app.AlignedMask;   % standardmäßig alle gültigen Bilder wählen

                end



            else

                app.UIFigure.Visible = 'on';
                figure(app.UIFigure);
                % --- erstmal alignen und abspeichern ---
                note = uiprogressdlg(app.UIFigure, ...
                    'Title', 'Transformation läuft', ...
                    'Message', 'Bitte warten, Transformation wird durchgeführt ...', ...
                    'Indeterminate', 'on');
                drawnow;
                [rgbImages, dates, alignedMask, tforms] = runOverlapWorkflow(fp);
                app.AlignedMask   = alignedMask;
                app.tforms = tforms;  % Transformationen für die Bilder der aktuellen Location
                app.SelectedMask = app.AlignedMask;   % standardmäßig alle gültigen Bilder wählen
                if ~exist(alignedDir,'dir'), mkdir(alignedDir); end
                save(fullfile(alignedDir,'metadata.mat'), ...
                    'rgbImages','dates','alignedMask', 'tforms');

            end

            close(note);


            % App-Daten befüllen
            app.CurrentLocationImages = rgbImages;
            app.CurrentLocationDates  = dates;
            app.ChoosenLocation = locName;




            app.ViewSelectionGroup.SelectedObject = app.TimelapseButton;
            app.onViewSelectionChanged();

            if isempty(dlg) % Aufruf kam aus Linker Tile-Liste
                % nichts schließen
            else
                close(dlg);
            end
            app.refreshImageSelectionPanel();

            refreshLocationTiles(app);  % Liste neu einfärben

        end

        function openGUIDirect(app, locationName)
            % GUI direkt öffnen und bestimmte Location laden
            app.UIFigure.Visible = 'on';
            figure(app.UIFigure);

            % Location laden wie im Startup-Dialog
            dlg = [];
            app.onStartupLocationSelected(locationName, dlg);

            % Panels und Tiles aktualisieren
            app.ViewSelectionGroup.SelectedObject = app.TimelapseButton;
            app.onViewSelectionChanged();
            refreshLocationTiles(app);
        end

        function onViewSelectionChanged(app)
            % Wechselt zwischen den vier Haupt-Ansichten und aktualisiert UI
           
            % Falls gerade Timelapse läuft, stoppen und Status in der View zurücksetzen
            app.TimelapseViewObj.stopTimelapse();


            sel = app.ViewSelectionGroup.SelectedObject;
            dlg = uiprogressdlg(app.UIFigure, ...
                'Title', 'Berechnung läuft', ...
                'Message', 'Bitte warten, Ansichtsänderung ...', ...
                'Indeterminate', 'on');
            % alles ausblenden
            app.TimelapseViewObj.TimelapsePanel.Visible  = 'off';
            app.HighlightsViewObj.HighlightsPanel.Visible = 'off';
            app.ProgressViewObj.ProgressPanel.Visible = 'off';
            app.SegmentationViewObj.SegmentationPanel.Visible = 'off';
            app.ROIButton.Visible = 'on';
            app.CropToggleButton.Visible = 'on';


            % ---------- TIMELAPSE ----------
            if sel == app.TimelapseButton
                app.TimelapseViewObj.TimelapsePanel.Visible = 'on';
                app.TimelapseViewObj.initializeTimelapseSlider();
                app.TimelapseViewObj.toggleTimelapse(app.TimelapseViewObj.PlayButton);


                % ---------- HIGHLIGHTS ----------
                % ---------- HIGHLIGHTS ----------
            elseif sel == app.HighlightsButton
                % --- NEU: automatisch jüngstes & ältestes Bild wählen ---------------
                app.autoSelectOldestNewest();      % siehe Methode oben
                app.refreshImageSelectionPanel();  % Checkboxes sofort aktualisieren
                % --------------------------------------------------------------------

                app.HighlightsViewObj.HighlightsPanel.Visible = 'on';
                app.HighlightsViewObj.initializeHighlightsView();


                % ---------- Progress ----------
            elseif  sel == app.ProgressButton
                app.SelectedMask = app.AlignedMask;
                app.refreshImageSelectionPanel();
                app.ProgressViewObj.ProgressPanel.Visible = 'on';
                app.ProgressViewObj.initializeProgressView();
                disp('⏳ Progress View ausgewählt');



                % --- Segmentation ---
            elseif sel == app.SegmentationButton
                app.ROIButton.Visible = 'off';
                app.CropToggleButton.Visible = 'off';
                app.autoSelectOldestNewest();      % siehe Methode oben
                app.refreshImageSelectionPanel();  % Checkboxes sofort aktualisieren
                app.SegmentationViewObj.SegmentationPanel.Visible = 'on';
                disp('🖼️ Segmentation View ausgewählt');
                app.SegmentationViewObj.initializeSegmentationView();
            end
            close(dlg);
        end


        function onROIButtonPushed(app)
            % Führt ROI-basierte Neuausrichtung durch und aktualisiert Anzeige

            app.TimelapseViewObj.stopTimelapse();  % Timelapse stoppen, falls aktiv
            disp('🕒 ROI View ausgewählt');
            dlg = uiprogressdlg(app.UIFigure, ...
                'Title', 'Transformation läuft', ...
                'Message', 'Bitte warten, Transformation wird durchgeführt ...', ...
                'Indeterminate', 'on');
            [rgbImages, dates, alignedMask, tforms] = runRealignWithRoi(app.CurrentLocationImages, app.CurrentLocationDates, app.AlignedMask);
            close(dlg);
            app.CurrentLocationImages = rgbImages;
            app.CurrentLocationDates  = dates;
            app.tforms = tforms;
            app.AlignedMask   = alignedMask;
            app.SelectedMask = app.AlignedMask;   % standardmäßig alle gültigen Bilder wählen
            app.ViewSelectionGroup.SelectedObject = app.TimelapseButton;
            app.onViewSelectionChanged();
            app.refreshImageSelectionPanel();
            alignedDir = fullfile(app.AlignedPath, app.ChoosenLocation);
            if ~exist(alignedDir,'dir'), mkdir(alignedDir); end
            save(fullfile(alignedDir,'metadata.mat'), ...
                'rgbImages','dates','alignedMask', 'tforms');


        end

        function refreshLocationTiles(app)
            % Erzeugt Tiles für alle alignierten Locations in der linken Leiste

            delete(app.LocationGrid.Children);     % alles leeren

            % ---- Ordner einlesen ------------------------------------------------
            dirs = dir(app.AlignedPath);
            dirs = dirs([dirs.isdir] & ~ismember({dirs.name},{'.','..'}));
            n    = numel(dirs);

            if n==0        % nichts gefunden
                app.LocationGrid.RowHeight = {100};
                return
            end

            % ---- für jede Location ein Tile erstellen ---------------------------
            for k = 1:n
                locName = dirs(k).name;

                tile = uipanel(app.LocationGrid,...
                    'BorderType','line',...
                    'BorderWidth',1,...);
                    'BorderColor',[0.65 0.65 0.8],...
                    'BackgroundColor',[0.94 0.94 1]);
                tile.Layout.Row = k;

                if strcmp(app.ChoosenLocation,locName)          % aktive Location
                    tile.BorderColor     = [0.25 0.45 1];
                    tile.BackgroundColor = [0.80 0.88 1];
                end

                g = uigridlayout(tile,[2 2], ...        % <--- NEU: 2 Zeilen × 2 Spalten
                    'RowHeight',{60,'fit'}, ...
                    'ColumnWidth',{'1x',18}, ...    % rechte Spalte schmal (25 px)
                    'Padding',[2 2 2 2]);


                ax = uiaxes(g, ...
                    'XTick',[], 'YTick',[], 'Box','off');
                ax.Toolbar.Visible = 'off';
                ax.Layout.Row = 1;

                delBtn = uibutton(g, ...
                    'Text','✖', ...
                    'Tooltip','Alignment löschen', ...
                    'FontSize',10, ...
                    'FontWeight','bold', ...
                    'BackgroundColor',[1 0.85 0.85], ...
                    'FontColor',[0.8 0 0], ...
                    'ButtonPushedFcn',@(src,~)app.onDeleteAlignedClicked(locName));
                delBtn.Layout.Row    = 1;   % gleiche Zeile wie Thumbnail
                delBtn.Layout.Column = 2;   % rechte, schmale Spalte


                imgFile = dir(fullfile(app.LocationsPath,locName,'*.jpg'));
                [~,idx] = max([imgFile.datenum]);
                if ~isempty(imgFile)
                    im = imread(fullfile(imgFile(idx).folder,imgFile(idx).name));
                    imshow(im,'Parent',ax,'InitialMagnification','fit');
                end

                b = uibutton(g,'Text',locName,...
                    'FontSize',11,...
                    'FontWeight','bold',...
                    'HorizontalAlignment','center',...
                    'ButtonPushedFcn',@(~,~)app.onLeftTileClicked(locName));
                b.Layout.Row = 2;
                b.Layout.Column = [1 2];
            end

            % ---- Grid-Zeilenhöhe korrekt setzen --------------------------------
            app.LocationGrid.RowHeight = repmat({100},1,n);

        end

        function onDeleteAlignedClicked(app, locName)
            % Bestätigt und löscht Alignment-Daten einer Location
            % Bestätigungsdialog
            answer = uiconfirm(app.UIFigure, ...
                ['Alignment „' locName '“ wirklich löschen?'], ...
                'Löschen bestätigen', ...
                'Options',{'Ja','Abbrechen'}, ...
                'DefaultOption',2,'CancelOption',2);

            if ~strcmp(answer,'Ja');  return;  end

            alignedDir = fullfile(app.AlignedPath, locName);

            try
                if isfolder(alignedDir)
                    rmdir(alignedDir,'s');   % rekursiv löschen
                end

                % Wenn gerade geladene Location entfernt wurde -> zurücksetzen
                if strcmp(app.ChoosenLocation, locName)
                    app.ChoosenLocation      = '';
                    app.CurrentLocationDates = {};
                    app.CurrentLocationImages= {};
                end

                refreshLocationTiles(app);   % Liste neu aufbauen
            catch ME
                uialert(app.UIFigure, ...
                    ['Ordner konnte nicht gelöscht werden: ' ME.message], ...
                    'Fehler beim Löschen');
            end
        end

        % ------------------------------------------------------------
        function refreshImageSelectionPanel(app)
            % Aktualisiert die Anzeige der Bilder in der rechten Spalte
            % Grids leeren
            delete(app.AlignedGrid.Children);
            delete(app.NotAlignedGrid.Children);

            if isempty(app.CurrentLocationImages), return; end

            % Dimensionen -------------------------------------------------------
            thumbSize   = 120;      % Pixel‐Kantenlänge
            numCols     = 2;        % 2 Spalten
            numImgs     = numel(app.CurrentLocationImages);

            % Zähler für Zeilen
            rowCntAligned    = 0;
            rowCntNotAligned = 0;

            for k = 1:numImgs
                isAligned = app.AlignedMask(k);

                % ---- Zielgrid & Farbschema ------------------------------------
                if isAligned
                    parentGrid = app.AlignedGrid;
                    bg         = [0.90 1.00 0.90];
                    rowCntAligned = rowCntAligned + 1;
                    tileRow   = ceil(rowCntAligned/numCols);
                    tileCol   = mod(rowCntAligned-1,numCols)+1;
                else
                    parentGrid = app.NotAlignedGrid;
                    bg         = [1.00 0.92 0.92];
                    rowCntNotAligned = rowCntNotAligned + 1;
                    tileRow   = ceil(rowCntNotAligned/numCols);
                    tileCol   = mod(rowCntNotAligned-1,numCols)+1;
                end

                % ---- Tile -----------------------------------------------------
                tile = uipanel(parentGrid,'BackgroundColor',bg,'BorderType','line');
                tile.Layout.Row    = tileRow;
                tile.Layout.Column = tileCol;

                % Layout im Tile: Bild (oben) und ggf. Checkbox (unten)
                if isAligned
                    g = uigridlayout(tile,[2 1],'RowHeight',{thumbSize,22}, ...
                        'Padding',[2 2 2 2]);
                else
                    g = uigridlayout(tile,[1 1],'RowHeight',{thumbSize}, ...
                        'Padding',[2 2 2 2]);
                end

                % Thumbnail

                ax = uiaxes(g,'XTick',[],'YTick',[],'Box','off');
                ax.Toolbar.Visible = 'off';
                ax.Layout.Row = 1;

                if isAligned || app.ShowRawThumbs
                    % Originalbild vom Dateisystem holen
                    origFile = fullfile(app.LocationsPath, ...
                        app.ChoosenLocation, ...
                        [app.CurrentLocationDates{k} '.jpg']);
                    im = imread(origFile);
                else
                    % bereits transformiertes RGB
                    im = app.CurrentLocationImages{k};
                end
                imshow(im,'Parent',ax,'InitialMagnification','fit');
                % -----------------------------------------------


                % Checkbox nur für ✔-Bilder
                if isAligned
                    cb = uicheckbox(g, ...
                        'Text', app.CurrentLocationDates{k}, ...   %  ⇐  NEU
                        'Value', app.SelectedMask(k), ...
                        'ValueChangedFcn', @(src,~)app.onImageCheckboxChanged(k,src));
                    cb.Layout.Row = 2;
                end

            end

            % Grid-Zeilenhöhen setzen
            app.AlignedGrid.RowHeight    = repmat({thumbSize+30},1,ceil(rowCntAligned/numCols));
            app.NotAlignedGrid.RowHeight = repmat({thumbSize+10},1,ceil(rowCntNotAligned/numCols));
        end


        % ------------------------------------------------------------
        function onImageCheckboxChanged(app, idx, src)
            % Callback für Checkbox-Änderungen in der Bildauswahl
            % Maske updaten
            app.SelectedMask(idx) = src.Value;

            % Limitiere Auswahl bei Highlights-Ansicht
            if app.ViewSelectionGroup.SelectedObject == app.HighlightsButton
                if nnz(app.SelectedMask) > 2
                    src.Value = false;              % zurücksetzen
                    app.SelectedMask(idx) = false;
                    uialert(app.UIFigure, ...
                        'Für Highlights dürfen maximal 2 Bilder gewählt sein.', ...
                        'Auswahlbegrenzung');
                    return;
                end
            end

            if app.ViewSelectionGroup.SelectedObject == app.TimelapseButton
                app.TimelapseViewObj.initializeTimelapseSlider( ...
                    app.CurrentLocationImages, app.CurrentLocationDates);
                app.TimelapseViewObj.updateTimelapseDisplay( ...
                    min(app.CurrentImageIndex, nnz(app.SelectedMask)));
            end

            if app.ViewSelectionGroup.SelectedObject == app.HighlightsButton
                % 2-Bilder-Limit erzwingen
                if nnz(app.SelectedMask) > 2
                    src.Value = false;
                    app.SelectedMask(idx) = false;
                    uialert(app.UIFigure, ...
                        'Für Highlights dürfen maximal 2 Bilder gewählt sein.', ...
                        'Auswahlbegrenzung');
                    return
                end
                % jetzt sind es 1 oder 2 ⇒ View sofort refreshen
                app.HighlightsViewObj.onViewChanged();
            end

            % ─── Wenn wir gerade in der Progress View sind, dann updaten ───
            if app.ViewSelectionGroup.SelectedObject == app.ProgressButton
                app.ProgressViewObj.updateProgressPlot();
            end

            if app.ViewSelectionGroup.SelectedObject == app.SegmentationButton
                app.SegmentationViewObj.initializeSegmentationView();
            end

        end

        % ------------------------------------------------------------


        function onLeftTileClicked(app, locName)
            % Callback für Klick auf Location-Tile in der linken Leiste
            %  Startup-Logik wiederverwenden:
            dlg = [];                       % kein Dialogfenster nötig
            app.onStartupLocationSelected(locName, dlg);
            %  Scroll-Liste sofort neu einfärben
            refreshLocationTiles(app);
        end

        function onCropToggleChanged(app, src)
            % Callback für Crop-Toggle-Button
            app.ShowCrop = src.Value;

            if app.ShowCrop
                app.updateCropCache();              % Bounding-Box + Cache neu
            end

            % aktive View neu initialisieren
            imgs = app.getDisplayImages();
            if app.ViewSelectionGroup.SelectedObject == app.TimelapseButton
                app.TimelapseViewObj.initializeTimelapseSlider(imgs, app.CurrentLocationDates);
                app.TimelapseViewObj.updateTimelapseDisplay( ...
                    min(app.CurrentImageIndex, nnz(app.SelectedMask)));
            elseif app.ViewSelectionGroup.SelectedObject == app.HighlightsButton
                app.HighlightsViewObj.initializeHighlightsView();  % greift intern auf app.getDisplayImages()
            elseif app.ViewSelectionGroup.SelectedObject == app.ProgressButton
                app.ProgressViewObj.updateProgressPlot();
            end
        end

        %--------------------------------------------------------------
        function bbox = computeCommonCropBBox(app)
            % Berechnet die Bounding-Box für den gemeinsamen Crop-Bereich
            % nur die momentan ausgewählten Bilder heranziehen
            selIdx = find(app.SelectedMask);
            imgs   = app.CurrentLocationImages(selIdx);

            % robuste Überlappung der sichtbaren Pixel bestimmen
            commonMask = true(size(rgb2gray(imgs{1})));
            for k = 1:numel(imgs)
                commonMask = commonMask & rgb2gray(imgs{k}) > 0;
            end

            props = regionprops(commonMask,'BoundingBox');
            if isempty(props)
                error('Keine gemeinsame Sichtbarkeit gefunden.');
            end
            bbox = round(props(1).BoundingBox);   % [x y w h]
        end
        % ------------------------------------------------------------
        function updateCropCache(app)
            % Aktualisiert den Cache der zugeschnittenen Bilder basierend auf der
            % Bounding-Box nur dann neu berechnen, wenn Auswahl geändert
            app.CropBBox = app.computeCommonCropBBox();   % [x y w h] – Bezug: Bild 1
            bbox = app.CropBBox;
            x0 = bbox(1);  y0 = bbox(2);  w = bbox(3);  h = bbox(4);

            N = numel(app.CurrentLocationImages);
            C = cell(1, N);

            for k = 1:N
                img = app.CurrentLocationImages{k};
                [rows, cols, ~] = size(img);

                % ► auf Bildgrenzen begrenzen
                x1 = max(1, x0);
                y1 = max(1, y0);
                x2 = min(cols, x0 + w - 1);
                y2 = min(rows, y0 + h - 1);

                if x1 > x2 || y1 > y2
                    % Bounding-Box liegt außerhalb dieses Bildes – notfalls Original behalten
                    warning('BBox passt nicht zu Bild %d – Originalbild übernommen.', k);
                    C{k} = img;
                else
                    C{k} = img(y1:y2, x1:x2, :);
                end
            end

            app.CroppedImages = C;
        end

        function autoSelectOldestNewest(app)
            % Wählt unabhängig von der aktuellen Auswahl das älteste und das
            % neueste *ausgerichtete* Bild aus und setzt app.SelectedMask passend.
            %
            % Unterstützte Date-Namens­muster:
            %   •  YYYY-MM-DD oder YYYYMMDD
            %   •  MM_YYYY   (z. B. 12_2000)
            %   •  beliebige andere, solange regexp unten angepasst wird.

            if isempty(app.CurrentLocationDates);  return;  end

            % --- nur Bilder, die fürs Alignment gültig sind ---------------------
            idxCandidates = find(app.AlignedMask);

            if numel(idxCandidates) < 2
                uialert(app.UIFigure, ...
                    'Für die Highlights-Ansicht werden mindestens zwei ausgerichtete Bilder benötigt.', ...
                    'Zu wenige Bilder');
                app.ViewSelectionGroup.SelectedObject = app.TimelapseButton;
                app.onViewSelectionChanged();
                return;
            end

            % --------------------------------------------------------------------
            datesCell = app.CurrentLocationDates(idxCandidates);   % *cell* of char
            datesCell = cellstr(datesCell);                        % sicherstellen

            % Versuche erst direktes datetime-Parsen (YYYY-MM-DD usw.)
            try
                dt = datetime(datesCell, "InputFormat","yyyy-MM-dd");   % klappt nur, wenn Format passt
            catch
                dt = NaT(size(datesCell));
            end

            % Fallback: eigenes Parsen für "MM_YYYY"
            if any(isnat(dt))
                %  → Einträge, die noch NaT sind, mit regexp auswerten
                for k = 1:numel(datesCell)
                    if ~isnat(dt(k)),  continue;  end
                    tok = regexp(datesCell{k}, '^(\d{1,2})_(\d{4})$', 'tokens', 'once');
                    if ~isempty(tok)
                        mon  = str2double(tok{1});
                        year = str2double(tok{2});
                        dt(k) = datetime(year, mon, 1);   % Tag = 1
                    end
                end
            end

            % Letztes Sicherheitsnetz – alles noch NaT?
            if all(isnat(dt))
                error('Kein unterstütztes Datumsformat in CurrentLocationDates gefunden.');
            end

            % --- ältestes / neuestes herausfinden -------------------------------
            [~,iOldLocal] = min(dt);
            [~,iNewLocal] = max(dt);

            iOld = idxCandidates(iOldLocal);
            iNew = idxCandidates(iNewLocal);

            % --- Auswahl hart überschreiben -------------------------------------
            app.SelectedMask(:) = false;
            app.SelectedMask([iOld iNew]) = true;
        end

        function onClose(app, src, evt)
            % Callback für das Schließen des Hauptfensters
            % ➊ TimelapseView aufräumen
            app.TimelapseViewObj.cleanup();

            % ➋ Optional: andere Timer oder Resourcen freigeben
            % delete(timerfind('Tag','SCV_PlayTimer'));  % falls gewünscht

            % ➌ Fenster schließen
            delete(app.UIFigure);
        end
    end


    %% -------------------- Methoden (public) -------------------
    methods (Access = public)

        function app = GUI()
            % GUI-Konstruktor
            % Initialisiert die App und erstellt die Hauptkomponenten

            % addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'functions'));

            % TimelapseView-Objekt VORHER erstellen
            app.TimelapseViewObj = TimelapseView(app);
            app.HighlightsViewObj = HighlightsView(app);
            % ---- evtl. herrenlose Timer aus vorherigen Läufen entfernen ------------
            delete(timerfind('Tag','SCV_PlayTimer'));
            app.SegmentationViewObj = SegmentationView(app);
            app.ProgressViewObj = ProgressView(app);
            app.createComponents();
            app.UIFigure.Visible = 'off';
            app.UIFigure.Color   = [1 1 1];
            app.UIFigure.WindowStyle = 'normal';
            refreshLocationTiles(app);
            app.showStartupDialog();
            % app.openGUIDirect('Dubai');
            refreshLocationTiles(app);
            % in GUI-Konstruktor, ganz unten:
            app.UIFigure.CloseRequestFcn = @(src,evt)app.onClose(src,evt);

        end

        function createComponents(app)
            % Erstellt die Hauptkomponenten der GUI
            % Main Window
            app.UIFigure = uifigure( ...
                'Visible','off', ...
                'Theme',      'dark', ...
                'WindowState','maximized', ...
                'Name',       'Veränderungen aus dem All' ...
                );

            % und zuletzt sichtbar schalten
            app.UIFigure.Visible = 'on';

            %% Hauptlayout
            %% Hauptlayout

            % oben / unten
            mainLayout = uigridlayout(app.UIFigure, [2, 1]);
            mainLayout.RowHeight = {40, '1x'};
            mainLayout.Padding = [5, 5, 5, 5]; % Kein Padding um das Hauptlayout
            mainLayout.RowSpacing = 5; % Abstand zwischen den Zeilen



            %% Oben
            %% Oben

            HeaderPanel = uipanel(mainLayout);
            HeaderPanel.BorderType = 'none';

            headerLayout = uigridlayout(HeaderPanel, [1, 2]);
            headerLayout.Padding = [0, 0, 0, 0]; % Padding um den Header
            headerLayout.ColumnWidth = {'1x', 'fit'}; % Links flexibel, rechts feste Größe


            % oben links - Navigation Buttons
            app.ViewSelectionGroup = uibuttongroup(headerLayout);
            app.ViewSelectionGroup.SelectionChangedFcn = @(src,event)app.onViewSelectionChanged();
            app.TimelapseButton = uitogglebutton(app.ViewSelectionGroup, 'Text', 'Zeitraffer', 'Position', [10, 1, 100, 40]);
            app.HighlightsButton = uitogglebutton(app.ViewSelectionGroup, 'Text', 'Veränderung', 'Position', [120, 1, 100, 40]);
            app.ProgressButton = uitogglebutton(app.ViewSelectionGroup, 'Text', 'Fortschritt', 'Position', [230, 1, 100, 40]);
            app.SegmentationButton = uitogglebutton(app.ViewSelectionGroup, 'Text', 'Segmentierung', 'Position', [340, 1, 100, 40]);
            app.ViewSelectionGroup.BorderType = 'none';

            % Container rechts oben
            roiPanel = uipanel(headerLayout);
            roiPanel.BorderType = 'none';


            % ---------- ROI- & Crop-Buttons (rechts oben) ----------
            roiLayout = uigridlayout(roiPanel,[1 2]);   % ⇐ war [1 1]
            roiLayout.ColumnWidth  = {'fit','fit'};
            roiLayout.ColumnSpacing = 8;
            roiLayout.Padding      = [0 0 0 0];

            % ROI-Button (unverändert)
            app.ROIButton = uibutton(roiLayout,'Text','ROI Auswahl');
            app.ROIButton.Layout.Column = 1;
            app.ROIButton.ButtonPushedFcn = @(~,~)app.onROIButtonPushed();

            % Crop-Toggle-Button (NEU)
            app.CropToggleButton = uibutton(roiLayout,'state','Text','Zuschnitt');
            app.CropToggleButton.Layout.Column = 2;
            app.CropToggleButton.ValueChangedFcn = @(src,~)app.onCropToggleChanged(src);
            app.CropToggleButton.Layout.Column = 2;
            app.CropToggleButton.ValueChangedFcn = @(src,~)app.onCropToggleChanged(src);




            %% Unten

            UntenPanel = uipanel(mainLayout);
            UntenPanel.BorderType = 'none';

            contentLayout = uigridlayout(UntenPanel, [1, 3]);
            contentLayout.ColumnWidth = {200, '1x', 420};   % 3. Spalte feste Breite

            contentLayout.Padding = [0, 0, 0, 0]; % Padding um den Content



            %% unten - left panel

            app.LeftPanel = uipanel(contentLayout);
            app.LeftPanel.BorderType = 'line';


            leftLayout = uigridlayout(app.LeftPanel,[3 1]);   % 3 Zeilen
            leftLayout.RowHeight = {'fit' '1x' 'fit'};        % Label | Scroll | Button
            leftLayout.RowSpacing = 5;
            leftLayout.Padding    = [5 5 5 5];
            % leftLayout.BackgroundColor = [0.9 0.9 0.95];      % leichtes Lila

            % 1) Überschrift ------------------------------------------------------
            app.LocationLabel = uilabel(leftLayout, ...
                'Text','Ausgerichtete Locations:', ...
                'FontWeight','bold');
            app.LocationLabel.Layout.Row    = 1;   % <- Layout NACH der Erzeugung
            app.LocationLabel.Layout.Column = 1;

            % 2) Scroll-Panel -----------------------------------------------------
            app.LocationScroll = uipanel(leftLayout, ...
                'BorderType','none', ...
                'AutoResizeChildren','off');   %  <<< wichtig
            app.LocationScroll.Layout.Row = 2;
            app.LocationScroll.Layout.Column = 1;


            app.LocationGrid = uigridlayout(app.LocationScroll,[1 1], ...
                'Scrollable','on');              %  <-- hier landen die Scrollbars
            app.LocationGrid.RowHeight   = {100};   % bleibt unverändert
            app.LocationGrid.ColumnWidth = {'1x'};
            app.LocationGrid.RowSpacing  = 3;
            app.LocationGrid.Padding     = [0 0 0 0];


            % 3) ➕-Button --------------------------------------------------------
            app.AddLocationBtn = uibutton(leftLayout, ...
                'Text','➕ Location hinzufügen', ...
                'FontWeight','bold', ...
                'ButtonPushedFcn',@(~,~)app.showStartupDialog);
            app.AddLocationBtn.Layout.Row    = 3;
            app.AddLocationBtn.Layout.Column = 1;


            %% unten - right panel
            app.ViewSelectionGroup.SelectedObject = app.TimelapseButton;
            rightPanel = uipanel(contentLayout);
            rightPanel.BorderType = 'line';
            rightLayout = uigridlayout(rightPanel, [1 1]);

            % ---------- NEW: Bildauswahl-Panel (ganz rechts) --------------
            app.ImageSelectionPanel = uipanel(contentLayout);
            app.ImageSelectionPanel.BorderType = 'line';
            selLayout = uigridlayout(app.ImageSelectionPanel,[3 1]);
            selLayout.RowHeight = {'fit','1x','fit'};   % Überschrift | Scroll | Button
            selLayout.Padding   = [4 4 4 4];

            % Überschrift
            uilabel(selLayout, ...
                'Text','Bilder der Location', ...
                'FontWeight','bold', ...
                'HorizontalAlignment','center');

            % --- createComponents -----------------------------------------------

            % ❶ Scroll-Container OHNE Scroll-Bars
            app.ImageSelectionScroll = uipanel(selLayout, ...
                'BorderType','none', ...
                'AutoResizeChildren','off');         % keine Scroll‐Bars hier!
            app.ImageSelectionScroll.Layout.Row = 2;

            % ❷ Grid, das später gescrollt wird
            inner = uigridlayout(app.ImageSelectionScroll,[4 1], ...
                'Scrollable','on', ...               %  ←  Scroll-Bars sitzen hier
                'RowHeight',{'fit','fit','fit','fit'}, ...
                'Padding',[0 0 0 0]);

            inner.RowHeight = {'fit','fit','fit','fit'};
            inner.Padding   = [0 0 0 0];

            % Header 1
            uilabel(inner,'Text','✔ für Ausrichtung verwendet');
            % Grid 1 (wird später per Code gefüllt)
            app.AlignedGrid = uigridlayout(inner,[1 1], ...
                'Padding',[0 0 0 0], ...
                'RowHeight',{'fit'}, ...
                'ColumnWidth',{'1x', '1x'}, ...
                'RowSpacing',8,'ColumnSpacing',8);

            % Header 2
            uilabel(inner,'Text','✖ nicht verwendet','FontAngle','italic');
            % Grid 2
            app.NotAlignedGrid = uigridlayout(inner,[1 1], ...
                'Padding',[0 0 0 0], ...
                'RowHeight',{'fit'}, ...
                'ColumnWidth',{'1x', '1x'}, ...
                'RowSpacing',8,'ColumnSpacing',8);




            % === TIMELAPSE ===
            app.TimelapseViewObj.createTimelapsePanel(rightLayout);



            % === Highlights ===
            app.HighlightsViewObj.createHighlightsPanel(rightLayout);


            % === Progress ===
            app.ProgressViewObj.createProgressPanel(rightLayout);

            % === Segementation ===
            app.SegmentationViewObj.createSegmentationPanel(rightLayout);

        end
        function imgs = getDisplayImages(app)
            % Gibt die aktuell anzuzeigenden Bilder zurück
            if app.ShowCrop && ~isempty(app.CroppedImages)
                imgs = app.CroppedImages;
            else
                imgs = app.CurrentLocationImages;
            end
        end
    end
end
