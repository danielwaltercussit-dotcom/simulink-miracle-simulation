% Required data to run New England 39 Bus benchmark
% By HJQ 20260120 
wbase=2*pi*60;
tbase=1/wbase;
%% Line data Format (line)
% All values are given on the same system base MVA
% 1: From bus  
% 2: To bus   
% 3: Resistance (pu)
% 4: Reactance  (pu)
% 5: Charge     (pu)
% 6: Transformer Tap Amplitute
% 7: base MVA
% 8: Nomonal Voltage (KV) 

%   1   2    3        4       5     6    7   8    9    10    11    12    13    14    15   
line=[...
    1	2	0.0035	0.0411	0.6987	0	100	345 275.5 0.032 0.373 1.105e-6 0.318 1.119 0.609e-6  
    1	39	0.001	0.025	0.75	0	100	345 167.6 0.015 0.373 1.790e-6 0.149 1.119 1.074e-6
    2	3	0.0013	0.0151	0.2572	0	100	345 101.2 0.032 0.373 1.017e-6 0.321 1.119 0.610e-6
    2	25	0.007	0.0086	0.146	0	100	345 57.6  0.304 0.373 1.103e-6 3.036 1.119 0.608e-6
    2	30	0	    0.0181	0	  1.025	100	22   0      0     0    0      0     0     0
    3	4	0.0013	0.0213	0.2214	0	100	345 142.8 0.023 0.373 0.620e-6 0.228 1.119 0.372e-6
    3	18	0.0011	0.0133	0.2138	0	100	345 89.1  0.031 0.373 0.959e-6 0.308 1.119 0.576e-6
    4	5	0.0008	0.0128	0.1342	0	100	345 85.8  0.023 0.373 0.626e-6 0.233 1.119 0.375e-6
    4	14	0.0008	0.0129	0.1382	0	100	345 86.5  0.023 0.373 0.639e-6 0.231 1.119 0.384e-6 
    5	8	0.0008	0.0112	0.1476	0	100	345 17.4  0.029 0.373 0.996e-6 0.287 1.119 0.598e-6
    6	5	0.0002	0.0026	0.0434	0	100	345 75.1  0.027 0.373 0.786e-6 0.266 1.119 0.472e-6
    6	7	0.0006	0.0092	0.113	0	100	345 61.7  0.024 0.373 0.733e-6 0.243 1.119 0.440e-6
    6	11	0.0007	0.0082	0.1389	0	100	345 55.0  0.032 0.373 1.011e-6 0.318 1.119 0.607e-6
    7	8	0.0004	0.0046	0.078	0	100	345 30.8  0.032 0.373 1.102e-6 0.324 1.119 0.607e-6
    8	9	0.0023	0.0363	0.3804	0	100	345 243.3 0.024 0.373 0.625e-6 0.236 1.119 0.375e-6
    9	39	0.001	0.025	1.2	    0	100	345 167.6 0.015 0.373 2.865e-6 0.149 1.119 1.719e-6
    10	11	0.0004	0.0043	0.0729	0	100	345 28.8  0.035 0.373 1.012e-6 0.347 1.119 0.607e-6
    10	13	0.0004	0.0043	0.0729	0	100	345 28.8  0.035 0.373 1.012e-6 0.347 1.119 0.607e-6
    10	32	0	    0.02	0	  1.07	100	22  0      0     0      0     0     0     0
    12	11	0.0016	0.0435	0	  1.006	100	345 0      0     0      0     0     0     0
    12	13	0.0016	0.0435	0	  1.006	100	345 0      0     0      0     0     0     0
    13	14	0.0009	0.0101	0.1723	0	100	345 67.7  0.033 0.373 1.108e-6 0.332 1.119 0.611e-6
    14	15	0.0018	0.0217	0.366	0	100	345 145.5 0.031 0.373 1.007e-6 0.309 1.119 0.604e-6
    15	16	0.0009	0.0094	0.171	0	100	345 63.0  0.036 0.373 1.086e-6 0.357 1.119 0.651e-6
    16	17	0.0007	0.0089	0.1342	0	100	345 59.7  0.029 0.373 0.900e-6 0.293 1.119 0.540e-6
    16	19	0.0016	0.0195	0.304	0	100	345 130.7 0.031 0.373 0.930e-6 0.306 1.119 0.558e-6
    16	21	0.0008	0.0135	0.2548	0	100	345 90.5 0.022 0.373 1.126e-6 0.221 1.119 0.676e-6
    16	24	0.0003	0.0059	0.068	0	100	345 39.5 0.019 0.373 0.688e-6 0.190 1.119 0.413e-6
    17	18	0.0007	0.0082	0.1319	0	100	345 55.0 0.032 0.373 0.960e-6 0.318 1.119 0.576e-6
    17	27	0.0013	0.0173	0.3216	0	100	345 116.0 0.028 0.373 1.109e-6 0.280 1.119 0.666e-6
    19	33	0.0007	0.0142	0	  1.07	100	22   0      0     0      0     0     0     0
    19	20	0.0007	0.0138	0	  1.06	100	345  0      0     0      0     0     0     0
    20	34	0.0009	0.018	0	  1.009	100	22   0      0     0      0     0     0     0
    21	22	0.0008	0.014	0.2565	0	100	345 93.8 0.021 0.373 1.093e-6 0.213 1.119 0.656e-6
    22	23	0.0006	0.0096	0.1846	0	100	345 64.3 0.023 0.373 1.148e-6 0.233 1.119 0.689e-6
    22	35	0	    0.0143	0	  1.025	100	22   0      0     0      0     0     0     0
    23	24	0.0022	0.035	0.361	0	100	345 234.6 0.023 0.373 0.616e-6 0.234 1.119 0.369e-6
    23	36	0.0005	0.0272	0	    1	100	22   0      0     0      0     0     0     0
    25	26	0.0032	0.0323	0.513	0	100	345 216.5 0.037 0.373 0.948e-6 0.370 1.119 0.569e-6
    25	37	0.0006	0.0232	0	  1.025	100	22   0      0     0      0     0     0     0
    26	27	0.0014	0.0147	0.2396	0	100	345 98.5 0.036 0.373 0.973e-6 0.355 1.119 0.584e-6
    26	28	0.0043	0.0474	0.7802	0	100	345 317.7 0.034 0.373 0.982e-6 0.338 1.119 0.589e-6
    26	29	0.0057	0.0625	1.029	0	100	345 418.9 0.034 0.373 0.983e-6 0.340 1.119 0.590e-6
    28	29	0.0014	0.0151	0.249	0	100	345 101.2 0.035 0.373 0.984e-6 0.346 1.119 0.590e-6
    29	38	0.0008	0.0156	0	  1.025	100	22   0      0     0      0     0     0     0
    31	6	0	    0.025	0	    1	100	22   0      0     0      0     0     0     0 ];

