% function visualizeEntropySurface(entropyMap)

% % Zeigt Entropieänderung als 3D-Oberfläche mit Jet-Colormap
% %
% % Eingabe:
% %   entropyMap - 2D-Matrix (Entropieänderungen, normalisiert [0,1])

%     % Normieren
%     entropyMap = mat2gray(entropyMap);

%     % Gitter für Oberfläche erzeugen
%     [X, Y] = meshgrid(1:size(entropyMap,2), 1:size(entropyMap,1));

%     figure;
%     surf(X, Y, entropyMap, 'EdgeColor', 'none');
%     colormap(jet); colorbar;
%     view(3);  % 3D-Ansicht
%     title('3D-Oberfläche der Entropieänderung');
%     xlabel('X'); ylabel('Y'); zlabel('Entropie');
% end

function visualizeEntropySurface(entropyMap, ax)
% Entropie normalisieren
entropyMap = mat2gray(entropyMap);
% Gitter erstellen
[X,Y] = meshgrid(1:size(entropyMap,2), 1:size(entropyMap,1));

% Zeichenziel einstellen
if nargin<2 || isempty(ax)
    ax = gca;
end
cla(ax, 'reset');        % alles löschen und Achse zurücksetzen
surf(ax, X, Y, entropyMap, 'EdgeColor','none');
colormap(ax, 'jet');
colorbar(ax);
view(ax, 3);             % 3D-Perspektive nur hier
axis(ax, 'off');
end
