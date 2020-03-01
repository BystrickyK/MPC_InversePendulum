clc
clear all 
close all

eta_g = 0.9; %gearbox efficiency
K_g = 3.71; %gearbox gear ratio
k_t = 7.68e-3; %motor current-torque constant
k_m = 7.68e-3; %motor back-emf constant
R_m = 2.6; %motor armature resistance
r_mp = 6.35e-3; %motor pinion radius (prumer pastorku)
eta_m = 0.69; %motor efficiency
J_p = 1.2e-3; %moment of inertia about CoM, medium length pendulum
L_p = 0.3365; %full length of the pendulum
l_p = L_p/2;
M_p = 0.127; %pendulum mass
%J_p = J_pCoM + M_p * l_p^2
M_c = 0.38; %cart mass
J_m = 3.9e-7; %motor moment of inertia
J_eq = M_c + eta_g*K_g^2*J_m/r_mp^2;
B_eq = 4.3; %equivalent viscous damping coefficient (cart)
B_p = 0.0024; %equivalent viscous damping coefficient (pendulum)
g = 9.81;

    p.B_eq = B_eq;
    p.B_p = B_p;
    p.J_eq = J_eq;
    p.J_p = J_p;
    p.K_g = K_g;
    p.M_p = M_p;
    p.R_m = R_m;
    p.eta_g = eta_g;
    p.eta_m = eta_m;
    p.g = g;
    p.k_m = k_m;
    p.k_t = k_t;
    p.l_p = l_p;
    p.r_mp = r_mp;
%%  Navrh regulatoru
    %stavovy bod pro linearizaci
    X_operating = [0 pi 0 0];
    [A,B,C,D] = ABCD(X_operating, 0, p)
    
    Q = diag([10 10 1 1]);
    R = 0.15;
    K_lqr = lqr(A,B,Q,R)
    disp(eigs(A-B*K_lqr))
    
    %pole = [ -2, -2.1, -2.2, -2.3];
    %K_pp = place(A,B,pole)
    %disp(eigs(A-K_pp*B))
%% Navrh estimatoru

    Vd = 1*diag(4);      %disturbance covariance
    Vd(1,1) = 10;
    
    Vn = [100 0; 0 0.5];                 %noise covariance

    Af = A-B*K_lqr;
    Bf = B*K_lqr
    
    Cf = eye(4); 
    
    Kf = (lqr(Af', C', Vd, Vn))';
    
    KF = ss(Af-Kf*C, [Bf Kf], Cf, 0*[Bf Kf]);
    disp(eigs(KF.A))

%% Nastaveni pocatecnich hodnot
%pocatecni stav
X = [0, pi, 0, 0]; %alpha, Dalpha, xc, Dxc
%pozadovany stav
W = [0, pi, 0, 0];
Wrel = W - X_operating;

%nastaveni solveru
options = odeset();

simulationTime = 1e4;
dt = 0.02; %samplovaci perioda
kRefreshPlot = 10; %vykresluje se pouze po kazdych 'kRefreshPlot" samplech
kRefreshAnim = 5; % ^

%predalokace poli pro data
Xs = zeros(simulationTime/dt, 4); %skutecny stav
Xs(1,:) = X;
Xest = zeros(simulationTime/dt, 4); %estimovany stav
Xest(1,:) = X - X_operating;
Ts = zeros(simulationTime/dt, 1);   %cas
U = zeros(simulationTime/dt, 1);   %vstupy
U(1) = 0;
Wx = zeros(simulationTime/dt, 1); %pozadovana poloha xc
D = zeros(simulationTime/dt, 2); %poruchy
Y = zeros(simulationTime/dt, 2); %mereni
Y(1,:) = X(1, 1:2) - X_operating(1:2);
Wx(1) = W(1);

d = [0 0];
d1T = 0;
d1t = 0;
d1a = 0;
d2T = 0;
d2t = 0;
d2a = 0;


%% Simulace
tic
disp("1000 samples = " + 1000*dt + "s");
for k = 1:simulationTime/dt
    % Soucasny stav
    X = Xs(k,:);
    
    % Generovani pozadovaneho stavu
    if rand(1) > 0.99      
        W = [(2*rand(1)-1)*0.95, pi, 0, 0];
        %W = [sign(2*rand(1)-1)*0.9, pi, 0, 0];
        %W = [sin(pi/16*k*dt), pi, 0, 0];
        Wrel = W - X_operating;
    end
    
    %% Generovani poruchy
    if rand(1) > 0.999      %sila
        d(1) = randn(1)*0.1;
        d1T = randn(1)*100;
        d1t = 0;
        d1a = 1;
        %disp("Porucha d1")
        %disp(d(1))
        %disp(d1T)
    end
    
    if rand(1) > 0.995      %moment
        d(2) = randn(1)*0.1;
        d2T = randn(1)*100;
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
    


    %% Regulace
    %definice vstupu a saturace do <-12,12>
    Xr = Xest(k,:) + X_operating;
    if(Xr(1)<0.99 && Xr(1)>-0.99)
        u = -K_lqr * ( Xr' - W' );
        u = min(12, max(-12, u));
    elseif(Xr(1)>0.99)
        u = 0
        disp("!")
    elseif(Xr(1)<-0.99)
        u = 0;
        disp("!")
    end
    
    %% Estimace stavu X
    xe = Xs(k,:)' - X_operating';
    y = Y(k, :)';
    yError = y - C*xe;
    dxeA = KF.A*xe;
    %dxeB = KF.B * [Wrel'; yError];
    dxeBW = KF.B(:, 1:4)*Wrel'
    dxeBYERROR = KF.B(:, 5:6)*yError
    Dxe = (dxeA + dxeBW + dxeBYERROR)*dt;
    Xest(k+1, :) = xe+Dxe; 
       % Xest are coords relative to X_operating

    %% Simulace
    
    %"spojite" reseni v intervalu dt, uklada se pouze konecny stav 
    [ts, xs] = ode45(@(t, X) pendulumCart(X,u,d,p), [(k-1)*dt k*dt], X, options);
    
    %mezni polohy xc <-1 1>
    %po odrazu je velikost rychlosti 10% rychlosti pred narazem
    if(Xs(k,1)>1)
        Xs(k,3) = -abs(Xs(k,3)*0);
        Xs(k,1) = 1;
        disp("bonk")
    elseif(Xs(k,1)<-1)
        Xs(k,3) = +abs(Xs(k,3)*0);
        Xs(k,1) = -1;
        disp("bonk")
    end
    
	Xs(k+1,:) = xs(end,:);
    Ts(k+1) = ts(end);
    U(k+1) = u;
    Wx(k+1) = W(1);
    D(k+1, :) = d;
    
    % mereni Y
    Y(k+1, :) = C * xs(end,:)' + [randn(1)*010 randn(1)*0.01]' - X_operating(1:2)';
    
    
    %% Vizualizace
    
    
    %refresh plotu
    if(mod(k+1,kRefreshPlot)==1)
        plotRefresh(Ts,Xs,Xest+X_operating,Wx,U,D,k,kRefreshPlot);
    end
    
    %refresh animace
    if(mod(k,kRefreshAnim)==0)
        animRefresh(Ts,Xs,W,k);
    end
      
    %progress meter a vypocetni cas na 1000 vzorku
    if (mod(k,1000)==0) 
        disp("Computing time: " + toc)
        disp(k + "/" + simulationTime/dt);
        tic
    end
end

sol.X = Xs
sol.T = Ts
sol.U = U
