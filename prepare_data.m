function [] = prepare_data(CONFIG)

%% GET DATA
data = readtable('../DATA_init/biometric_data_verynew.xlsx');

% Binning of age and BMI
data.BMI_bin = data.BMI>30;
data.age_bin = data.age>70;

% Hospital features categorizing hospital the patient comes from
data.hospital(data.encounterid<1e5) = 1;
data.hospital((data.encounterid>=1e5) & (data.encounterid<7e5)) = 2;
data.hospital((data.encounterid>=7e5) & (data.encounterid<9e5)) = 3;
data.hospital(data.encounterid>=9e5) = 4;

%% ONLY CONSIDER PATIENTS FROM CERTAIN HOSPITALS AND WITH LOS >= 1 day

iobs = false(size(data,1),1);
for h=CONFIG.use_hospitals
    iobs = iobs | (data.hospital==h);
end

iobs = iobs & (data.ICUlengthOfStay>=1);
data = data(iobs,:);


%% CREATE DATAFRAMES
% Split data into non-covid (transfer from) and covid (transfer to) patients 
data_0 = data(data.Covid==0,:);
data_1 = data(data.Covid==1,:);

% Comorbidities of interest 
comorb_feat_cols=[33,13:15,18,19,20,21,23,24,26,29,27,28,29,30,34,35]; % Comorbidities of interest
comorbs_basis = data_0(:,comorb_feat_cols);
comorbs_covid = data_1(:,comorb_feat_cols);
% Always consider the worst ARDS case
comorbs_basis.ARDS_moderate(comorbs_basis.ARDS_severe==1) = 0;
comorbs_basis.ARDS_mild(comorbs_basis.ARDS_severe==1) = 0;
comorbs_basis.ARDS_mild(comorbs_basis.ARDS_moderate==1) = 0;
comorbs_covid.ARDS_moderate(comorbs_covid.ARDS_severe==1) = 0;
comorbs_covid.ARDS_mild(comorbs_covid.ARDS_severe==1) = 0;
comorbs_covid.ARDS_mild(comorbs_covid.ARDS_moderate==1) = 0;

% Meta data
meta_basis = data_0(:,[1:12, 20,36]);
meta_covid = data_1(:,[1:12, 20,36]);


%%

tbl = readtable('../DATA_init/covid_stats_whole_stay_chosen_cols.csv');
tbl(:,1) = []; % Remove encounterid
tbl = tbl(iobs,:);


%%
% CLEAN FEATURE NAMES
tbl = renamevars(tbl, ["x24h_Bilanz__Fluessigkeiten_Einfuhr_vs__Ausfuhr__median", "individuelles_Tidalvolumen_pro_kg_idealem_Koerpergewicht_median"], ...
    ["Fluessigkeitsbilanz", "Tidalvolumen"]);
feats = tbl.Properties.VariableNames;
for i=1:length(feats)
    name = erase(feats{i}, '_median');
    if contains(name,'__ohne_Temp_Korrektur_')
        name = erase(name,'__ohne_Temp_Korrektur_');
    end
    feats{i} = name;
end
tbl.Properties.VariableNames = feats;
feats = string(feats);

orgsysfeats = table('Size', [numel(feats) 7], ...
    'VariableTypes', repmat("logical",1,7),...
    'VariableNames', ["lung", "inflam", "kidney", "heart", "liver", "meta", "body"]);
% orgsysfeats = false;

