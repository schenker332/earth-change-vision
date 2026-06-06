function [rgbImages, dates, alignedMask, tforms] = runOverlapWorkflow(folderPath)
% RUNOVERLAPWORKFLOW  Wrapper ruft runAlignment auf und liefert die Maske mit zurück.


[rgbImages, dates, alignedMask, tforms] = runAlignment(folderPath);
end
