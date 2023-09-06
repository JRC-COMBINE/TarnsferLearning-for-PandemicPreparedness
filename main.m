% Get configuration parameters
CONFIG = config;

T = CONFIG.T;

% prepare_data(CONFIG)
% pause(.5)
% clc

load data meta_basis meta_covid prepared_data_basis prepared_data_covid mean_lastDays_basis comorbs_basis
des_basis = meta_basis.Expire_flag;
des_covid = meta_covid.Expire_flag;
los_basis = meta_basis.ICUlengthOfStay;
los_covid = meta_covid.ICUlengthOfStay;
clear meta_basis meta_covid

inorm = des_basis==0;
% inorm = sum(comorbs_basis{:,:}, 2)==0;
map = mapper(mean_lastDays_basis, des_basis, inorm);
xTr = map.map_timeSeriesData(prepared_data_basis, los_basis);
xTe = map.map_timeSeriesData(prepared_data_covid, los_covid);
for t=2:T
    flag = los_basis>=t;
    xTr(t,~flag,:) = xTr(t-1,~flag,:);
end
clear mean_lastDays_basis t flag inorm


%% CROSSVALIDATION
[pred_cv_basis, pred_cv_covid, B_basis, B_covid, auc_cv_basis,auc_cv_covid, auprc_cv_basis, auprc_cv_covid] = ...
    mycrossval(xTr, des_basis, xTe, des_covid, los_covid, CONFIG);
save 'ans.mat' 'pred_cv_basis' 'pred_cv_covid' 'B_basis' 'B_covid' 'auc_cv_basis' 'auc_cv_covid' 'auprc_cv_basis' 'auprc_cv_covid'


