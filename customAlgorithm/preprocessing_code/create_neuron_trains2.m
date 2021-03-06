% This file indiscriminately concatenates all trials for a single neuron.
% The result is a 16-cell array with only 1 concatenated train for each
% neuron. The trials for each neuron are sorted by increasing TNR
% intensity. In particular, for any neuron, there is 1 spike train, where
% the earliest times are from trials with TNR intensity 0 and the latest
% times are from trials with TNR intensity 85 (which is the highest intensity).

% Load sorted trains
sorted_trains = load('sorted_trains.mat');
sorted_trains = sorted_trains.sorted_trains;

num_neurons = size(sorted_trains, 1);
num_tnrs = size(sorted_trains, 2);

% Preallocate a 16-cell array with 1 train for each neuron
neuron_trains = cell(num_neurons,1);

% For each neuron...
for i = 1:num_neurons
    % Create empty vector for concatenated train
    A = [];
    % For each TNR intensity...
    for j = 1:num_tnrs
        % Concatenate the train associated with that intensity
        A = [A sorted_trains{i,j}];
    end
    neuron_trains{i,1} = A;
    % Print i
    i
end

save('neuron_trains.mat', 'neuron_trains');