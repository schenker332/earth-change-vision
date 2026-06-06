%==========================================================================
% ProgressView – Progress-Ansicht
%==========================================================================
%
% File:
%   ProgressView.m
%
% Beschreibung:
%   Diese Klasse implementiert die View zur Darstellung des Fortschritts
%   von Veränderungen zwischen zwei oder mehr Satellitenbildern durch
%   sequentielle Überlagerung von Veränderungskonturen.
%   Features:
%     • Einstellbare Schwellen für Unterschiedsstärke und -fläche
%     • Sequentielle Kontur-Overlays in zeitlicher Reihenfolge
%     • Option zum Umdrehen der Bildreihenfolge (Alt ↔ Neu)
%     • Unterstützung des globalen Crop-Modus für Zuschnitt
%
%==========================================================================
classdef ProgressView < handle
    properties (Access = public)
        App
        ProgressPanel
        SampleButton
        ProgressAxes     matlab.ui.control.UIAxes
        StrengthSlider   matlab.ui.control.Slider
        AreaSlider       matlab.ui.control.Slider
        ReverseButton    matlab.ui.control.Button
        ReverseOrder     logical = false

    end

    methods
        function obj = ProgressView(app)
            obj.App = app;
        end

        function createProgressPanel(obj, parentLayout)
            % Panel erzeugen und verstecken
            obj.ProgressPanel = uipanel(parentLayout,'BorderType','none');
            obj.ProgressPanel.Layout.Row = 1;
            obj.ProgressPanel.Visible = 'off';

            % -----------------------------------------------------------------
            % Layout: 2 Zeilen, 1. Zeile: Achse, 2. Zeile: Slider-Panel
            % -----------------------------------------------------------------
            grid = uigridlayout(obj.ProgressPanel, [2,1]);
            grid.RowHeight   = {'1x','fit'};
            grid.Padding     = [10 10 10 10];
            grid.RowSpacing  = 10;

            % --- 1) Banner | Achse | Banner ------------------------------------
            row1 = uigridlayout(grid,[1 3]);           % 1 Zeile, 3 Spalten
            row1.Layout.Row    = 1;
            row1.ColumnWidth   = {'1x','3x','1x'};     % Mitte breiter
            row1.Padding       = [0 0 0 0];
            row1.ColumnSpacing = 0;
            row1.RowSpacing    = 0;

            % linker Banner ------------------------------------------------------
            imgL = uiimage(row1, ...
                'ImageSource','resources/backgrounds/background_links.png', ...
                'ScaleMethod','fill');
            imgL.Layout.Column = 1;

            % Progress-Achse in der Mitte ---------------------------------------
            ax = uiaxes(row1,'XTick',[],'YTick',[]);
            ax.Layout.Column = 2;
            ax.Toolbar.Visible = 'off';
            hold(ax,'on');
            obj.ProgressAxes = ax;

            % rechter Banner -----------------------------------------------------
            imgR = uiimage(row1, ...
                'ImageSource','resources/backgrounds/background_rechts.png', ...
                'ScaleMethod','fill');
            imgR.Layout.Column = 3;

            % --- 2) Slider-Panel ----------------------------------------------------
            sliderPanel = uipanel(grid,'BorderType','none');
            sliderPanel.Layout.Row = 2;

            % 2a) Layout: 4 Zeilen × 2 Spalten
            spGrid = uigridlayout(sliderPanel,[4,2]);
            spGrid.RowHeight     = {'fit','fit','fit','fit'};
            spGrid.ColumnWidth   = {'1x','fit'};   % rechts schmale Spalte
            spGrid.RowSpacing    = 8;
            spGrid.ColumnSpacing = 8;

            % 1) Strength-Label (links)
            lbl1 = uilabel(spGrid,'Text','Unterschiedsstärke', ...
                'HorizontalAlignment','center');
            lbl1.Layout.Row = 1; lbl1.Layout.Column = 1;

            % 2) Strength-Slider (links)
            obj.StrengthSlider = uislider(spGrid,'Limits',[0 1],'Value',0.4, ...
                'MajorTicks',0:0.2:1, ...
                'ValueChangedFcn',@(s,~) obj.updateProgressPlot());
            obj.StrengthSlider.Layout.Row = 2; obj.StrengthSlider.Layout.Column = 1;
            obj.StrengthSlider.MajorTickLabels = {'0%', '20%', '40%' ,'60%' , '80%' ,'100%'};

            % 3) Area-Label (links)
            lbl2 = uilabel(spGrid,'Text','Fläche', ...
                'HorizontalAlignment','center');
            lbl2.Layout.Row = 3; lbl2.Layout.Column = 1;

            % 4) Area-Slider (links)
            obj.AreaSlider = uislider(spGrid,'Limits',[0 0.01],'Value',0.0005, ...
                'MajorTicks',0:0.002:0.01, ...
                'ValueChangedFcn',@(s,~) obj.updateProgressPlot());
            obj.AreaSlider.Layout.Row = 4; obj.AreaSlider.Layout.Column = 1;
            obj.AreaSlider.MajorTickLabels = {'0%','0.2%','0.4%','0.6%','0.8%','1%'};

            % 5) Reverse-Button (rechts, kompakt)
            obj.ReverseButton = uibutton(spGrid,'Text','⇆', ...   % kleines Icon
                'Tooltip','Reihenfolge Alt ↔ Neu umschalten', ...
                'ButtonPushedFcn',@(btn,~) obj.toggleReverseOrder());
            obj.ReverseButton.Layout.Row    = [2 4];  % vertikal mittig
            obj.ReverseButton.Layout.Column = 2;      % rechte Spalte
            obj.ReverseButton.Text = 'Alt→Neu';


        end



        function initializeProgressView(obj)
            obj.ProgressPanel.Visible = 'on';
            obj.updateProgressPlot();
        end

        function updateProgressPlot(obj)
            % 1) Overlay berechnen (gibt nur das Bild zurück, öffnet kein neues figure)
            imgsAll = obj.App.CurrentLocationImages;
            sel     = obj.App.SelectedMask;
            imgs    = imgsAll(sel);
            selIdx  = find(sel);

            % • Bildfolge ggf. umdrehen
            if obj.ReverseOrder
                imgs   = flip(imgs);
                selIdx = selIdx(end:-1:1);
            end

            if numel(imgs) < 2
                cla(obj.ProgressAxes);
                return;
            end
            overlay = overlayChangeContoursSequentially(imgs, ...
                'StrengthThreshold', obj.StrengthSlider.Value, ...
                'AreaThreshold',     obj.AreaSlider.Value);

            % — nur im Crop-Mode: das fertige Overlay auf die gemeinsame BBox zuschneiden
            if obj.App.ShowCrop && ~isempty(obj.App.CropBBox)
                bb = obj.App.CropBBox;      % [x y w h]
                x1 = bb(1);  y1 = bb(2);
                x2 = x1 + bb(3) - 1;
                y2 = y1 + bb(4) - 1;
                % Begrenze auf Bildgrenzen
                x2 = min(size(overlay,2), x2);
                y2 = min(size(overlay,1), y2);
                overlay = overlay(y1:y2, x1:x2, :);
            end


            % 2) Achse leeren und Bild anzeigen
            cla(obj.ProgressAxes);
            imshow(overlay, 'Parent', obj.ProgressAxes, 'InitialMagnification', 'fit');
            obj.ProgressAxes.XTick = [];
            obj.ProgressAxes.YTick = [];

            % 3) Legende mit Bildnamen zeichnen
            hold(obj.ProgressAxes, 'on');
            nSteps = numel(selIdx) - 1;
            if nSteps > 0
                cols = lines(nSteps);
                arrow = '→';
                if obj.ReverseOrder
                    arrow = '←';   % zeigt die tatsächliche Vergleichsrichtung an
                end
                labels = strcat( ...
                    obj.App.CurrentLocationDates(selIdx(1:end-1)), ...
                    arrow, ...
                    obj.App.CurrentLocationDates(selIdx(2:end)) );
                for j = 1:nSteps
                    plot(obj.ProgressAxes, nan, nan, 's', ...
                        'MarkerFaceColor', cols(j,:), ...
                        'MarkerEdgeColor', cols(j,:));
                end
                legend(obj.ProgressAxes, labels, ...
                    'Location', 'northeast', ...
                    'Interpreter','none');
            end
            hold(obj.ProgressAxes, 'off');
        end




    end

    methods (Access = private)
        function onSampleButtonPushed(obj)
            uialert(obj.App.UIFigure, ...
                'Sample-Button gedrückt!', ...
                'Info');
        end

        function toggleReverseOrder(obj)
            obj.ReverseOrder = ~obj.ReverseOrder;
            if obj.ReverseOrder
                obj.ReverseButton.Text = 'Neu→Alt';
            else
                obj.ReverseButton.Text = 'Alt→Neu';
            end
            % Update Plot mit neuer Reihenfolge
            obj.updateProgressPlot();
        end

    end
end