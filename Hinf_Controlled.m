%%  Zadan� hodnoty
clc
clear all 
close all
addpath('functions') % toto p�id� slo�ku functions do prohl�d�van�ch

p = getParameters();
% initializeModel();

%% Linearizace v pracovn�m bod?
X_operating = [0 pi 0 0];
[A, B] = AB(X_operating', 0);
C = eye(4,4);
C_real = [1 0 0 0; 0 1 0 0];
D = [0; 0; 0; 0];

P = ss(A,B,C,D); %plant
P.u = 'u';
P.y = 'y';

%% Struktura regul�toru
C0 = tunableGain('C0',1,4);
C0.u = {'e(1)', 'e(2)', 'e(3)', 'e(4)'};
C0.y = 'u';
%% V�hov� filtry   
W1 = 1/makeweight(10,1,0.5);
W2 = 1/makeweight(0.1,[32 0.32],1);
W3 = 1/makeweight(0.5,1,10);

W1.u = 'e(1)+e(2)';
W1.y = 'z1';
W2.u = 'u';
W2.y = 'z2';
W3.u = 'y(1)';
W3.y = 'z3';

%% Vytvoreni struktury

Sum = sumblk('e = w - y', 4);
CL0 = connect(P, C0, Sum, ...
    W1, W2, W3, ...
    {'w'}, {'z1', 'z2', 'z3'});

rng('shuffle')
synthesisOptions = hinfstructOptions('Display','final','RandomStart',5);
[CL, gamma] = hinfstruct(CL0, synthesisOptions);
K = getBlockValue(CL, 'C0');

showTunable(CL);
ls = loopsens(P,K);

sigma(ls.Si,'b',ls.Li,'r',ls.Ti,'g',gamma/W1,'b-.',gamma/W2,'r-.',gamma/W3,'g-.',{1e-3,1e3})
legend('S','KS','T','GAM/W1','GAM/W2','GAM/W3','Location','SouthWest')
grid

K_hinf = K.D;

Areg = (A-B*K_hinf)
eigs(Areg)


%% Navrh estimatoru


%% Nastaveni pocatecnich hodnot
%pocatecni stav
X = [0 pi 0 0]; %alpha, dAlpha, xc, dXc

W = [0, pi, 0, 0];
Wrel = W - X_operating;

%nastaveni solveru
options = odeset();

simulationTime = 15;
dt = 0.01; %samplovaci perioda
kRefreshPlot = 100; %vykresluje se pouze po kazdych 'kRefreshPlot" samplech
kRefreshAnim = 5; % ^

%predalokace poli pro data
Xs = zeros(simulationTime/dt, 4); %skutecny stav plantu
Xs(1,:) = X;

Xr = zeros(simulationTime/dt, 13); %stav regulatoru

Ts = zeros(simulationTime/dt, 1);   %cas

U = zeros(simulationTime/dt, 1);   %vstupy
U(1) = 0;
D = zeros(simulationTime/dt, 2); %poruchy

Y = zeros(simulationTime/dt, 2); %mereni
Y(1,:) = X(1, 1:2);


computingTimes = zeros(simulationTime/dt, 1);
Xc = X;
Tc = [];
%INFO = zeros(simulationTime/dt, 1);

d = [0 0];
d1T = 0;
d1t = 0;
d1a = 0;
d2T = 0;
d2t = 0;
d2a = 0;

%% Simulace
hbar = waitbar(0,'Simulation Progress');
tic
disp("1000 samples = " + 1000*dt + "s");
for k = 1:simulationTime/dt
    %% Generovani pozadovaneho stavu
    if rand(1) > 0.99      
        W = [(2*rand(1)-1)*0.50, pi, 0, 0];
        %W = [sign(2*rand(1)-1)*0.9, pi, 0, 0];
        %W = [sin(pi/16*k*dt), pi, 0, 0];
        Wrel = W - X_operating;
    end

    %% Generovani poruchy
    if rand(1) > 0.99      %sila
        d(1) = randn(1)*.5;
        d1T = randn(1)*10;
        d1t = 0;
        d1a = 1;
        %disp("Porucha d1")
        %disp(d(1))
        %disp(d1T)
    end
    
    if rand(1) > 0.99      %moment
        d(2) = randn(1)*.5;
        d2T = randn(1)*10;
        d2t = 0;
        d2a = 1;
        %disp("Porucha d2")
        %disp(d(2))
        %disp(d2T)
    end
    
    if d1a==1
        d1t = d1t + 1;
        if (d1t >= d1T)
            d(1) = 0;
        end
    end
    
    if d2a==1
        d2t = d2t + 1;
        if (d2t >= d2T)
            d(2) = 0;
            d2a = 0;
        end
    end
    
    %% Estimace stavu X; pouziti mereni pro korekci predpovedi

    %% Regulace
    u = -K_hinf*(Wrel-Xs(k,:))';
    %% Simulace
    
    %"spojite" reseni v intervalu dt, uklada se pouze konecny stav 
    [ts, xs] = ode45(@(t, X) pendulumCart_symbolicPars(X,u,d,p), [(k-1)*dt/10 k*dt/10], Xs(k,:), options);

	Xs(k+1,:) = xs(end,:);
    Ts(k+1) = ts(end);
    U(k+1) = u;
    %Wx(k+1) = W(1);
    D(k+1, :) = d;
    Xc = [Xc; xs];
    Tc = [Tc; ts];
    
    %% Mereni a predikce EKF
    Y(k+1, :) = C_real * xs(end,:)' + [randn(1)*0.001 randn(1)*0.01]';  

    waitbar(k*dt/simulationTime,hbar);
    end

close(hbar);

sol.X = Xs;
% sol.Xest = Xest;
sol.T = Ts;
sol.U = U;
sol.D = D;
sol.Y = Y;
sol.Xc = Xc;
sol.Tc = Tc;
% sol.computingTimes = computingTimes;

%vytiskne �e�en�
sol

    figure('Name', 'Computing times')
    bar(Ts(1:end-1), computingTimes);
    grid on

save('results/ResultsHinf.mat', 'sol');