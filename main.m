% Starter-Skript für die GUI
delete(findall(0, 'Type', 'figure', 'Name', 'Satellite Change Visualization'));
addpath(genpath('src'));
addpath(genpath('resources/locations'));
addpath(genpath('resources/aligned_locations'));
addpath(genpath('resources/backgrounds'));


app = GUI();
