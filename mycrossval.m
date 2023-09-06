function [pred_cv_basis, pred_cv_covid, B_basis, B_covid, auc_cv_basis,auc_cv_covid, auprc_cv_basis, auprc_cv_covid] ...
    = mycrossval(xTr_basis, des_basis, xTe_basisTr, des_covid, los_covid, CONFIG)

T = CONFIG.T;
nwks = ceil(T/7);

load data mean_lastDays_covid prepared_data_covid comorbs_covid

nRuns = CONFIG.nRounds_crossval * CONFIG.nFolds_crossval;
auc_cv_basis = zeros(nRuns,T);
auc_cv_covid = zeros(nRuns,T);
auprc_cv_basis = zeros(nRuns,T);
auprc_cv_covid = zeros(nRuns,T);
ncovid = length(des_covid);
pred_cv_basis = NaN(nRuns, T, ncovid);
pred_cv_covid = NaN(nRuns, T, ncovid);

m_basis = size(xTr_basis,3);
m_covid = size(prepared_data_covid, 3);
B_basis = NaN(nRuns, nwks, m_basis+1);
B_covid = NaN(nRuns, nwks, m_covid+1);

for r=1:CONFIG.nRounds_crossval
    cvp_basis = cvpartition(des_basis,'KFold',CONFIG.nFolds_crossval);
    cvp_covid = cvpartition(des_covid,'KFold',CONFIG.nFolds_crossval);
    for k=1:CONFIG.nFolds_crossval

        iRun = (r-1)*CONFIG.nFolds_crossval + k;
        disp(iRun)

        iTr_basis = training(cvp_basis, k);
        iTr_covid = training(cvp_covid, k);
        iTe = test(cvp_covid, k);

        % 
        inorm = sum(comorbs_covid{iTr_covid,:}, 2)==1;
        map_covid = mapper(mean_lastDays_covid(iTr_covid,:), des_covid(iTr_covid), des_covid(iTr_covid)==0);
        x_covid = map_covid.map_timeSeriesData(prepared_data_covid, los_covid);
        xTr_covid = x_covid(:,iTr_covid,:);
        xTe_covidTr = x_covid(:,iTe,:);
        for t=2:T
            flag = los_covid(iTr_covid)>=t;
            xTr_covid(t,~flag,:) = xTr_covid(t-1,~flag,:);
        end

        % FIT MODEL & PREDICT
        mdl_basis = model();
        mdl_basis = mdl_basis.fit(xTr_basis(:,iTr_basis,:), des_basis(iTr_basis), CONFIG.nFolds, CONFIG.nGLMs);
        B_basis(iRun,:,:) = mdl_basis.B;
        pred_basis = mdl_basis.predictions_over_time(xTe_basisTr(:,iTe,:));
        mdl_covid = model();
        mdl_covid = mdl_covid.fit(xTr_covid, des_covid(iTr_covid), CONFIG.nFolds, CONFIG.nGLMs);
        B_covid(iRun,:,[1;map_covid.ivars+1]) = mdl_covid.B;
        pred_covid = mdl_covid.predictions_over_time(xTe_covidTr);

        % CHECK PERFORMANCE
        auc_basis = zeros(1,T);
        auc_covid = zeros(1,T);
        auprc_basis = zeros(1,T);
        auprc_covid = zeros(1,T);
        for t=1:T
            [~,~,~,auc_basis(t)]      = perfcurve(des_covid(iTe),pred_basis(t,:),'1');
            [~,~,~,auc_covid(t)]      = perfcurve(des_covid(iTe),pred_covid(t,:),'1');
            [~,~,~,auprc_basis(t)]    = perfcurve(des_covid(iTe),pred_basis(t,:), '1', 'XCrit', 'reca', 'YCrit', 'prec');
            [~,~,~,auprc_covid(t)]    = perfcurve(des_covid(iTe),pred_covid(t,:), '1', 'XCrit', 'reca', 'YCrit', 'prec');
        end
        auc_cv_basis(iRun,:) = auc_basis;
        auc_cv_covid(iRun,:) = auc_covid;
        auprc_cv_basis(iRun,:) = auprc_basis;
        auprc_cv_covid(iRun,:) = auprc_covid;
        pred_cv_basis(iRun,:,iTe) = pred_basis;
        pred_cv_covid(iRun,:,iTe) = pred_covid;
    end
end

end

