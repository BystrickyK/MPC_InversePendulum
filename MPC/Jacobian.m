function A = Jacobian(x,u)
%AB
%    A = Jacobian(x)

%    This function was generated by the Symbolic Math Toolbox version 8.4.
%    19-May-2020 20:15:23

X2 = x(2,:);
X3 = x(3,:);
X4 = x(4,:);
t2 = cos(X3);
t3 = sin(X3);
t4 = X4.^2;
t5 = t2.^2;
t6 = t3.^2;
t7 = t5.*4.565807400625001e-4;
t8 = t7-3.005650706948956e-3;
t9 = 1.0./t8;
t10 = t9.^2;
A = reshape([0.0,0.0,0.0,0.0,1.0,t9.*5.403790646678023e-2,0.0,t2.*t9.*(-2.408005488399419e-1),0.0,t9.*(t5.*4.695776235861862e-7-t6.*4.695776235861862e-7-X4.*t3.*5.3763908601e-9+t2.*t4.*1.074185854609239e-8).*(-9.53848061542277e+3)-t2.*t3.*t10.*(X2.*(-5.665253057117538e-6)+u.*5.387661376655595e-7+X4.*t2.*5.3763908601e-9+t2.*t3.*4.695776235861861e-7+t3.*t4.*1.074185854609239e-8).*8.71017307692308,0.0,t9.*(t2.*1.377486248645154e-5+X2.*t3.*2.524516833955624e-5+t4.*t5.*4.786723991704242e-8-t4.*t6.*4.786723991704242e-8-t3.*u.*2.40081805770912e-6).*9.53848061542277e+3+t2.*t3.*t10.*(X4.*1.57714169184e-7+t3.*1.377486248645154e-5-X2.*t2.*2.524516833955624e-5+t2.*u.*2.40081805770912e-6+t2.*t3.*t4.*4.786723991704242e-8).*8.71017307692308,0.0,t9.*(t2.*5.3763908601e-9+X4.*t3.*2.148371709218477e-8).*(-9.53848061542277e+3),1.0,t9.*(X4.*t2.*t3.*9.573447983408483e-8+1.57714169184e-7).*9.53848061542277e+3],[4,4]);
