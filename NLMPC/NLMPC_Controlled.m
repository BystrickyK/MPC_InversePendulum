%%  Init
clc
clear all 
close all

cd('../');
parentDir = cd('./NLMPC');
addpath(parentDir);
addpath(strcat(parentDir,'/functions')); 
addpath(strcat(parentDir,'/results')); 
C = [1 0 0 0; 0 0 1 0];
p = getParameters();
%%  Navrh regulatoru    
nx = 4;
ny = 2;
nu = 1;
nlobj = nlmpc(nx, ny, nu);


nlobj.PredictionHorizon = 7;
nlobj.ControlHorizon = 4;
MPC_Ts = 0.1;
nlobj.Ts = MPC_Ts;

nlobj.Model.StateFcn = 'pendCartC';
nlobj.Jacobian.StateFcn = 'AB';
nlobj.Model.IsContinuousTime = true;
nlobj.Model.NumberOfParameters = 0;
% nlobj.Model.OutputFcn = @(X, u) [X(1); sawtooth(X(3), 0.5)];
triangleWaveFourier3 = @(x) 8/pi^2 * (sin(x) - 1/9*sin(3*x) + 1/25*sin(5*x));
nlobj.Model.OutputFcn = @(X, u) [X(1); triangleWaveFourier3(X(3)-pi/2)];

nlobj.Weights.OutputVariables = [8 4];
nlobj.Weights.ManipulatedVariablesRate = 0.01;

%  nlobj.OV(1).Min = -0.33;
%  nlobj.OV(1).Max = 0.33;
%  
nlobj.MV.Min = -5;
nlobj.MV.Max = 5;
 
nlobj.Optimization.UseSuboptimalSolution = true;
nlobj.Optimization.SolverOptions.MaxIter = 4;
% nlobj.Optimization.SolverOptions.UseParallel = true;
nlobj.Optimization.SolverOptions.Algorithm = 'sqp';
nlobj.Optimization.SolverOptions.Display = 'none';

X = [0; 0; 0; 0];
validateFcns(nlobj, X, 0, [])

%% Navrh EKF

EKF = extendedKalmanFilter(@(X,u) pendCartD(X,u), ...
                           @(X) [X(1); X(3)]);
EKF.MeasurementNoise = diag([1 1]);
EKF.ProcessNoise = diag([1 5 1 5]);

%% Nastaveni pocatecnich hodnot
%pocatecni stav
X0 = [0 0 0 0]'; %xc dxc alpha dalpha
EKF.State = X;
u = 0;
%nastaveni solveru
options = odeset();

simulationTime = 20;
MPC_Ts = MPC_Ts; %samplovaci perioda

%predalokace poli pro data
X = zeros(4, simulationTime/MPC_Ts); %skutecny stav
X(:,1) = X0;
Xest = zeros(4,simulationTime/MPC_Ts); %estimovany stav
Xest(:,1) = X0;
Ts = zeros(1,simulationTime/MPC_Ts);   %spojity cas
U = zeros(1,simulationTime/MPC_Ts);   %vstupy
U(1) = u;
D = zeros(2,simulationTime/MPC_Ts); %poruchy
Y = zeros(2,simulationTime/MPC_Ts); %mereni
Y(:,1) = [X0(1), X0(3)];
Rf = zeros(2,simulationTime/MPC_Ts); %reference
computingTimes = [];
computingTimes2 = [];
INFO = [];

d = [0 0]';
d1T = 0;
d1t = 0;
d1a = 0;
d2T = 0;
d2t = 0;
d2a = 0;

yref1 = [0 1];
[~, nloptions_ref1] = nlmpcmove(nlobj, [0 0 0 0], 0, yref1,[]);
yref2 = [0 -1];


yref = yref1;

nloptions = nloptions_ref1; %initial guess
%% Uprava parametru
inertia_coeff = 0.9;
p.J_p = p.J_p*inertia_coeff %moment setrvacnosti kyvadla
p.M_p = p.M_p*inertia_coeff %hmotnost kyvadla
p.l_p = p.l_p*inertia_coeff %polovina delky kyvadla
p.k_m = p.k_m * 1; %torque coefficient
p.k_t = p.k_m;
p.J_eq = p.J_eq * inertia_coeff; %equivalent LINEAR cart inertia

%% Simulace
hbar = waitbar(0,'Simulation Progress');
tic
disp("1000 samples = " + 1000*MPC_Ts + "s");
for k = 1:simulationTime/MPC_Ts*10
    %% Generovani pozadovaneho stavu
    T = mod(k*MPC_Ts/10, 20);
    
    if( T == 0)
            yref = yref1;
    elseif( T == 12)
            yref = yref2;
    end
       
%         %% Generovani poruchy
%     if rand(1) > 0.99      %sila
%         d(1) = randn(1)*3;
%         d1T = randn(1)*30;
%         d1t = 0;
%         d1a = 1;
%         %disp("Porucha d1")
%         %disp(d(1))
%         %disp(d1T)
%     end
%     
%     if d1a==1
%         d1t = d1t + 1;
%         if (d1t >= d1T)
%             d(1) = 0;
%         end
%     end
    %% Estimace stavu X; pouziti mereni pro korekci predpovedi
    Xest(:,k) = correct(EKF, Y(:,k));
    %% Regulace
    if(mod(k,10)==0)
        tic
        [u, nloptions, info] = nlmpcmove(nlobj,Xest(:,k),U(k),yref,[],nloptions);
        computingTime = toc
        computingTimes = [computingTimes, computingTime];
        INFO = [INFO info];
%               %Vizualizace predikce
%               figure(4)
%               for i = 1:4
%                   subplot(3,2,i)
%                   plot(info.Topt, info.Xopt(:,i), 'ko-')
%                   grid on
%               end
%               subplot(313)
%               stairs(info.Topt, info.MVopt(:,1), 'ko-');
%               grid on
% 
%               %Vypocetni cas
%               diskp("Computing time: " + computingTimes(end))
%               disp(k + "/" + simulationTime/dt*10);
    end    

    %% Simulace
    
    %"spojite" reseni v intervalu dt, uklada se pouze konecny stav 
    [ts, xs] = ode45(@(t, X) pendCartC_symbolicPars(X,u,d,p), [(k-1)*MPC_Ts/10 k*MPC_Ts/10], X(:,k), options);
    X(:,k+1) = xs(end,:)';
    Ts(k+1) = ts(end);
    U(k+1) = u;
    D(:,k+1) = d;
    Rf(:,k+1) = yref;
    %% Mereni a predikce EKF
    Y(:,k+1) = C * xs(end,:)' + [randn(1)*0.002 randn(1)*0.002]';  
    predict(EKF, u);

    waitbar(k*MPC_Ts/simulationTime/10,hbar);
    end

close(hbar);

sol.X = X;
sol.Xest = Xest;
sol.T = Ts;
sol.U = U;
sol.R = Rf';
sol.D = D;
sol.Y = Y;
sol.dt = MPC_Ts;
sol.INFO = INFO;
sol.controller = nlobj;
sol.computingTimes = computingTimes;

%vytiskne �e�en�
sol

    figure('Name', 'Computing times')
    bar(Ts(1:10:end-1), computingTimes);
    grid on

save(strcat(parentDir,'/results/ResultsNLMPC.mat'), 'sol');

%% Vizualizace vysledku
visualizeData('ResultsNLMPC.mat');