[~,ilung]   = intersect(feats, ["FiO2", "AF", "SaO2", "SpO2", "paCO2", "Horowitz_Quotient" ,"P_EI", "PEEP", "Vt", "MP", "paO2"]);
[~,iinflam] = intersect(feats, ["Leukozyten", "CRP", "PCT", "Koerperkerntemperatur"]);
[~,ikidney] = intersect(feats, ["Kreatinin", "Harnstoff"]);
[~,iheart]  = intersect(feats, ["HF", "Bicarbonat_arteriell", "pH_arteriell", "Albumin"]);
[~,iliver]  = intersect(feats, ["GOT", "INR", "Albumin"]);
[~,imeta]   = intersect(feats, ["Laktat_arteriell", "Bicarbonat_arteriell", "BE_arteriell", "pH_arteriell"]);
[~,ibody]   = intersect(feats, ["Haematokrit", "Thrombozyten", "SAP", "MAP", "DAP", "INR", "Fluessigkeitsbilanz", "Haemoglobin"]);
orgsysfeats.lung(ilung) = true;
orgsysfeats.inflam(iinflam) = true;
orgsysfeats.kidney(ikidney) = true;
orgsysfeats.heart(iheart) = true;
orgsysfeats.liver(iliver) = true;
orgsysfeats.meta(imeta) = true;
orgsysfeats.body(ibody) = true;

m = numel(feats);

%%
median_wholeStay_basis = tbl(data.Covid==0,:); 
median_wholeStay_basis = table2array(median_wholeStay_basis);
median_wholeStay_covid = tbl(data.Covid==1,:); 
median_wholeStay_covid = table2array(median_wholeStay_covid);

nbasis = size(median_wholeStay_basis, 1);
ncovid = size(median_wholeStay_covid, 1);

%%
x_0 = zeros(CONFIG.T_lastDays, nbasis, m);
x_1 = zeros(CONFIG.T_lastDays, ncovid, m);
for t=1:CONFIG.T_lastDays
    % Get median daily data
    x_t = readmatrix('../DATA_init/prepared_dataframe_for_analysis_last_days/prepared_dataframe_for_analysis_last_day_'+string(t)+'.csv');
    x_t = x_t(iobs,:);
    x_0_t = x_t(data.Covid==0,:);
    x_0_t(:,1) = [];
    x_0(t,:,:) = x_0_t;
    x_1_t = x_t(data.Covid==1,:);
    x_1_t(:,1) = [];
    x_1(t,:,:) = x_1_t;
end
mean_lastDays_basis = squeeze(mean(x_0, "omitnan"));
mean_lastDays_covid = squeeze(mean(x_1, "omitnan"));

%%
prepared_data_basis = NaN(CONFIG.T,size(meta_basis,1),length(feats));
prepared_data_covid = NaN(CONFIG.T,size(meta_covid,1),length(feats));
for t=1:CONFIG.T
    % Get median daily data
    x_t = readmatrix('../DATA_init/prepared_dataframe_for_analysis_days/prepared_dataframe_for_analysis_day_'+string(t)+'.csv');
    x_t = x_t(iobs,:);
    x_0_t = x_t(data.Covid==0,:);
    x_1_t = x_t(data.Covid==1,:);
    % Remove encouterid column
    x_1_t(:,1) = [];
    x_0_t(:,1) = [];
    prepared_data_basis(t,:,:) = x_0_t;
    prepared_data_covid(t,:,:) = x_1_t;
end
%% Momentum data, i.e. 3-day difference
prepared_data_mom_basis = NaN(CONFIG.T,size(meta_basis,1),length(feats));
prepared_data_mom_covid = NaN(CONFIG.T,size(meta_covid,1),length(feats));
for t=4:CONFIG.T
    x_mom_0_t = squeeze(prepared_data_basis(t,:,:)) - squeeze(prepared_data_basis(t-3,:,:));
    x_mom_1_t = squeeze(prepared_data_covid(t,:,:)) - squeeze(prepared_data_covid(t-3,:,:));
    prepared_data_mom_basis(t,:,:) = x_mom_0_t;
    prepared_data_mom_covid(t,:,:) = x_mom_1_t;
end


save data.mat ...
    comorbs_basis comorbs_covid ... 
    meta_basis meta_covid ... 
    feats orgsysfeats ...
    median_wholeStay_basis median_wholeStay_covid ...
    mean_lastDays_basis mean_lastDays_covid ...
    prepared_data_basis prepared_data_covid ...
    prepared_data_mom_basis prepared_data_mom_covid ...
    
    
    
end