%% Machine Data Format (mac_con)
% 1.  Machine Number
% 2.  Bus Number
% 3.  Base MVA
% 4.  Leakage Reactance x_l(pu)
% 5.  Resistance r_a(pu)
% 6.  d-axis sychronous reactance x_d(pu)
% 7.  d-axis transient reactance x'_d(pu)
% 8.  d-axis subtransient reactance x"_d(pu)
% 9.  d-axis open-circuit time constant T'_do(sec),
% 10. d-axis open-circuit subtransient time constant T"_do(sec)
% 11. q-axis sychronous reactance x_q(pu)
% 12. q-axis transient reactance x'_q(pu)
% 13. q-axis subtransient reactance x"_q(pu)
% 14. q-axis open-circuit time constant T'_qo(sec)
% 15. q-axis open circuit subtransient time constant % T"_qo(sec)
% 16. inertia constant H(sec)
% 17. damping coefficient d_o(pu)
% 18. dampling coefficient d_1(pu)
% 19. bus number
% Note: all the following machines use sub-transient model
% 1  2     3      4      5      6     7    8      9    10    11    12    13    14    15    16    17    18  19
mac_con=[
  1  39 1000.0 0.30 0.0050   1.0  0.60  0.4  7.000 0.003 1.0  0.80  0.4   0.700 0.005 5.00 0.000 0.00 39 ;
  2  31  1000.0 0.350 0.0270  2.950 0.697 0.4  6.560 0.003 2.820 1.7   0.5  1.500 0.005 3.030 0.000 0.00 31 ;
  3  32  1000.0 0.304 .00386  2.495 0.531 0.4  5.700 0.003 2.370 0.876 0.5  1.500 0.005 3.580 0.000 0.00 32 ;
  4  33  1000.0 0.295 .00222  2.620 0.436 0.4  5.690 0.003 2.580 1.66  0.5  1.500 0.005 2.860 0.000 0.00 33 ;
  5  34  1000.0 0.540 0.0014  4.020 1.320 0.6  5.400 0.003 3.720 1.66  0.8  0.440 0.005 2.600 0.000 0.00 34 ;
  6  35  1000.0 0.224 0.0615  2.540 0.500 0.3  7.300 0.003 2.410 0.814 0.5  0.400 0.005 3.480 0.000 0.00 35 ;
  7  36  1000.0 0.322 .00268  2.950 0.490 0.4  5.660 0.003 2.920 1.86  0.5  1.500 0.005 2.640 0.000 0.00 36 ;
  8  37  1000.0 0.280 .00686  2.900 0.570 0.3  6.700 0.003 2.800 0.911 0.5  0.410 0.005 2.430 0.000 0.00 37 ;
  9  38  1000.0 0.298 0.0030  2.106 0.570 0.3  4.790 0.003 2.050 0.587 0.5  1.960 0.005 3.450 0.000 0.00 38 ;
  10 30  1000.0 0.125 0.0054  1.000 0.310 0.2  10.20 0.003 0.690 0.5  0.4  1.500 0.005 4.200 0.000 0.00 30 ];

