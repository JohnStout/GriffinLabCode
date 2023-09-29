%% autocov_to_var
%
% Calculate VAR parameters from autocovariance sequence
%
% <matlab:open('autocov_to_var.m') code>
%
%% Syntax
%
%     [A,SIG] = autocov_to_var(G)
%
%% Arguments
%
% See also <mvgchelp.html#4 Common variable names and data structures>.
%
% _input_
%
%     G          autocovariance sequence
%
% _output_
%
%     A          VAR coefficients matrix
%     SIG        residuals covariance matrix
%
%% Description
%
% Calculates regression coefficients |A| and residuals covariance matrix
% |SIG| from the autocovariance sequence |G| defined as [[ii_acseq.png]]
% by solving the Yule-Walker equations
%
% <<eq_yweqs.png>>
%
% (where  [[ii_Sigma.png]] = |SIG|). For a |q|-lag autocovariance sequence,
% this routine corresponds to an autoregression of |q| lags. It also
% effects an efficient spectral factorisation if called with the
% autocovariance sequence derived from the cross-power spectral density
% (_e.g._ as calculated by <cpsd_to_autocov.html |cpsd_to_autocov|>).
%
% This routine implements Whittle's recursive LWR algorithm [2] which, for |n|
% variables, performs |2q| separate |n x n| matrix inversions as compared with a
% single |nq x nq| matrix inversion for the conventional "OLS" solution of the
% Yule-Walker equations (see [1]). The LWR algorithm also (unlike OLS)
% guarantees that if the "true" regression model is stable, then the estimated
% model is also stable, even if not of the correct order.
%
%% References
%
% [1] L. Barnett and A. K. Seth, <matlab:open('mvgc_doc.pdf') The MVGC
% Multivariate Granger Causality Toolbox>, _in preparation_, Aug. 2012.
%
% [2] P. Whittle, "On the fitting of multivariate autoregressions, and the
% approximate canonical factorization of a spectral density matrix",
% _Biometrika_, 50, 1963.
%
%% See also
%
% <cpsd_to_autocov.html |cpsd_to_autocov|>
%
% (C) Lionel Barnett and Anil K. Seth, 2012. See file license.txt in
% installation directory for licensing terms.
%
%%

function [AF,SIG] = autocov_to_var(G)

[n,~,q1] = size(G);
q = q1-1;
qn = q*n;

G0 = G(:,:,1);                                               % covariance
GF = reshape(G(:,:,2:end),n,qn)';                            % forward  autocov sequence
GB = reshape(permute(flipdim(G(:,:,2:end),3),[1 3 2]),qn,n); % backward autocov sequence

AF = zeros(n,qn); % forward  coefficients
AB = zeros(n,qn); % backward coefficients (reversed compared with Whittle's treatment)

% initialise recursion

k = 1;            % model order

r = q-k;
kf = 1:k*n;       % forward  indices
kb = r*n+1:qn;    % backward indices

AF(:,kf) = GB(kb,:)/G0;
AB(:,kb) = GF(kf,:)/G0;

% and loop

for k=2:q

    AAF = (GB((r-1)*n+1:r*n,:)-AF(:,kf)*GB(kb,:))/(G0-AB(:,kb)*GB(kb,:)); % DF/VB
    AAB = (GF((k-1)*n+1:k*n,:)-AB(:,kb)*GF(kf,:))/(G0-AF(:,kf)*GF(kf,:)); % DB/VF

    AFPREV = AF(:,kf);
    ABPREV = AB(:,kb);

    r = q-k;
    kf = 1:k*n;
    kb = r*n+1:qn;

    AF(:,kf) = [AFPREV-AAF*ABPREV AAF];
    AB(:,kb) = [AAB ABPREV-AAB*AFPREV];

end

if nargout > 1
    SIG = G0-AF*GF;
end

AF = reshape(AF,n,n,q);
