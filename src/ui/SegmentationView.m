%==========================================================================
% SegmentationView – Segmentierungs-Ansicht
%==========================================================================
%
% File:
%   SegmentationView.m
%
% Beschreibung:
%   Diese Klasse implementiert die View zur Anzeige und Analyse von
%   Segmentierungsergebnissen zwischen zwei Satellitenbildern.
%   Features:
%     • Darstellung der segmentierten Überlagerungen
%     • Anzeige von Flächenstatistiken je Klasse
%     • Dynamische Legende mit Klassenfarben
%     • Unterstützung des globalen Crop-Modus
%
%==========================================================================
classdef SegmentationView < handle
    % SEGMENTATIONVIEW - View für Segmentierungs-Ansicht

    properties (Access = public)
        App
        SegmentationPanel            matlab.ui.container.Panel
        StatsPanel                   matlab.ui.container.Panel
        StatsGrid                    matlab.ui.container.GridLayout
        LegendPanel                  matlab.ui.container.Panel   % feste Legende oben‑links
        SelectedMask                 % Maske für die Segmentierung
        LocationsPath                % Pfad zu den Locations
        ChoosenLocation              % Ausgewählte Location
        CurrentLocationDates         % Daten der aktuellen Location
        CurrentLocationImages        % Bilder der aktuellen Location
    end

    properties (Constant, Access = private)
        UnifiedClassNames = {'Wasser','Vegetation','Gebäude','Bebaute Fläche','Offenland'};
        UnifiedColorMap   = [0 0 255;0 128 0;255 0 0;128 128 128;255 255 153]./255;
    end

    methods (Access = public)
        function obj = SegmentationView(app)
            obj.App = app;
        end

        function createSegmentationPanel(obj,parentLayout)

            % ── Äußeres Panel (unsichtbar bis Initialisierung) ─────────────
            obj.SegmentationPanel = uipanel(parentLayout, ...
                'Title','Segmentation Ansicht', ...
                'BorderType','line','Visible','off');
            obj.SegmentationPanel.Layout.Row = 1;

            % ── Outer grid: 2 Zeilen  (Bilder oben, Stats unten) ───────────
            outer = uigridlayout(obj.SegmentationPanel,[2 1]);
            outer.RowHeight    = {'1x','fit'};
            outer.ColumnWidth  = {'1x'};
            outer.RowSpacing   = 4;
            outer.Padding      = [0 0 0 0];

            % ── feste Legende (liegt über dem Grid, immer sichtbar) ───────
            obj.LegendPanel = uipanel(obj.SegmentationPanel , ...
                'Units'      ,'normalized', ...
                'Position'   ,[0.01 0.88 0.18 0.12], ...  % oben‑links
                'BorderType' ,'line', ...
                'Tag'        ,'LegendPanel');
            % sicherstellen, dass die Legende vor allen anderen UI‑Elementen liegt
            uistack(obj.LegendPanel,'top');

            % ── Row 1: 1×2‑Grid für die beiden Bilder ──────────────────────
            gImg = uigridlayout(outer,[1 2], ...
                'RowHeight',{'1x'},'ColumnWidth',{'1x','1x'}, ...
                'RowSpacing',0,'ColumnSpacing',0,'Padding',[0 0 0 0]);

            axL = uiaxes(gImg); axL.Layout.Column = 1;
            axR = uiaxes(gImg); axR.Layout.Column = 2;
            for ax = [axL axR]
                ax.XTick = []; ax.YTick = []; ax.Box = 'off';
            end
            axL.Tag = 'LeftAx';   axR.Tag = 'RightAx';

            % ── Row 2: Panel für Statistik‑Labels ──────────────────────────
            obj.StatsPanel = uipanel(outer);
            obj.StatsPanel.Layout.Row = 2;
            obj.StatsPanel.Layout.Column = 1;

            % ── Gridlayout für Statistik‑Labels in Panel ───────────────────
            obj.StatsGrid = uigridlayout(obj.StatsPanel,[1 3], ...
                'RowHeight',{ 'fit' }, ...
                'ColumnWidth',{ '1x','fit','1x'}, ...
                'RowSpacing',0,'ColumnSpacing',10,'Padding',[0 0 4 4]);
            % leere Platzhalter‑Labels
            uilabel(obj.StatsGrid,'Text','','Tag','StatsLeft');
            uilabel(obj.StatsGrid,'Text','','Tag','StatsDiff');
            uilabel(obj.StatsGrid,'Text','','Tag','StatsRight');
        end

        function initializeSegmentationView(obj)
            persistent lastOverlayA lastOverlayB lastDatesA lastDatesB lastClassNames lastColorNames lastPercentA lastPercentB lastPercentDiff

            % --- Panel refresh --------------------------------------------------
            obj.SegmentationPanel.Visible = 'on';
            % delete(findobj(obj.SegmentationPanel,'Type','uilabel','-not','Tag','LegendLabel'));
            [axLeft, axRight] = obj.ensureImageAxes();
            cla(axLeft);
            cla(axRight);

            dates = obj.App.CurrentLocationDates;
            selectedMask = obj.App.SelectedMask;
            alignedMask = obj.App.AlignedMask;

            outMask = selectedMask(alignedMask ~= 0);   %  ⇒  [1 0 0 0 1]

            selectedIdx = find(outMask == 1);

            if numel(selectedIdx) > 2
                uialert(obj.App.UIFigure, ...
                    'Bitte genau zwei Bilder auswählen.', ...
                    'Ungültige Anzahl Bilder');

                if ~isempty(lastOverlayA)
                    obj.displaySegmentationResults(lastOverlayA, lastDatesA, lastOverlayB, lastDatesB);
                    obj.displaySegmentationStats(lastClassNames, lastColorNames, lastPercentA, lastPercentB, lastPercentDiff);
                end
                return
            elseif numel(selectedIdx) < 2
                if ~isempty(lastOverlayA)
                    obj.displaySegmentationResults(lastOverlayA, lastDatesA, lastOverlayB, lastDatesB);
                    obj.displaySegmentationStats(lastClassNames, lastColorNames, lastPercentA, lastPercentB, lastPercentDiff);
                end
                return

            end

            selectDatesTformsIdx = find(selectedMask);
            selectedDates = dates(selectDatesTformsIdx);
            tforms = obj.App.tforms;  % Transformationen für die Bilder der aktuellen Location

            tformsA = tforms(selectedIdx(1));
            tformsB = tforms(selectedIdx(2));
            imageA = fullfile(obj.App.LocationsPath, ...
                obj.App.ChoosenLocation, ...
                [selectedDates{1} '.jpg']);
            imageB = fullfile(obj.App.LocationsPath, ...
                obj.App.ChoosenLocation, ...
                [selectedDates{2} '.jpg']);


            dlg = uiprogressdlg(obj.App.UIFigure, ...
                'Title', 'Segmentierung läuft', ...
                'Message', 'Bitte warten, Segmentierung wird durchgeführt ...', ...
                'Indeterminate', 'on');
            % Segmentierung durchführen
            [overlayA, overlayB, classNames, colorNames, percentA, percentB, percentDiff] = ...
                runSegmentation(imageA, imageB, tformsA, tformsB);
            close(dlg);
            % Anzeige Overlays
            obj.displaySegmentationResults(overlayA, selectedDates{1}, overlayB, selectedDates{2});
            % Anzeige Statistik

            obj.displaySegmentationStats(classNames, colorNames, percentA, percentB, percentDiff);
            obj.drawLegend();

            lastOverlayA = overlayA;
            lastOverlayB = overlayB;
            lastDatesA = selectedDates{1};
            lastDatesB = selectedDates{2};
            lastClassNames = classNames;
            lastColorNames = colorNames;
            lastPercentA = percentA;
            lastPercentB = percentB;
            lastPercentDiff = percentDiff;
        end

        function displaySegmentationResults(obj, overlayA, datesA, overlayB, datesB)
            % Draw the two overlay images into their respective axes.
            [axLeft,axRight] = obj.ensureImageAxes();

            imshow(overlayA,'Parent',axLeft,'InitialMagnification','fit');
            title(axLeft,sprintf('%s - %s',obj.App.ChoosenLocation,datesA), ...
                'Interpreter','none');

            imshow(overlayB,'Parent',axRight,'InitialMagnification','fit');
            title(axRight,sprintf('%s - %s',obj.App.ChoosenLocation,datesB), ...
                'Interpreter','none');
        end

        function displaySegmentationStats(obj,classNames,~,percentA,percentB,percentDiff)
            % Ensure stats labels exist
            lblL = findobj(obj.StatsGrid,'Tag','StatsLeft');
            if isempty(lblL)
                lblL = uilabel(obj.StatsGrid, 'Tag','StatsLeft', 'Text','');
                lblL.Layout.Row = 1; lblL.Layout.Column = 1;
            end
            lblR = findobj(obj.StatsGrid,'Tag','StatsRight');
            if isempty(lblR)
                lblR = uilabel(obj.StatsGrid, 'Tag','StatsRight', 'Text','');
                lblR.Layout.Row = 1; lblR.Layout.Column = 3;
            end
            lblD = findobj(obj.StatsGrid,'Tag','StatsDiff');
            if isempty(lblD)
                lblD = uilabel(obj.StatsGrid, 'Tag','StatsDiff', 'Text','');
                lblD.Layout.Row = 1; lblD.Layout.Column = 2;
            end

            % Textblöcke erstellen
            txtL = strjoin(arrayfun(@(i) sprintf('%s: %.1f%%', classNames{i}, percentA(i)), 1:numel(classNames), 'UniformOutput', false), '\n');
            txtR = strjoin(arrayfun(@(i) sprintf('%s: %.1f%%', classNames{i}, percentB(i)), 1:numel(classNames), 'UniformOutput', false), '\n');

            lblL.Text = txtL;
            lblR.Text = txtR;

            diffTxt = strjoin(arrayfun(@(i) ...
                sprintf('%+.1f%%', percentDiff(i)), 1:numel(classNames), 'UniformOutput', false), '\n');
            lblD.Text = diffTxt;

            lblL.HorizontalAlignment = 'center';
            lblR.HorizontalAlignment = 'center';
            lblD.HorizontalAlignment = 'center';
            lblL.FontSize = 10;  lblR.FontSize = 10; lblD.FontSize = 10;

            % Diff‑Label (zentral unter den Bildern)
            % Diff‐Label (ganz unten in der StatsPanel, über beide Spalten)
            % Diff-Label unter den Statistik-Labels im StatsGrid
            % 1) RowHeight um eine zweite Zeile erweitern (falls noch nicht geschehen)
            % obj.StatsGrid.RowHeight = {'fit','fit'};

            % 2) Existierendes Δ-Label entfernen
            % oldD = findobj(obj.StatsGrid, 'Tag', 'DiffLabel');
            % delete(oldD);

            % 3) Delta-Texte vorbereiten
            % deltaTexts = arrayfun(@(p) sprintf('%.1f%%', p), percentDiff, 'UniformOutput', false);

            % 4) Neues Δ-Label erzeugen, das beide Spalten überspannt
            % dLbl = uilabel(obj.StatsGrid, ...
            %     'Tag', 'DiffLabel', ...
            %     'Text', sprintf('Δ: %s', strjoin(deltaTexts, ', ')), ...
            %     'FontSize', 10, ...
            %     'HorizontalAlignment', 'center');

            % 5) Layout—zweite Zeile, beide Spalten
            % dLbl.Layout.Row    = 2;
            % dLbl.Layout.Column = [1 2];
        end

        function drawLegend(obj)
            % Kompakte Legende oben links (immer vollständig sichtbar)

            if isempty(obj.LegendPanel) || ~isvalid(obj.LegendPanel)
                return
            end
            delete(obj.LegendPanel.Children);                       % alte Einträge

            nC        = numel(obj.UnifiedClassNames);               % # Klassen
            chipSize  = 10;                                         % px-Kanten
            lineSpace = 2;                                          % Zeilenabstand (px)

            % ── Panelgröße in Pixeln berechnen ────────────────────────────────
            panW = 100;                                             % feste Breite
            panH = nC*(chipSize+lineSpace)+lineSpace;               % Höhe passt sich an
            % Panel ganz links-oben platzieren (ohne 8 px Top-Rand)
            drawnow; % sicherstellen, dass Layout aktualisiert ist
            panelPos = getpixelposition(obj.SegmentationPanel, true);
            panelWidth = panelPos(3);
            panelHeight = panelPos(4);

            pPos = [panelWidth - panW - 15, panelHeight-panH-25, panW+2, panH];
            obj.LegendPanel.Units    = 'pixels';
            obj.LegendPanel.Position = pPos;

            % ── Grid in der Legende ───────────────────────────────────────────
            g = uigridlayout(obj.LegendPanel,[nC 2], ...
                'RowHeight', repmat({chipSize},1,nC), ...
                'ColumnWidth',{chipSize+2, '1x'}, ...
                'Padding',[2 2 2 2], ...
                'RowSpacing', lineSpace, ...
                'ColumnSpacing', 6);

            % ── Einträge zeilen­weise anlegen ─────────────────────────────────
            for c = 1:nC
                % Farbfeld
                chip = uipanel(g, ...
                    'BackgroundColor', obj.UnifiedColorMap(c,:), ...
                    'BorderType',      'line');
                chip.Layout.Row    = c;
                chip.Layout.Column = 1;

                % Klassenname
                lbl = uilabel(g, ...
                    'Text',       obj.UnifiedClassNames{c}, ...
                    'FontSize',   8, ...
                    'Interpreter','none', ...
                    'HorizontalAlignment','left');
                lbl.Layout.Row    = c;
                lbl.Layout.Column = 2;
            end

            % Panel über alle anderen Child-Elemente legen
            uistack(obj.LegendPanel,'top');
        end
    end

    methods (Access = private)
        function [axLeft,axRight] = ensureImageAxes(obj)
            % Returns handles to the left and right image axes.
            % If they don't exist yet a fresh 1×2 grid with axes is created.
            axLeft  = findobj(obj.SegmentationPanel,'-isa','matlab.ui.control.UIAxes','Tag','LeftAx');
            axRight = findobj(obj.SegmentationPanel,'-isa','matlab.ui.control.UIAxes','Tag','RightAx');

            % stats‑labels bleiben erhalten

            if isempty(axLeft) || isempty(axRight)
                % remove every child except the legend‑axes (if present)
                keepAx = findobj(obj.SegmentationPanel,'Type','axes','Tag','LegendAx');
                delete(setdiff(obj.SegmentationPanel.Children, keepAx))

                % new grid takes whole panel
                grid = uigridlayout(obj.SegmentationPanel,[1 2], ...
                    'RowHeight',{'1x'},'ColumnWidth',{'1x','1x'}, ...
                    'RowSpacing',0,'ColumnSpacing',0,'Padding',[0 0 0 0]);

                axLeft  = uiaxes(grid);   axLeft.Layout.Row = 1; axLeft.Layout.Column = 1;
                axRight = uiaxes(grid);   axRight.Layout.Row = 1; axRight.Layout.Column = 2;

                for ax = [axLeft,axRight]
                    ax.XTick=[]; ax.YTick=[]; ax.Box='off';
                end
                axLeft.Tag  = 'LeftAx';
                axRight.Tag = 'RightAx';
            else
                % take first handles (findobj can return many if duplicated)
                axLeft  = axLeft(1);
                axRight = axRight(1);
                cla(axLeft);
                cla(axRight);
                axLeft.XTick=[];  axLeft.YTick=[];  axLeft.Box='off';
                axRight.XTick=[]; axRight.YTick=[]; axRight.Box='off';
            end
        end
    end
end