%mac_con(:,5)=0;

p0=[1000 520.81 650 632 508 650 560 540 830 250]'./1000;%Active Power Generation of PV units
Pn(1:10,1)=mac_con(:,3)*1e6; % Nominal Power
% 由实用参数计算基本参数
mac_Fu(1:10,1)=mac_con(:,6)-mac_con(:,4);
mac_Fu(1:10,2)=((mac_con(:,7)- mac_con(:,4)) .* mac_Fu(1:10,1)) ./ (mac_Fu(1:10,1) - (mac_con(:,7)- mac_con(:,4)) );
mac_Fu(1:10,3)=(mac_Fu(1:10,1).* mac_Fu(1:10,2).*(mac_con(:,8)-mac_con(:,4)))./(mac_Fu(1:10,1).* mac_Fu(1:10,2)-(mac_con(:,8)-mac_con(:,4)).*(mac_Fu(1:10,1)+mac_Fu(1:10,2)));
mac_Fu(1:10,4) = (mac_Fu(1:10,2)+mac_Fu(1:10,1)) .* tbase ./ mac_con(:,9);
mac_Fu(1:10,5) = ((mac_Fu(1:10,3)+mac_Fu(1:10,1)) -(mac_Fu(1:10,1).*mac_Fu(1:10,1))./(mac_Fu(1:10,2)+mac_Fu(1:10,1)))* tbase ./ mac_con(:,10);

mac_Fu(1:10,6)=mac_con(:,11)-mac_con(:,4);
mac_Fu(1:10,7)=((mac_con(:,12)- mac_con(:,4)) .* mac_Fu(1:10,6)) ./ (mac_Fu(1:10,6) - (mac_con(:,12)- mac_con(:,4)) );
mac_Fu(1:10,8)=(mac_Fu(1:10,6).* mac_Fu(1:10,7).*(mac_con(:,13)-mac_con(:,4)))./(mac_Fu(1:10,6).* mac_Fu(1:10,7)-(mac_con(:,13)-mac_con(:,4)).*(mac_Fu(1:10,6)+mac_Fu(1:10,7)));
mac_Fu(1:10,9) = (mac_Fu(1:10,7)+mac_Fu(1:10,6)) .* tbase ./ mac_con(:,14);
mac_Fu(1:10,10) = ((mac_Fu(1:10,8)+mac_Fu(1:10,6)) -(mac_Fu(1:10,6).*mac_Fu(1:10,6))./(mac_Fu(1:10,7)+mac_Fu(1:10,6)))* tbase ./ mac_con(:,15);
%% Power System Stabilizer Format (MB)
% Applied power system stabilizer is MBPSS with simplified settings
% Note: All machines use MBPSS with same configuration 
% 1: Global gain (G)
% 2: Frequency of low frequency band (FL) Hz
% 3: Gain of low frequency band (KL)
% 4: Frequency of intermediate frequency band (FI) Hz
% 5: Gain of intermediate frequency band (KI)
% 6: Frequency of high frequency band (FH) Hz
% 7: Gain of high frequency band (KH)
%   1    2  3     4   5      6  7
MB=[1   0.2 30   1.25 40    12 160];

%% Excitation System format (AVR_Data)
% All machines use IEEE type 1 synchronous machine voltage regulator combined to an exciter
% 1. st1_Tr(voltage meter time constant [s])
% 2. st1_Vimax(control error high limit [pu(V_base)])
% 3. st1_Vimin(control error low limit [pu(V_base)])
% 4. st1_Tc(transient filter lead time constant [s])
% 5. st1_Tb(transient filter lag time constant [s])
% 6. st1_Ka(regulator gain (incl base conv V_base/Efd_base))
% 7. st1_Ta(regulator time constant [s])
% 8. st1_Vrmax(regulator high limit)
% 9. st1_Vrmin(regulator low limit)
% 10. st1_Kc(transformer fed systems)
% 11. st1_Kf (feedback gain (incl base conv Efd_base/V_base))
% 12. st1_Tf(feedback time constant [s])
%   1    2     3     4      5      6     7     8    9     10    11  12
 AVR_Data=[...
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %1
  0.01 0.1   -0.1   1.0    10     200  0.015  5   -5     0    0.0  1.0  %2
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %3
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %4
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %5
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %6
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %7
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %8
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0  %9
  0.01 0.1   -0.1   1.0    10     200   0.015  5   -5     0    0.0  1.0 ];%10

