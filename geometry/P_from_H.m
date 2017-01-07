%P_FROM_H Compute motion hypotheses from a homography or 2D correspondences
%
%   P = P_from_H(H)
%   P = P_from_H(X1, X2)
%
%IN:
%   H - 3x3 homography on calibrated image coordinates, i.e.
%       K^-1 * X2 = H * K^-1 * X1
%   X1 - 3xM set of calibrated image coordinates in image 1
%   X2 - 3xM set of calibrated image coordinates in image 2
%
%OUT:
%   P - 3x4xN array of N potential extrinsic matrices [R, t] (up to scale).

function P = P_from_H(x1, x2)
if nargin < 2
    H = x1;
    % This transcodes the C++ implementation from ORB-SLAM
    % Do the SVD of H
    [U, S, V] = svd(H);
    P = zeros(3, 4, 0);

    % Check all 3 singular values are sufficiently different
    S = diag(S);
    if any(S([1 2]) ./ S([2 3]) < 1.00001)
        return;
    end

    s = det(U) * det(V);
    V = V';
    S2 = S .* S;

    tp = sqrt((S2([1 2]) - S2([2 3])) ./ (S2(1) - S2(3)));
    tp = bsxfun(@times, tp([1 1 2]), [1 1 -1 -1; 0 0 0 0; -1 1 -1 1]);
    T = normalize(U * tp * (S(1) - S(3))); 

    ctheta = 1 ./ (S(2) * (S(1) + S(3)));
    stheta = sqrt((S2(1) - S2(2)) * (S2(2) - S2(3))) * ctheta;
    ctheta = ctheta * (S2(2) + S(1) * S(3));
    R1 = s * U * [ctheta 0 -stheta; 0 1 0; stheta 0 ctheta] * V;
    R2 = s * U * [ctheta 0 stheta; 0 1 0; -stheta 0 ctheta] * V;

    P = cat(3, [R1 T(:,1)], [R2 T(:,2)], [R2 T(:,3)], [R1 T(:,4)]);

    tp(3,:) = -tp(3,:);
    T = normalize(U * tp * (S(1) + S(3)));

    ctheta = 1 ./ (S(2) * (S(1) - S(3)));
    stheta = sqrt((S2(1) - S2(2)) * (S2(2) - S2(3))) * ctheta;
    ctheta = ctheta * (S(1) * S(3) - S2(2));
    R1 = s * U * [ctheta 0 stheta; 0 -1 0; stheta 0 -ctheta] * V;
    R2 = s * U * [ctheta 0 -stheta; 0 -1 0; -stheta 0 -ctheta] * V;

    P = cat(3, P, [R1 T(:,1)], [R2 T(:,2)], [R2 T(:,3)], [R1 T(:,4)]);
    return;
end

% Use the IPPE method of Collins & Bartoli:
% "Infinitesimal Plane-Based Pose Estimation"

P = perspectiveIPPE(x1, proj(x2), 'DLT', struct('measureTiming', false, 'withPoseRefinement', false));
P = cat(3, [P.R1 P.t1], [P.R2 P.t2]);
end
