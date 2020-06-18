%% Init
clc
clear all 
close all

cd('..\..\');
parentDir = cd('.\LQG\P');
addpath(strcat(parentDir,'\functions')); %enables access to scripts in the folder
resultsDir = strcat(parentDir,'\results');
savefileDir = strcat(resultsDir, '\P_LQG');
if ~exist(savefileDir,'dir')
    mkdir(savefileDir);
end
timeLabel = datetime;
timeLabel.Format = 'dd-MM-uu_HH-mm_ss';
timeLabel = string(timeLabel);
saveFilePath = strcat(savefileDir,'\data_',timeLabel);
%%  Initialize interface
% Cart Position Pinion number of teeth
N_pp = 56;


    wcf = 2 * pi * 10.0;  % filter cutting frequency
    zetaf = 0.9;  
% Rack Pitch (m/teeth)
Pr = 1e-2 / 6.01; % = 0.0017

global K_EC K_EP
    % Cart Encoder Resolution (m/count)
    K_EC = Pr * N_pp / ( 4 * 1024 ); % = 22.7485 um/count
    % Pendulum Encoder Resolution (rad/count)
    % K_EP is positive, since CCW is the positive sense of rotation
    K_EP = 2 * pi / ( 4 * 1024 ); % = 0.0015
   
K_AMP = 1;

X_LIM_ENABLE = 1;
XMAX = 0.20;

ALPHA_LIM_ENABLE = 1;
ALPHAMAX = pi/8;

KF_Ts = 0.010;

VMAX_AMP = 8;

% Initial state
X0 = [0; 0; pi; 0];
%%  Model
    X_operating = [0 0 pi 0]';
    [A, B] = AB(X_operating, 0);
    Co = [1 0 0 0; 0 0 1 0]; % observed outputs | measuring xc and alpha
    Cr = [1 0 0 0]; % reference outputs
    D = [0; 0];
    
    % Adding an error integrator into the state space description
    % The controller's objective is to follow the reference r
    % with the variable x_c, where x_c is the position of the cart
    % The controlled plant already has an integrator, the controller's
    % integrator purpose is to reject constant disturbances, not to
    % remove steady-state error. 
    Ah = [A, zeros(length(A),1);
         -Cr, 0];
    Bh = [B; 0];
    Cho = [1 0 0 0 0; 0 0 1 0 0];
    Dh = [0;0];
    
    Gi = ss(Ah,Bh,Cho,Dh,...
        'StateName', {'x1','x2','x3','x4','Ksi'},...
        'OutputName', {'x_c','alpha'}); %added integrator
    G = ss(A,B,Co,D,...
        'StateName', {'x1','x2','x3','x4'},...
        'OutputName', {'x_c','alpha'}); %original system
    Go = ss(A,B,eye(4),zeros(4,1),...
        'StateName', {'x1','x2','x3','x4'},...
        'OutputName', {'x_c','dx_c','alpha','dalpha'}); %fully observed system
    
 %% Regulator
 Q = diag([60 0.0001 300 0.0001]); %P
%  Q = diag([1 0.1 1 0.1 5]); %I  / PI
    R = 0.001;
    [K,S,e] = lqr(G.A,G.B,Q,R);
    K = lqr(G,Q,R);