%%  电力系统稳定器参数
% 1. Stabilizer Input selection
% 2. pss1a_T1(lead time constant no1)
% 3. pss1a_T2(lag time constant no1)
% 4. pss1a_T3(lead time constant no2)
% 5. pss1a_T4(lag time constant no2)
% 6. pss1a_T5(washout time constant)
% 7. pss1a_T6(transducer time constant)   
% 8. pss1a_Ks(gain)
% 9. pss1a_Vstmax(Maximum output limit)
% 10.pss1a_Vstmin(Minimum output limit)   
% 11. pss1a_A1(High frequency filter coefficients)
% 12. pss1a_A2(High frequency filter coefficients)
% // Stabilizer Input selection
% // 1 - rotor speed deviation (SM device Omega_1 only)
% // 2 - bus frequency deviation
% // 3 - electrical power
% // 4 - accelerating power
 PSS_Data=[...
    1  5.0    0.6   3.0    0.5    10    0.0    1   0.20  -0.20  0   0  %1
    1  5.0    0.4   1.0    0.1    10    0.0  0.5   0.20  -0.20  0   0  %2
    1  3.0    0.2   2.0    0.2    10    0.0  0.5   0.20  -0.20  0   0  %3
    1  1.0    0.1   1.0    0.3    10    0.0    2   0.20  -0.20  0   0  %4
    1  1.5    0.2   1.0    0.1    10    0.0    1   0.20  -0.20  0   0  %5
    1  0.5    0.1   0.5   0.05    10    0.0    4   0.20  -0.20  0   0  %6
    1  0.2   0.02   0.5    0.1    10    0.0  7.5   0.20  -0.20  0   0  %7
    1  1.0    0.2   1.0    0.1    10    0.0    2   0.20  -0.20  0   0  %8
    1  1.0    0.5   2.0    0.1    10    0.0    2   0.20  -0.20  0   0  %9
    1  1.0   0.05   3.0    0.5    10    0.0    1   0.20  -0.20  0   0];%10
 PSS_Data(:,8)=20;
 PSS_Data(:,7)=15e-3;
%%  调速器与气缸参数
% 1. ieeeg1_K
% 2. ieeeg1_T1
% 3. ieeeg1_T2
% 4. ieeeg1_T3
% 5. ieeeg1_Uo
% 6. ieeeg1_Uc(gate min closing speed)
% 7. ieeeg1_Pmax   
% 8. ieeeg1_Pmin
% 9. ieeeg1_T4(Steam flow time cst(s))
% 10.ieeeg1_K1 Fraction of LP mech power  
% 11. ieeeg1_K2  Fraction of HP mech power
% 12. ieeeg1_T5  First reheater time cst
% 13. ieeeg1_K3  Fraction of LP mech power
% 14. ieeeg1_K4  Fraction of HP mech power
% 15. ieeeg1_T6  Second reheater time cst 
% 16. ieeeg1_K5  Fraction of LP mech power
% 17. ieeeg1_K6  Fraction of HP mech power
% 18. ieeeg1_T7  Crossover reheater time cst  
% 19. ieeeg1_K7  Fraction of HP mech power
% 20. ieeeg1_K8  Fraction of HP mech power
STG_Data=[20 0.0 0 0.0075 0.6786 -1.0 0.90 0.0 0.3 0.2 0 10 0.4 0 0.6 0.4 0 0 0 0];
%% 变压器参数
% 1   2    3    4   5    
Trans=[
  12   11   450e6   0.0072   0.196    %1
  12   13   450e6   0.0072   0.196    %2
  6    31   1000e6     0     0.25     %3 
  10   32   1000e6     0     0.2      %4
  19   33   1000e6   0.007   0.142    %5
  20   34   600e6    0.0054  0.108    %6
  22   35   1000e6     0     0.143    %7
  23   36   1000e6   0.005   0.272    %8
  25   37   1000e6   0.006   0.232    %9
  2    30   1000e6     0     0.181    %10
  29   38   1000e6   0.008   0.156    %11
  19   20   1400e6   0.0098  0.1932]; %12

