%==========================================================================
% TimelapseView – Zeitraffer-Ansicht
%==========================================================================
%
% File:
%   TimelapseView.m
%
% Beschreibung:
%   Diese Klasse steuert die Wiedergabe und Interaktion mit der
%   Zeitraffer-Sequenz aus Satellitenbildern.
%   Features:
%     • Sanftes Blending zwischen Bildern (optimiert, sauberer Loop)
%     • Steuerung via Slider und Play/Pause-Button
%     • Einstellbarer Alpha-Übergang und Frame-Rate (~15 fps)
%     • Unterstützung des globalen Crop-Modus für Zuschnitt
%
%==========================================================================
classdef TimelapseView < handle
    % TimelapseView - Abspielen & Steuern der Timelapse-Sequenz

    properties (Access = public)
        App
        TimelapsePanel                            % Referenz zur GUI
        CurrImgHandle matlab.graphics.primitive.Image
        NextImgHandle matlab.graphics.primitive.Image
        AlphaSlider   matlab.ui.control.Slider
        PauseAfterLoop double = 1           % s Pause am Zyklusende
        PlayTimer    timer
        FrameSteps   double = 5      % wie viele Alpha-Steps von 0→1
        StepIdx      double = 0      % Fortschritt innerhalb eines Frames
        CacheImgs    cell            % gepufferte Bilddaten
        CacheDates   cell            % gepufferte Datumslabels

        IsPlaying     logical = false
        TimelapseAxes matlab.ui.control.UIAxes
        TimelapseSlider matlab.ui.control.Slider
        DateLabel     matlab.ui.control.Label
        PlayButton    matlab.ui.control.Button
    end

    methods (Access = public)
        function obj = TimelapseView(app)
            obj.App = app;

            obj.PlayTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period',        1/15, ...          % ≈15 fps
                'BusyMode',      'drop', ...
                'Tag',           'SCV_PlayTimer', ...
                'TimerFcn',      @(~,~) obj.onTick() );

        end

        function createTimelapsePanel(obj, parentLayout)
            % Panel und Layout
            pnl = uipanel(parentLayout);
            obj.TimelapsePanel = pnl;
            pnl.Layout.Row = 1; pnl.BorderType = 'none';

            gl = uigridlayout(pnl, [6, 1]);

            gl.RowHeight  = {'1x',22,60,22,60,22};
            gl.Padding    = [10,10,10,10];
            gl.RowSpacing = 5;

            % 1) Bildanzeige: Banner-Achse-Banner
            row1 = uigridlayout(gl,[1 3]);          % 1 Zeile, 3 Spalten
            row1.Layout.Row     = 1;
            row1.ColumnWidth    = {'1x','3x','1x'}; % Mitte dominiert
            row1.Padding        = [0 0 0 0];
            row1.ColumnSpacing  = 0;
            row1.RowSpacing     = 0;

            % ----- linker Banner -----------------------------------------------
            imgL = uiimage(row1, ...
                'ImageSource', 'resources/backgrounds/background_links.png', ...
                'ScaleMethod', 'fill');
            imgL.Layout.Column = 1;

            % ----- Timelapse-Achse (wie zuvor) ----------------------------------
            ax = uiaxes(row1,'XTick',[],'YTick',[],'Box','on');
            ax.Layout.Column   = 2;
            ax.Toolbar.Visible = 'off';
            hold(ax,'on');
            obj.TimelapseAxes  = ax;          % <-- Referenz wieder setzen

            % ----- rechter Banner -----------------------------------------------
            imgR = uiimage(row1, ...
                'ImageSource', 'resources/backgrounds/background_rechts.png', ...
                'ScaleMethod', 'fill');
            imgR.Layout.Column = 3;


            % 2) Label Hauptslider
            lbl1 = matlab.ui.control.Label('Parent', gl, 'Text', 'Bild auswählen:', 'HorizontalAlignment', 'left');
            lbl1.Layout.Row = 2;

            % 3) Slider + Play-Button
            row3 = uigridlayout(gl, [1,2]); row3.Layout.Row = 3;
            row3.ColumnWidth   = {'1x',50}; row3.ColumnSpacing = 10;
            row3.Padding       = [0,0,0,0];
            row3.RowSpacing    = 0;
            obj.TimelapseSlider = uislider(row3);
            obj.TimelapseSlider.Layout.Column = 1;
            obj.TimelapseSlider.ValueChangingFcn = @(s, e) obj.onSliderSnapped(e);
            obj.PlayButton = uibutton(row3, 'Text', '▶');
            obj.PlayButton.Layout.Column = 2;
            obj.PlayButton.ButtonPushedFcn = @(btn,~)obj.toggleTimelapse(btn);

            % 4) Label Alpha-Slider
            lbl2 = matlab.ui.control.Label('Parent', gl, 'Text', 'Transparenz:', 'HorizontalAlignment', 'left');
            lbl2.Layout.Row = 4;

            % 5) Alpha-Slider
            row5 = uigridlayout(gl, [1,2]); row5.Layout.Row = 5;
            row5.ColumnWidth   = {'1x',50}; row5.ColumnSpacing = 10;
            row5.Padding       = [0,0,0,0];
            row5.RowSpacing    = 0;            obj.AlphaSlider = uislider(row5, 'Limits', [0 1], 'Enable', 'off');
            obj.AlphaSlider.Layout.Column = 1;
            obj.AlphaSlider.MajorTicks      = [0 1];
            obj.AlphaSlider.MajorTickLabels = {'0%','100%'};
            obj.AlphaSlider.ValueChangingFcn = @(s,e) obj.onAlphaChanged(e);
            spacer = matlab.ui.control.Label('Parent', row5, 'Text', '');
            spacer.Layout.Column = 2;

            % 6) DateLabel
            obj.DateLabel = matlab.ui.control.Label('Parent', gl, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            obj.DateLabel.Layout.Row = 6;
        end

        function initializeTimelapseSlider(obj,~,~)
            [imgs,dates] = obj.getActive();
            N = numel(imgs);
            obj.TimelapseSlider.Limits = [1 max(1,N)];
            obj.TimelapseSlider.Value  = 1;
            % Slider-Beschriftung
            if N>0
                obj.TimelapseSlider.MajorTicks = 1:N;
                obj.TimelapseSlider.MajorTickLabels = dates;
            else
                obj.TimelapseSlider.MajorTicks = [];
                obj.TimelapseSlider.MajorTickLabels = {};
            end

            obj.AlphaSlider.Enable = 'off'; obj.AlphaSlider.Value = 0;
            cla(obj.TimelapseAxes);
            if N>0
                % einmaliges Anlegen der beiden Image-Handles
                obj.CurrImgHandle = imshow(imgs{1}, 'Parent', obj.TimelapseAxes);
                obj.CurrImgHandle.AlphaData = 1;
                obj.NextImgHandle = imshow(imgs{1}, 'Parent', obj.TimelapseAxes);
                obj.NextImgHandle.AlphaData = 0;

                obj.App.CurrentImageIndex = 1;
                obj.DateLabel.Text = sprintf('Bild 1/%d: %s',N,dates{1});
            else
                obj.App.CurrentImageIndex = 0;
                obj.DateLabel.Text = 'Keine Bilder';
            end
            % --- Cache befüllen (für onTick) -----------------------------------
            obj.CacheImgs  = imgs;
            obj.CacheDates = dates;

        end

        function updateTimelapseDisplay(obj,idx)
            [imgs,dates] = obj.getActive();
            if isempty(imgs)
                cla(obj.TimelapseAxes); obj.DateLabel.Text = 'Keine Bilder'; return;
            end
            idx = max(1,min(idx,numel(imgs)));
            % bei manuellem Modus: Direkt anzeigen
            obj.CurrImgHandle.CData = imgs{idx};
            obj.CurrImgHandle.AlphaData = 1;
            obj.NextImgHandle.AlphaData = 0;
            obj.App.CurrentImageIndex = idx;
            obj.TimelapseSlider.Value = idx;
            if obj.IsPlaying
                obj.DateLabel.Text = sprintf('Bild %d/%d: %s',idx,numel(imgs),dates{idx});
            else
                nextIdx = idx+1; if nextIdx>numel(imgs), nextIdx=1; end
                obj.DateLabel.Text = sprintf('%s ⟷ %s',dates{idx},dates{nextIdx});
                % Next vorbereiten
                obj.prepareNextManual();
                obj.AlphaSlider.Enable='on';
            end
        end

        function onSliderSnapped(obj,e)
            obj.updateTimelapseDisplay(round(e.Value));
        end

        function onAlphaChanged(obj,e)
            a = e.Value;
            obj.NextImgHandle.AlphaData = a;
            obj.CurrImgHandle.AlphaData = 1;
            if ~obj.IsPlaying
                [~,dates] = obj.getActive();
                idx = obj.App.CurrentImageIndex;
                nextIdx = idx+1; if nextIdx>numel(dates), nextIdx=1; end
                obj.DateLabel.Text = sprintf('%s ⟷ %s',dates{idx},dates{nextIdx});
            end
        end

        % -----------------------------------------------------------------
        function toggleTimelapse(obj, btn)

            % ===== PAUSE =================================================
            if obj.IsPlaying
                if isvalid(obj.PlayTimer)
                    stop(obj.PlayTimer);
                end
                obj.IsPlaying          = false;
                btn.Text               = '▶';
                obj.AlphaSlider.Enable = 'on';
                obj.prepareNextManual;
                return;
            end

            % ===== PLAY ==================================================
            if isempty(obj.CacheImgs);  return; end      % nichts abzuspielen

            % ------- Timer notfalls neu anlegen --------------------------
            if isempty(obj.PlayTimer) || ~isvalid(obj.PlayTimer)
                obj.PlayTimer = timer( ...
                    'ExecutionMode','fixedRate', ...
                    'Period',       1/15, ...            % ≈ 15 fps
                    'BusyMode',     'drop', ...
                    'Tag',          'SCV_PlayTimer', ...
                    'TimerFcn',     @(~,~) obj.onTick() );
            end

            obj.StepIdx = 0;
            start(obj.PlayTimer);

            obj.IsPlaying          = true;
            btn.Text               = '⏸';
            obj.AlphaSlider.Enable = 'off';
            obj.AlphaSlider.Value  = 0;
        end
        % -----------------------------------------------------------------




        function onAdvance(obj)
            if ~obj.IsPlaying, return; end
            [~,dates] = obj.getActive();
            total = numel(dates);
            idx = obj.App.CurrentImageIndex + 1;
            if idx > total
                % erst Bild 1 einblenden, dann Pause, so dass Bild 1 genauso lange steht
                obj.blendTo(1);
                pause(obj.PauseAfterLoop);
                return;
            end
            obj.blendTo(idx);
        end

        function [imgs, dates] = getActive(obj)
            % Safely retrieve active images and dates based on SelectedMask
            allImgs = obj.App.getDisplayImages();
            allDates = obj.App.CurrentLocationDates;
            mask = obj.App.SelectedMask;
            % Align mask to available data
            nImgs = numel(allImgs);
            if numel(mask) > nImgs
                mask = mask(1:nImgs);
            elseif numel(mask) < nImgs
                mask = [mask(:); false(nImgs - numel(mask),1)];
            end
            % Use mask for dates (truncate if needed)
            nDates = numel(allDates);
            dateMask = mask(1:min(numel(mask), nDates));
            % Extract
            imgs = allImgs(mask);
            dates = allDates(dateMask);
        end

        function onTick(obj)
            if ~obj.IsPlaying || isempty(obj.CacheImgs); return; end

            % -------- 1) Alpha hochdrehen ----------------------------------------
            a = obj.StepIdx / obj.FrameSteps;             % 0 ... 1
            obj.NextImgHandle.AlphaData = a;
            obj.CurrImgHandle.AlphaData = 1;
            drawnow limitrate nocallbacks;

            obj.StepIdx = obj.StepIdx + 1;
            if obj.StepIdx <= obj.FrameSteps; return; end

            % -------- 2) Framewechsel fertig -------------------------------------
            obj.StepIdx = 0;                              %  für nächsten Frame
            idx = obj.App.CurrentImageIndex + 1;
            if idx > numel(obj.CacheImgs)
                idx = 1;                                  % Loop
                pause(obj.PauseAfterLoop);                % kurze Pause
            end

            % swap: Next ➜ Current
            obj.CurrImgHandle.CData = obj.NextImgHandle.CData;
            obj.NextImgHandle.AlphaData = 0;
            obj.CurrImgHandle.AlphaData = 1;

            % neuen Next vorbereiten
            nxt = idx + 1; if nxt > numel(obj.CacheImgs), nxt = 1; end
            obj.NextImgHandle.CData = obj.CacheImgs{nxt};

            % UI-State aktualisieren
            obj.App.CurrentImageIndex = idx;
            obj.TimelapseSlider.Value = idx;
            obj.DateLabel.Text = sprintf('Bild %d/%d: %s', idx, numel(obj.CacheImgs), obj.CacheDates{idx});
        end


        function blendTo(obj,tgt)
            [imgs,dates] = obj.getActive();
            % Next aktualisieren
            obj.NextImgHandle.CData      = imgs{tgt};
            obj.NextImgHandle.AlphaData  = 0;
            % sanftes Blending
            for a = linspace(0,1,4)
                if ~obj.IsPlaying, return; end
                obj.NextImgHandle.AlphaData = a;
                drawnow limitrate;
                pause(0.012);
            end
            % swap CData
            obj.CurrImgHandle.CData     = obj.NextImgHandle.CData;
            obj.CurrImgHandle.AlphaData = 1;
            obj.NextImgHandle.AlphaData = 0;
            % Index & Label updaten
            obj.App.CurrentImageIndex = tgt;
            obj.TimelapseSlider.Value = tgt;
            obj.DateLabel.Text = sprintf('Bild %d/%d: %s',tgt,numel(imgs),dates{tgt});
        end

        function prepareNextManual(obj)
            [imgs,~] = obj.getActive();
            if numel(imgs)<2, return; end
            nxt = obj.App.CurrentImageIndex + 1;
            if nxt > numel(imgs), nxt = 1; end
            obj.NextImgHandle.CData     = imgs{nxt};
            obj.NextImgHandle.AlphaData = 0;
            obj.AlphaSlider.Value       = 0;
        end

        function stopTimelapse(obj)
            % Sanft anhalten – von außen aufrufbar
            if obj.IsPlaying
                stop(obj.PlayTimer);
                obj.IsPlaying          = false;
                obj.PlayButton.Text    = '▶';
                obj.AlphaSlider.Enable = 'on';
                obj.prepareNextManual;
            end
        end

        function cleanup(obj)
            % Aufräumen vorm Schließen der App
            if isvalid(obj.PlayTimer)
                stop(obj.PlayTimer);
                delete(obj.PlayTimer);
            end
        end

    end
end
