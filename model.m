classdef model

    properties
        B
    end

    methods
        function obj = model()
            obj.B = NaN;
        end

        function obj = fit(obj, x, des, nFolds, nGLMs)

            nwks = ceil(size(x,1)/7);
            m = size(x,3);

            cvp = cvpartition(des,'KFold',nFolds);
            BFolds = NaN(nFolds, nwks, m+1);
            for k=1:nFolds

                iTr = training(cvp, k);

                xTr     = x(:,iTr,:);
                desTr   = des(iTr);

                % PRETRAIN
                BFolds(k,:,:) = obj.fit_GLMEnsemble(nGLMs, xTr, desTr);

            end
            obj.B = squeeze(mean(BFolds, 1, "omitnan"));
        end


        function b = fit_GLMEnsemble(obj, nGLMs, x, des)
            T = size(x, 1);
            n = size(x,2);
            m = size(x,3);

            b_t = zeros(T, m+1);
            for t=1:T
                b = zeros(nGLMs, m+1);
                for k=1:nGLMs
                    c = cvpartition(n,'Holdout',0.8);
                    i_k = c.test;
                    x_t = squeeze(x(t,i_k,:));

                    b(k,:) = glmfit(x_t,des(i_k),'binomial');
                    b_t(t,:) = mean(b);
                end
            end

            nwks = ceil(T/7);
            b = zeros(nwks, m+1);
            for w=1:nwks
                tend = w * 7;
                tstart = tend - 6;
                b(w,:) = mean(b_t(tstart:tend,:));
            end
        end


        function pred = predictions_over_time(obj, x)
            T = size(x, 1);
            n = size(x,2);

            pred = NaN(T,n);
            for t=1:T
                w = ceil(t/7);
                x_t = squeeze(x(t,:,:));
                pred(t,:) = glmval(obj.B(w,:)',x_t,'logit');
            end
        end


        function [auc, auprc] = performance(obj, pred, des)
            T = size(pred, 1);
            auc = zeros(1,T);
            auprc = zeros(1,T);
            for t=1:T
                [~,~,~,auc(t)]      = perfcurve(des,pred(t,:),'1');
                [~,~,~,auprc(t)]    = perfcurve(des,pred(t,:), '1', 'XCrit', 'reca', 'YCrit', 'prec');
            end
        end

    end
end