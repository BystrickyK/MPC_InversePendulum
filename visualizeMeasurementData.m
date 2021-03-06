close all

addpath('functions')
[file, filepath] = uigetfile([pwd, '\results'])
data = load([filepath '\' file])
%%
data = data.data;
%%
Xmsr = data.Xmsr;
    T = Xmsr.alpha.Time;
Xest = data.Xest;
U = data.U.u;
Rf = data.Rf.signal1;
%% Resampling
names = string(fieldnames(Xmsr));
% for i = 1:4
%     Xest.(names(i)) = resample(Xest.(names(i)),T);
% end
U = resample(U,T);
if length(Rf.Data)==1
    Rf = timeseries([Rf.Data Rf.Data], [Rf.Time T(end)])
end
Rf = resample(Rf,T);

%%
U = U.Data;
Rf = Rf.Data;
X1 = zeros(4, length(T));
X2 = zeros(4, length(T));
for i = 1:4
    X1(i,:) = Xmsr.(names(i)).Data;
    X2(i,:) = Xmsr.(names(i)).Data;
end
dt = T(2)-T(1);
%% Plot figure

figure;
% hAx = gobjects(2*4,1);
hAx = gobjects(4,1);
titlestrings = ["$x_c \; [m]$", "$\dot{x_c} \; [\frac{m}{s}]$",...
    "$\alpha \; [rad]$", "$\dot{\alpha} \; [\frac{rad}{s}$]"];
ylabelstrings = titlestrings;
xlabelstring = "$Time \; [s]$";

for i=1:4

    hAx(i) = subplot(2,2,i);
    plot(T,X1(i,:),'b');
    hold on
    plot(T,X2(i,:),'r:');
    
    % set titles and labels
    hAx(i).Title.String = titlestrings(i);
    hAx(i).Title.Interpreter = 'latex';
    hAx(i).Title.FontSize = 14;

    hAx(i).XLabel.String = xlabelstring;
    hAx(i).XLabel.Interpreter = 'latex';
    hAx(i).XLabel.FontSize = 12;

    hAx(i).YLabel.String = ylabelstrings(i);
    hAx(i).YLabel.Interpreter = 'latex';
    hAx(i).YLabel.FontSize = 12;

end
plot(T,Rf(:,1),'g-.', 'Parent', hAx(1));

%% Animace

kRefreshPlot = 60; 
kRefreshAnim = 20;
for k = 2:1:length(T)
    if(mod(k,kRefreshPlot)==0) xlim(hAx,[k*dt-15 k*dt]); end
    
    if(mod(k,kRefreshAnim)==0)
        animRefresh(X1(:,k), X2(:,k), Rf(k), U(k), 0);
        titleString = strcat("Time: ", string(T(k)), " s");
        title(titleString)      
    end
              
end