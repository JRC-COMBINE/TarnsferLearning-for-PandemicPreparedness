classdef mapper
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
        ivars
        weights_lasso
        mu
        sigma
    end

    methods
        function obj = mapper(x, des, inorm)
            obj = obj.set_normalization_params(x(inorm,:));
            obj = obj.set_predictors(x, des);
        end

        function obj = set_normalization_params(obj, x)
            obj.mu = mean(x, "omitnan");
            obj.sigma = std(x, "omitnan");
        end

        function obj = set_predictors(obj, x, des)
            % Normalisation
            z = (x - obj.mu)./obj.sigma;

            % Imputations
            % Nach der Normalisierung, ersetze NaNs mit 0 unter der Annahme, dass die Maschinen bei fehlenden Werten ausgeschaltet
            % wurden und der Patient somit im Normalbereich, also gleich der Überlebenskohorte ist.
            z = fillmissing(z, "constant", 0);

            % Lasso
            [B, FitInfo] = lasso(z, des, "CV", 10);
            wLasso = B(:,FitInfo.Index1SE);
            obj.ivars = find(wLasso~=0);
            obj.weights_lasso = wLasso(obj.ivars);

            % Remove insignificant features
            obj.mu = obj.mu(obj.ivars);
            obj.sigma = obj.sigma(obj.ivars);
        end

        function x = map_timeSeriesData(obj, x, los)
            x = x(:,:,obj.ivars);
            T = size(x,1);
            for t=1:T
                % Normalisation
                x(t,:,:) = (squeeze(x(t,:,:)) - obj.mu) ./ obj.sigma;
                % Imputation
                flag = los>=t;
                x(t,flag,:) = fillmissing(x(t,flag,:), 'constant', 0);

                if t>1
                    % Smoothing (each datapoint in the future is influenced by datapoints of the past, with decreasing weights in
                    % time)
                    x(t,flag,:) = (x(t,flag,:)+x(t-1,flag,:))/2;
                end
            end
        end
    end
end