clear; clc;

%% Community detection for the cortical deviation covariance matrix
root_dir = '/Users/miaolab/Desktop/dengchijun/topics/asd-mri-subtype';
modeldir = [root_dir, '/results/res02-subtype/rho'];
savedir = [root_dir, '/results/res02-subtype/community'];
mkdir(savedir);

%% Load deviation covariance matrices
corr_area = readNPY([modeldir, '/SA.npy']);
corr_thickness = readNPY([modeldir, '/CT.npy']);

%% Matrix transformation
corr_area(logical(eye(size(corr_area)))) = 0;
corr_thickness(logical(eye(size(corr_thickness)))) = 0;

corr_area(corr_area < 0) = 0;
corr_thickness(corr_thickness < 0) = 0;

% Fisher-Z transform
corr_area = atanh(corr_area);
corr_thickness = atanh(corr_thickness);

%% Wrap matrices into cell array
A = {corr_area, corr_thickness};
[N, ~] = size(corr_area);
T = length(A);
gamma = 1;
omega = 1;
iters = 1000;

%% Initialize result
S_iter = zeros(iters, N, T);
Q_iter = zeros(iters, 1);

%% Start parallel pool
poolobj = gcp('nocreate');
if isempty(poolobj)
    parpool(8); 
end

%% Community detection (parallel)
parfor i = 1 : iters
    % local copy
    A_local = A;
    
    [B, twom] = multicat(A_local, gamma, omega);
    [S, Q] = iterated_genlouvain(B);
    Q = Q / twom;
    S = reshape(S, N, T);
    S = postprocess_categorical_multilayer(S, T);
    
    % Store values
    S_iter(i,:,:) = S;
    Q_iter(i) = Q;
    
    fprintf('Iteration %d completed\n', i);
end

%% Save results
writeNPY(S_iter, fullfile(savedir, 'S_iter.npy'));
writeNPY(Q_iter, fullfile(savedir, 'Q_iter.npy'));

