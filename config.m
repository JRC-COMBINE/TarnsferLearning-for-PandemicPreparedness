function CONFIG = config
% CONFIG FILE
% Set all modifyable parameters here

%% TRAINING

% Zeitraum der Analyse
CONFIG.T = 35;

% Hospitals to use
CONFIG.use_hospitals = [1,2,3]; 

% Analysis of last days
CONFIG.T_lastDays = 3;

% Include PCA transformation based on organs
CONFIG.pca_transform = false;

% Number of GLMs in ensemble model
CONFIG.nGLMs = 10;

% Number of iterations to run model to get mean performance and confidence interval
CONFIG.nFolds = 5;
CONFIG.nFolds_crossval = 4;
CONFIG.nRounds_crossval = 5;

% Visualization
% set(groot, 'DefaultAxesTickLabelInterpreter', 'none')
CONFIG.plot_visibility = 'off';

% Seed for random number generator
rng(42);







end

