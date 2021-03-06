function [h0, J, mean_sigma, mean_experiment, mean_product, mean_experiment_product, test_logical,...
    train_experiment_product, train_product, train_logical] = estimate_ising_v2(iters, file)
    
    % load data 
    load([file filesep 'neuron_trains.mat']);
    neuron_trains = cell2mat(neuron_trains);
    [N, T] = size(neuron_trains);
    % Proportion used for training data
    p_train = 0.8;
    train_logical = false(T, 1);
    train_logical(1:round(p_train*T)) = true;
    % extract a random sample representing this proportion
    train_logical = train_logical(randperm(T));
    test_logical = ~train_logical;
    % split into train and test data 
    neuron_trains_test = neuron_trains(:,test_logical);
    neuron_trains = neuron_trains(:,train_logical);
    
    %compute the average of the products of all pairs - oi * oj
    mean_experiment = transpose(mean(neuron_trains,2));
    mean_experiment_product = neuron_trains*transpose(neuron_trains)/size(neuron_trains,2);
    
    % h0 = unifrnd(-1, 1, 1, N);
    % neuron_trains2 = (neuron_trains+1)/2;
    % h0 = log(mean(neuron_trains2, 2)./(1-mean(neuron_trains2, 2)))*0.5;
    h0 = transpose(atanh(mean_experiment));  % exact solution to independent ising model
    h0 = transpose(h0);
    J = unifrnd(-0.1, 0.1, N, N);  
    % J = zeros(N, N);
    maxdiff = 1;
    eta = 0.1;
    alpha = 0;
    prev_change_h0 = zeros(1, N);
    prev_change_J = zeros(N, N);
    itercount = 0;
    
    % Measure deviations from experiment
    sigma_diff = zeros(1,iters);
    corr_diff = zeros(1,iters);
    
    % Gradient Ascent
    sample_size = 10000;
    sigm0 = zeros(sample_size, N);
    for i=1:sample_size
        sigm0(i,:) = 2*(randi(2, 1, N)-1)-1;
    end
    best_diff = 1;
    best_h0 = h0;
    best_J = J;
    while itercount < iters
        
        tic;
        % eta = eta/itercount;
        itercount = itercount+1;
        disp([itercount maxdiff]);
        maxdiff = 0;
        
        % Sample Ising Estimations
        % [sigm, states] = sample_ising(sample_size, h0, J);
        % [sigm, states] = sample_ising_exact(h0, J);
        % [sigm, states] = sw_sample_ising(h0, J, sample_size, sigm0);
        % if mod(itercount, 2) == 1
        
        [sigm, states] = mh_sample_ising(1, sample_size, h0, J, 10, sigm0);
        sigm0 = sigm;
        % end
        % [sigm, states] = gibbs_sample_ising(sample_size, h0, J, 100);
        weighted_states = sigm.*repmat(transpose(states), 1, size(sigm, 2));
        toc
        
        % tic;
        % Update h0 
        mean_sigma = sum(weighted_states);
        diff = eta*(mean_experiment-mean_sigma) + alpha*prev_change_h0;
        prev_change_h0 = diff;
        h0 = h0 + diff;
        sigma_diff(itercount) = mean(abs(mean_experiment-mean_sigma));
        % toc
        
        % tic;
        % Update Jij
        mean_product = transpose(sigm)*weighted_states;
        diff = 0.5*eta*(mean_experiment_product-mean_product)+alpha*prev_change_J;
        diff(logical(eye(size(diff)))) = 0;
        maxdiff = max(max(max(maxdiff, abs(diff))));
        prev_change_J = diff;
        J = J + diff;
        corr_diff(itercount) = sum(sum(abs(mean_experiment_product-mean_product)))/(N^2);
        if maxdiff < best_diff
            best_diff = maxdiff;
            best_h0 = h0;
            best_J =J;
        end
        toc
    end

    J = best_J;
    h0 = best_h0;

    % Plot deviation from experiment over time
    figure(3);
    subplot(2,1,1);
    plot(1:itercount, sigma_diff(1:itercount), 'LineWidth', 1.5);
    title('Deviation of Mean Firing Rate');
    set(gca, 'FontSize', 14);
    subplot(2,1,2);
    plot(1:itercount, corr_diff(1:itercount), 'LineWidth', 1.5);
    xlabel('# of Iterations');
    title('Deviation of Mean Correlation');
    set(gca, 'FontSize', 14);
    print([file filesep 'convergence'], '-dpng'); % save to file

    % ON TRAINING DATA 
    % Mean responses
    mrs = mean_sigma;
    mers = mean_experiment;
    % Mean products
    num_entries = N*(N-1)/2;
    meps = zeros(1,num_entries);
    mps = zeros(1,num_entries);
    k = 1;
    for i = 1:N
        for j = i+1:N
            % computing covariance 
            meps(k) = mean_experiment_product(i,j) - mean_experiment(i)*mean_experiment(j);
            mps(k) = mean_product(i,j) - mean_sigma(i)*mean_sigma(j);
            k = k+1;
        end
    end
    
    train_experiment_product = mean_experiment_product;
    train_product = mean_experiment_product;
    
    % Plot predicted vs. empirical values TRAIN DATA (sanity check) 
    figure(1);
    hold on;
    xlabel('Mean Experimental Response');
    ylabel('Mean Predicted Response');
    lin = linspace(min(min(mers),min(mrs)),max(max(mers),max(mrs)),101);
    plot(lin, lin, 'k', 'LineWidth', 1.5);
    rtr = plot(mers, mrs, '*b', 'MarkerSize', 10);
    set(gca, 'FontSize', 14);
    figure(2);
    hold on;
    xlabel('Mean Experimental Correlation');
    ylabel('Mean Predicted Correlation');
    lin = linspace(min(min(meps),min(mps)),max(max(meps),max(mps)),101);
    plot(lin, lin, 'k', 'LineWidth', 1.5);
    ctr = plot(meps, mps, '*b', 'MarkerSize', 10);
    set(gca, 'FontSize', 14);
     
    % ON TESTING DATA SET
    mean_experiment = transpose(mean(neuron_trains_test,2));
    mean_experiment_product = neuron_trains_test*transpose(neuron_trains_test)/size(neuron_trains_test,2);    
    
    % Mean responses
    mrs = mean_sigma;
    mers = mean_experiment;
    % Mean products
    num_entries = N*(N-1)/2;
    meps = zeros(1,num_entries);
    mps = zeros(1,num_entries);
    k = 1;
    for i = 1:N
        for j = i+1:N
            meps(k) = mean_experiment_product(i,j) - mean_experiment(i)*mean_experiment(j); 
            mps(k) = mean_product(i,j) - mean_sigma(i)*mean_sigma(j); %definition of covariance
            k = k+1;
        end
    end
    
    % Plot predicted vs. empirical values
    figure(1);
    hold on;
    xlabel('Mean Experimental Response');
    ylabel('Mean Predicted Response');
    title('Predicted vs. Empirical Mean Response');
    rt = plot(mers, mrs, 'sr', 'MarkerSize', 10);
    set(gca, 'FontSize', 14);
    legend([rtr, rt], {'Training', 'Test'}, 'Location', 'Southeast');
    print([file filesep 'firing_rates'], '-dpng'); % save to file
    figure(2);
    hold on;
    xlabel('Mean Experimental Correlation');
    ylabel('Mean Predicted Correlation');
    title('Predicted vs. Empirical Mean Correlation');
    ct = plot(meps, mps, 'sr', 'MarkerSize', 10);
    set(gca, 'FontSize', 14);
    legend([ctr, ct], {'Training', 'Test'}, 'Location', 'Southeast');
    print([file filesep 'correlations'], '-dpng'); % save to file
    
end