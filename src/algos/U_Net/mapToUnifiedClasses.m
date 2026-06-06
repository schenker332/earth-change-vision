function mapped = mapToUnifiedClasses(classMap)
    % Konvertiere Eingabe in Strings für Vergleich
    inStr = string(classMap);
    [rows, cols] = size(inStr);
    mapped = strings(rows, cols);

    % Mapping der ursprünglichen Klassen zu vereinfachten Oberkategorien
    for y = 1:rows
        for x = 1:cols
            val = inStr(y,x);
            switch val
                case "water"
                    mapped(y,x) = "Wasser";
                case {"tree", "rangeland"}
                    mapped(y,x) = "Vegetation";
                case "building"
                    mapped(y,x) = "Gebäude";
                case {"developed", "road"}
                    mapped(y,x) = "Bebaute Fläche";
                case {"bareland", "agriculture"}
                    mapped(y,x) = "Offenland";
                otherwise
                    mapped(y,x) = "";  % Nicht klassifiziert
            end
        end
    end

    % Final als kategorisches Array zurückgeben mit fester Reihenfolge
    mapped = categorical(mapped, ...
        {'Wasser', 'Vegetation', 'Gebäude', 'Bebaute Fläche', 'Offenland'});
end