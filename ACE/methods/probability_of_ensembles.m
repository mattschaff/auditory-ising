function output_master = probability_of_ensembles(data_path, j_file_path, mc_algorithm_path, output_dir, bird, test_logical_path, strict, ensembles)
    % Function: probability_of_ensembles - calculates probability of
    % ensembles between experimental binary data and simulated binary data based on
    % Ising models, with parameters in .j file
    
        %variables 
            % timestamp
                time = datestr(now,'HH_MM_SS.FFF');
                if (exist('bird', 'var') == 0)
                   bird = true;
                end
                if (exist('strict', 'var') == 0)
                   strict = false;
                end
                if (exist('ensembles', 'var') == 0)
                   ensembles = 3;
                end
        % directories
            % create output directories for MC algorithm
            if (exist([mc_algorithm_path '/output'], 'dir') == 0)
                mkdir([mc_algorithm_path '/output']);
            end
            if (exist([mc_algorithm_path '/j_files'], 'dir') == 0)
                mkdir([mc_algorithm_path '/j_files']);
            end
            % mc_jfiles
            mc_j_files = [mc_algorithm_path '/j_files/' time];
            if (exist(mc_j_files, 'dir') == 0)
                mkdir(mc_j_files);
            end
            % mc_output
            mc_output = [mc_algorithm_path '/output/' time];
            if (exist(mc_output, 'dir') == 0)
                mkdir(mc_output);
            end
            if (exist([mc_output '/indep'], 'dir') == 0)
                mkdir([mc_output '/indep']);
            end
            if (exist([mc_output '/pairwise'], 'dir') == 0)
                mkdir([mc_output '/pairwise']);
            end
            if (exist(output_dir, 'dir') == 0)
                mkdir(output_dir);
            end
    % copy & paste the pairwise .j file
        copyfile(j_file_path, mc_j_files);
        [~, j_name,~] = fileparts(j_file_path);
        new_pairwise_j_path = [mc_j_files filesep j_name '.j'];
    % independent model -- get indep model .j file of elements
        if (bird)
            data = importdata(data_path);
        else
            data = load(data_path);
            data = cell2mat(data.neuron_trains);
            data = data';
            data(data > 0) = 1;
        end
        data(data > 1) = 1;
        data(data < 1) = 0;
        % now handle test_logical
        if exist('test_logical_path', 'var') == 1
            load(test_logical_path);
            train_data = data(~test_logical,:);
            h_i =log(mean(train_data)./(1-mean(train_data)));
            data = data(test_logical,:);
        else
            h_i =log(mean(data)./(1-mean(data)));
        end 
        h_i = h_i';
        fid = fopen([mc_j_files filesep 'indep.j'], 'wt');
        fprintf(fid,'%1g\n',h_i);
        N = numel(h_i);
        num_j = (N*(N-1))/2;
        J_ij = zeros([num_j 1]);
        fprintf(fid,'%1g\n',J_ij);
        fclose(fid);
    % run MC algorithm
        current_path = pwd;
        cd(mc_algorithm_path);
        disp('Running MC algorithm to generate simulated data on independent model');
        system(['./qee.out -i j_files/' time '/indep -o output/' time '/indep/indep-output -p2']);
        disp('Running MC algorithm to generate simulated data on pairwise model');
        system(['./qee.out -i j_files/' time '/' j_name ' -o output/' time '/pairwise/pairwise-output -p2']);
        cd(current_path);
    % load data
        disp('Loading simulated data.');
        sim_data_indep = importdata([mc_output '/indep/indep-output--1.dat']);
        sim_data_pairwise = importdata([mc_output '/pairwise/pairwise-output--1.dat']);
        disp('Data loaded.');
    % invert numbers
        sim_data_pairwise = sim_data_pairwise*-1+1;
        sim_data_indep = sim_data_indep*-1+1;
        
    % loop through ensembles
        output_master = [];
        for e=1:numel(ensembles)
        
        % get possible ensemble patterns
            num_elements = size(data,2);
            ensemble_patterns = nchoosek(1:num_elements,ensembles(e));
            num_patterns = size(ensemble_patterns,1);
            ensemble_patterns_binary = zeros([num_patterns num_elements]);
            for i=1:num_patterns
                ensemble_patterns_binary(i,ensemble_patterns(i,:)) = 1;
            end
        % measure frequencies over ensemble patterns

            % bird data
                disp(['Counting ensembles of ' num2str(ensembles(e)) ' over experimental data']);
                freq_data = count_ensemble_freq(data, ensemble_patterns_binary, num_patterns, ensembles(e));
                if (strict); freq_data_strict = count_ensemble_freq_strict(data, ensemble_patterns_binary, num_patterns, ensembles(e)); end

            % stimulatd data for independent model
                disp(['Counting ensembles of ' num2str(ensembles(e)) ' over data simulated from independent model']);
                freq_indep = count_ensemble_freq(sim_data_indep, ensemble_patterns_binary, num_patterns, ensembles(e));
                if (strict); freq_indep_strict = count_ensemble_freq_strict(sim_data_indep, ensemble_patterns_binary, num_patterns, ensembles(e)); end

            % matt simulated data
                disp(['Counting ensembles of ' num2str(ensembles(e)) ' over data simulated from pairwise model']);
                freq_pairwise = count_ensemble_freq(sim_data_pairwise, ensemble_patterns_binary, num_patterns, ensembles(e));
                if (strict); freq_pairwise_strict = count_ensemble_freq_strict(sim_data_pairwise, ensemble_patterns_binary, num_patterns, ensembles(e)); end

            % save output
                output = struct;
                output.size = ensembles(e);
                output.freq_data = freq_data;
                output.freq_indep = freq_indep;
                output.freq_pairwise = freq_pairwise;
                if (strict) 
                    output.freq_data_strict = freq_data_strict;
                    output.freq_indep_strict = freq_indep_strict;
                    output.freq_pairwise_strict = freq_pairwise_strict;
                end
                output_master = [output_master; output];
                save([output_dir filesep 'ensemble_frequencies.mat'], 'output_master');
            % create ensemble_output_dir
                ensemble_output_dir = [output_dir filesep 'ensemble_' num2str(ensembles(e))];
                if (exist(ensemble_output_dir, 'dir') == 0)
                    mkdir(ensemble_output_dir);
                end
            % plot ensemble
                figure();
                l2 = loglog(freq_data, freq_pairwise, '.r', 'MarkerSize', 15);
                hold on;
                l1 = loglog(freq_data, freq_indep, '.c', 'MarkerSize', 15);
                set(gca, 'FontSize', 14);
                title(['Ensemble Frequencies - ' ensembles(e)]);
                xlabel('Observed Frequencies');
                ylabel('Predicted Frequencies');
                x1 = xlim;
                lin = linspace(x1(1), x1(2), 100);
                plot(lin, lin, 'k', 'Linewidth', .75);
                legend([l1 l2], 'Independent', 'Pairwise', 'Location', 'SouthEast');
                hold off;
                print([ensemble_output_dir filesep 'ensemble_frequencies_' num2str(ensembles(e))], '-dpng');
                if (strict)
                    figure();
                    l2 = loglog(freq_data_strict, freq_pairwise_strict, '.r', 'MarkerSize', 15);
                    hold on;
                    l1 = loglog(freq_data_strict, freq_indep_strict, '.c', 'MarkerSize', 15);
                    set(gca, 'FontSize', 14);
                    title(['Ensemble Frequencies Strict - ' ensembles(e)]);
                    xlabel('Observed Frequencies');
                    ylabel('Predicted Frequencies');
                    x1 = xlim;
                    lin = linspace(x1(1), x1(2), 100);
                    plot(lin, lin, 'k', 'Linewidth', .75);
                    legend([l1 l2], 'Independent', 'Pairwise', 'Location', 'SouthEast');
                    hold off;
                    print([ensemble_output_dir filesep 'ensemble_frequencies_strict_' num2str(ensembles(e))], '-dpng');
                end
                close all;
        end
     % move mc output & j files
        rmdir(mc_output, 's');
        movefile(mc_j_files, [output_dir filesep 'j_files']);
end