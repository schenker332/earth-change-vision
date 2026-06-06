%==========================================================================
% HighlightsView – Change-Highlights-Ansicht
%==========================================================================
%
% File:
%   HighlightsView.m
%
% Beschreibung:
%   Diese Klasse implementiert die View für die Anzeige von
%   Veränderungs-Highlights zwischen zwei Satellitenbildern.
%   Features:
%     • Farb-Intensität vs. Rand-Detektion (RedEdge)
%     • Einstellbare Schwellen für Stärke, Fläche und Deckungskraft
%
%
%==========================================================================
classdef HighlightsView < handle
    % HIGHLIGHTSVIEW - View for displaying change highlights (Color vs. RedEdge)

    properties (Access = public)
        App
        HighlightsPanel       matlab.ui.container.Panel
        SubModeGroup          matlab.ui.container.ButtonGroup
        Color                 matlab.ui.control.ToggleButton  % Color
        RedEdge               matlab.ui.control.ToggleButton  % RedEdge
        HighlightsAxes        matlab.ui.control.UIAxes
        StrengthSlider        matlab.ui.control.Slider
        AreaSlider            matlab.ui.control.Slider

        % Default-Thresholds
        DefaultChangeStrengthThresh  = 0.5
        DefaultChangeAreaThresh      = 0.0001

        % --- NEW: Alpha-Slider (nur im Edge-Modus) -------------------------------
        AlphaLabel   matlab.ui.control.Label
        AlphaSlider  matlab.ui.control.Slider

    end

    methods (Access = public)
        function obj = HighlightsView(app)
            obj.App = app;
        end

        function createHighlightsPanel(obj, parentLayout)
            % === Main Panel ===
            obj.HighlightsPanel = uipanel(parentLayout, 'BorderType','line', 'Visible','off');
            obj.HighlightsPanel.Layout.Row = 1;

            % Create a 3-row grid: toggles (fixed height), axes (flexible), settings (fit)
            mainGrid = uigridlayout(obj.HighlightsPanel, [3,1]);
            mainGrid.RowHeight   = {50, '1x', 'fit'};  % first row 50px
            mainGrid.Padding     = [10 10 10 10];
            mainGrid.RowSpacing  = 10;

            % === Zeile 1: Sub-Mode Buttons ===
            row1 = uipanel(mainGrid, 'BorderType','none');
            row1.Layout.Row = 1;
            subGrid = uigridlayout(row1, [1,2]);
            subGrid.ColumnWidth = {'1x','fit'};
            subGrid.Padding = [0 0 0 0];

            obj.SubModeGroup = uibuttongroup(subGrid, 'SelectionChangedFcn', @(~,~) obj.onViewChanged(), ...
                'BorderType','none');
            obj.Color = uitogglebutton(obj.SubModeGroup, 'Text','Intensität', 'Position',[10 5 100 40]);
            obj.RedEdge = uitogglebutton(obj.SubModeGroup, 'Text','Umrandung', 'Position',[120 5 100 40]);
            obj.SubModeGroup.SelectedObject = obj.Color;

            % === Zeile 2: Banner | Achse | Banner ================================
            row2 = uigridlayout(mainGrid,[1 3]);      % 1 Zeile, 3 Spalten
            row2.Layout.Row    = 2;
            row2.ColumnWidth   = {'1x','3x','1x'};    % mittlere Spalte dominiert
            row2.Padding       = [0 0 0 0];
            row2.ColumnSpacing = 0;
            row2.RowSpacing    = 0;

            % ----- linker Banner -------------------------------------------------
            imgL = uiimage(row2, ...
                'ImageSource','resources/backgrounds/background_links.png', ...
                'ScaleMethod','fill');
            imgL.Layout.Column = 1;

            % ----- Achse in der Mitte -------------------------------------------
            ax = uiaxes(row2, ...
                'Box','on', 'Color','none', 'XTick',[], 'YTick',[]);
            ax.Layout.Column   = 2;
            ax.Toolbar.Visible = 'off';
            hold(ax,'on');
            obj.HighlightsAxes = ax;                  %  Handle merken

            % ----- rechter Banner ------------------------------------------------
            imgR = uiimage(row2, ...
                'ImageSource','resources/backgrounds/background_rechts.png', ...
                'ScaleMethod','fill');
            imgR.Layout.Column = 3;

            % === Zeile 3: Slider-Panel (ohne Titel­rahmen) ==================================
            sliderPanel = uipanel(mainGrid,'BorderType','none');
            sliderPanel.Layout.Row = 3;

            % 6 Zeilen × 2 Spalten – analog zu ProgressView
            spGrid = uigridlayout(sliderPanel,[6 2]);
            spGrid.RowHeight   = {'fit','fit','fit','fit','fit','fit'};
            spGrid.ColumnWidth = {'1x','fit'};
            spGrid.RowSpacing  = 8;
            spGrid.ColumnSpacing = 8;

            % 1) Strength-Label
            lbl1 = uilabel(spGrid,'Text','Unterschiedsstärke', ...
                'HorizontalAlignment','center');
            lbl1.Layout.Row = 1; lbl1.Layout.Column = 1;

            % 2) Strength-Slider
            obj.StrengthSlider = uislider(spGrid,'Limits',[0 1], ...
                'MajorTicks',0:0.2:1, ...
                'Value',obj.DefaultChangeStrengthThresh, ...
                'ValueChangedFcn',@(~,~) obj.onViewChanged());
            obj.StrengthSlider.Layout.Row = 2; obj.StrengthSlider.Layout.Column = 1;
            obj.StrengthSlider.MajorTickLabels = {'0%', '20%', '40%' ,'60%' , '80%' ,'100%'};

            % 3) Area-Label
            lbl2 = uilabel(spGrid,'Text','Fläche', ...
                'HorizontalAlignment','center');
            lbl2.Layout.Row = 3; lbl2.Layout.Column = 1;

            % 4) Area-Slider
            obj.AreaSlider = uislider(spGrid,'Limits',[0 0.01], ...
                'MajorTicks',0:0.002:0.01, ...
                'Value',obj.DefaultChangeAreaThresh, ...
                'ValueChangedFcn',@(~,~) obj.onViewChanged());
            obj.AreaSlider.Layout.Row = 4; obj.AreaSlider.Layout.Column = 1;
            obj.AreaSlider.MajorTickLabels = {'0%','0.2%','0.4%','0.6%','0.8%','1%'};

            % 5) Alpha-Label  (initial unsichtbar)
            obj.AlphaLabel = uilabel(spGrid,'Text','Deckungskraft', ...
                'HorizontalAlignment','center', ...
                'Visible','off');
            obj.AlphaLabel.Layout.Row = 5; obj.AlphaLabel.Layout.Column = 1;


            % 6) Alpha-Slider (initial unsichtbar)
            obj.AlphaSlider = uislider(spGrid,'Limits',[0 1], ...
                'MajorTicks',0:0.2:1, ...
                'Value',0.5, ...
                'Visible','off', ...
                'ValueChangedFcn',@(~,~) obj.onViewChanged());
            obj.AlphaSlider.Layout.Row = 6; obj.AlphaSlider.Layout.Column = 1;
            obj.AlphaSlider.MajorTickLabels =  {'0%', '20%', '40%' ,'60%' , '80%' ,'100%'};

        end

        function initializeHighlightsView(obj)
            % Called when the GUI switches to this view
            obj.HighlightsPanel.Visible = 'on';
            % Ensure default toggle is selected
            if isempty(obj.SubModeGroup.SelectedObject)
                obj.SubModeGroup.SelectedObject = obj.Color;
            end
            obj.onViewChanged();
        end

        function onViewChanged(obj, ~, ~)
            imgs     = obj.App.getDisplayImages();
            selImgs  = imgs(obj.App.SelectedMask);
            img1     = selImgs{1};
            img2     = selImgs{end};

            mode = lower(obj.SubModeGroup.SelectedObject.Text);

            % Slider-Sichtbarkeit umschalten
            isEdge              = strcmp(mode,'umrandung');
            obj.AlphaLabel.Visible  = isEdge;
            obj.AlphaSlider.Visible = isEdge;

            sThr = obj.StrengthSlider.Value;
            aThr = obj.AreaSlider.Value;
            aVal = obj.AlphaSlider.Value;      % wird ignoriert, falls nicht Edge

            % Rendern
            renderHighlightsView( ...
                obj.HighlightsAxes, img1, img2, mode, ...
                sThr, aThr, 'all', aVal );
        end

    end
end
