clear all;
N = 2500; % Number of creditors
NZ = 500; % Number of samples from MC
nE = 500; % Number of epsilion samples to take PER z sample
NPi = 1200; % Number of samples from MCMC of pi
NRuns = 5; % Number of times to recompute integral before averaging results
S = 20; % Dimension of Z
k = 2; % Number of Gaussians in MoG
burninRatio = 0.1;
C = 4;
  
a = zeros(1,NRuns);
v = zeros(1,NRuns);
  
az = zeros(1,NZ);
vz = zeros(1,NZ);
try
    for r=1:NRuns
        totalT = cputime;
        disp(strcat('RUN NUMBER',num2str(r)))
        %Initialize data
        [H, BETA, tail, EAD, CN, LGC, CMM] = ProblemParams(N, S, true);
        %Sample from pi
        %disp('BEGIN MCMC SAMPLING FROM PI')
        t = cputime;
        B = floor(NPi * burninRatio);
        f = @(z) DensityAtZ(z,H,BETA,tail,EAD,LGC);

        sampleZ = slicesample(rand(1,S), NPi, 'pdf', f, 'thin', 3, 'burnin', B);
        %disp(strcat('FINISH MCMC SAMPLING FROM PI...',num2str(cputime - t),'s'))

        %disp('BEGIN TRAINING MOG')
        t = cputime;
        [~, model, ~] = Emgm(sampleZ', k);  
        MoGWeights = model.weight;
        MoGMu = model.mu;
        MoGSigma = model.Sigma;
        %disp(strcat('FINISH TRAINING MOG...',num2str(cputime - t),'s'))
        zIndex = 1;
        l = zeros(NZ,1);
        for zIndex=1:NZ
        %while true
%             disp('BEGIN SAMPLING')
%             t = cputime;
            sampleZ = SampleMoG(MoGWeights,MoGMu,MoGSigma,1)';
            MoGDen = arrayfun(@(i) EvalMoG(MoGWeights,MoGMu,MoGSigma,sampleZ(:,i)),1:1);
            %ZDen = arrayfun(@(i) f(sampleZ(:,i)'),1:1);
            %MoGIntegrand = ZDen./MoGDen;
            %disp('MoG Estimate')
            %vpa(mean(MoGIntegrand))
%             %vpa(var(MoGIntegrand))
%             clear MoGIntegrand;
%             clear MoGMu;
%             clear MoGSigma;
%             clear MoGWeights; 
%             clear model;
%             disp(strcat('FINISH SAMPLING...',num2str(cputime - t),'s'))

%             disp('BEGIN COMPUTING PNCZ')
%             t = cputime;
            denom = (1-sum(BETA.^2,2)).^(1/2);
            BZ = BETA*sampleZ;
            CH = H;
            CHZ = repmat(CH,1,1,1);
            BZ = reshape(BZ,N,1,1);
            CBZ = repelem(BZ,1,C);
            PINV = (CHZ - CBZ) ./ denom;
            PHI = normcdf(PINV);
            PHI = [zeros(N,1,1) PHI];
            pncz = diff(PHI,1,2); %column wise diff
%             clear BETA;
%             clear BZ;
%             clear CH;
%             clear CHZ;
%             clear CBZ;
%             clear PHI;
%             clear PInv;
%             disp(strcat('FINISH COMPUTING PNCZ...',num2str(cputime - t),'s'))

%             disp('BEGIN COMPUTING THETA')
%             t = cputime;
            weights = EAD.*LGC;
            [pTheta,theta] = GlassermanPTheta(pncz,weights,tail);
%             disp(strcat('FINISH COMPUTING THETA...',num2str(cputime - t),'s'))

%             disp('BEGIN SAMPLING PNCZ')
%             t = cputime;
            cdf = cumsum(pTheta,2);
            cdf = repelem(cdf,1,1,nE);
            u = rand([N,1,nE*1]);
            isOne = (cdf >= u) == 1;
            ind = (cumsum(isOne,2) == 1);
%             clear isOne;
%             clear u;
%             clear cdf;
%             disp(strcat('FINISH SAMPLING PNCZ...',num2str(cputime - t),'s'))

%             disp('BEGIN COMPUTING LOSS')
%             t = cputime;
            LossMat = repelem(weights,1,1,1*nE).*ind;
            Loss = sum(sum(LossMat,2),1);
            theta = reshape(theta,[1,1,1]);
            B = zeros([N C 1]);
            for j=1:1
                B(:,:,j) = theta(:,:,j)*weights;
            end
            psi = sum(log(sum(pncz.*exp(B),2)),1);
            LRE = reshape(exp(-repelem(theta,1,1,nE).*Loss + repelem(psi,1,1,nE)),1,nE*1,1);
            Loss = reshape(Loss,1,nE*1);
            LRZ = repelem(arrayfun(@(i) mvnpdf(sampleZ(:,i))/MoGDen(i),1:1),1,nE);
            LR = LRE.*LRZ;
            %l(zIndex) = double(Loss > tail).*LR;
            l = double(Loss > tail).*LR;
            az(zIndex) = mean(vpa(l));
            %vz(zIndex) = vpa(var(l));
            
%             if (mod(zIndex,10000) == 0)
%               vpa(mean(az))
%             end
            %zIndex = zIndex + 1;
%             clear C;
%             clear CMM;
%             clear CN;
%             clear denom;
%             clear EAD;
%             clear f;
%             clear H;
%             clear ind;
%             clear l;
%             clear LGC;
%             clear Loss;
%             clear LossMat;
%             clear LR;
%             clear LRE;
%             clear LRZ;
%             clear MoGDen;
%             clear psi;
%             clear pTheta;
%             clear sampleZ;
%             clear theta;
%             clear weights;
%             clear ZDen;
%             clear pncz;
%             disp(strcat('FINISH COMPUTING LOSS...',num2str(cputime - t),'s'))
%             disp(strcat('TOTAL RUNTIME...',num2str(cputime - totalT),'s'))
        end
        a(r) = vpa(mean(az));
        %v(r) = vpa(mean(vz));
        disp(strcat('TOTAL RUNTIME...',num2str(cputime - totalT),'s'))
    end
catch ex
    disp(ex)
end
%[vpa(a); vpa(v)]'
disp('mean')
vpa(a)
vpa(mean(a))
%disp('var')
%vpa(v)
%vpa(mean(v))
