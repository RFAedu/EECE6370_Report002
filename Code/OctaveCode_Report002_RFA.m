#Report002 data Generation script
#Roberto Avila
#EECE6370

#{
Data Types (MWh):
Tot_Gen -> Total Power Generation
  Nuc_Gen -> Nuclear power Generation
  Sol_Gen -> Solar Power Generation
  Win_Gen -> Wind power Generation
  Oth_Gen -> Other Power Generation

Tot_Dem -> Total power demand with no optimization
Opt_Dem -> Optimized data center demand
  Oth_Dem -> Domestic & other demand
  Dat_Dem -> Base demand from data centers

Error Measurement -> error pr hour between optimized and unoptimized demand
  EU -> Unoptimized
  EO -> Optimized
#}

#Base Generation (MWh)
Nuc_Base = 90000;
Sol_Base = 85000;
Wind_Base1 = 35000;
Wind_Base2 = 10000;

#Grid variance metric % of how much demand varies from generation minus 4% from data centers
GVar = 0.05;
DVar = 0.04;  # percentage from total generation that equals data center demand

#Data Center Metrics
Dat_Var = 0.15; #Maximum Data center power shifting
Dat_Rmp = 1200; #maximum rate of change that data centers can have in MW/min


#Cheap way to make time for functions
Time = 168
Time_H = linspace(0,7,Time)';

Nuc_Gen = ones(Time, 1)*Nuc_Base';
Sol_Gen = -cos(7 * Time_H)*Sol_Base';
Win_Gen = Wind_Base1 + Wind_Base2*(sin(7 * Time_H)) - rand(Time,1)*Wind_Base2;

#Realistic Sol_Gen Script:
for i = 1:length(Sol_Gen)
  if Sol_Gen(i,1) < 0
    Sol_Gen(i,1) = 0;
    Sol_Gen(i,1);
  endif
endfor

#Totals
Tot_Gen = Nuc_Gen + Sol_Gen + Win_Gen;
Dat_Dem = DVar*Tot_Gen;
#Total Demand script
for i = 1:length(Tot_Gen)
  Tot_Dem(i,1) = Tot_Gen(i,1) + randi([-5,1])*(GVar/2)*Tot_Gen(i,1) + Dat_Dem(i,1);
endfor

Opt_Dem = Tot_Dem;
#Demand v Generation Optimization algorithm (not proud of it)
for i = 1:(length(Tot_Gen)-1)#Super awesome iteration loop

Dat_Max = (Dat_Var+1)*Dat_Dem(i,1);#Maximum Data center demand
Dat_Min = (Dat_Var-1)*Dat_Dem(i,1);#Minimum Data Center demand
  if (Tot_Gen(i,1) > Opt_Dem(i,1))#Checks if generation is greater than demand if yes ramp up
    disp("Ramp Up");
    if (Dat_Max > (Dat_Rmp+Dat_Dem(i,1)))#Checks if maximum rule isnt being broken by ramp
      Tmp_Dem = Opt_Dem((i+1),1) + Dat_Rmp;#applies ramp value of next optimization demand in temporary variable
    else
      Tmp_Dem = Opt_Dem((i+1),1) + (Dat_Max-Dat_Dem(i,1));#Applies maximal ramp up to next without breaking max demand
    endif
    Opt_Dem(i+1,1) = Tmp_Dem; #Applies ramp change
    EU(i,1) = abs(Tot_Dem(i,1)-Tot_Gen(i,1));
    EO(i,1) = abs(Opt_Dem(i,1)-Tot_Gen(i,1));
  elseif (Tot_Gen(i,1) < Opt_Dem(i,1))#Checks if generation is less than demand if yes ramp down
    disp("Ramp Down");
    if (Dat_Min < (Dat_Dem(i,1)-Dat_Rmp))#Checks if minimum rule isnt being broken by ramp
      Tmp_Dem = Opt_Dem((i+1),1) - Dat_Rmp;#applies ramp value of next optimization demand in temporary variable
    else
      Tmp_Dem = Opt_Dem((i+1),1) + (Dat_Min-Dat_Dem(i,1));#Applies maximal ramp down to next without breaking max demand
    endif
    Opt_Dem(i+1,1) = Tmp_Dem; #Applies ramp change
    EU(i,1) = abs(Tot_Dem(i,1)-Tot_Gen(i,1));
    EO(i,1) = abs(Opt_Dem(i,1)-Tot_Gen(i,1));
  endif


endfor

#Final Data CSV generation
Data = [Time_H,Nuc_Gen,Sol_Gen,Win_Gen,Tot_Gen,Tot_Dem];

#Testing plot for quick Verification
#subplot(1,2,1);
plot(Time_H, Nuc_Gen,'r', Time_H, Sol_Gen,'g',...
 Time_H, Win_Gen, 'b', Time_H, Tot_Gen,'k', Time_H, Tot_Dem,'c',...
 Time_H, Dat_Dem, 'm');
title ("Optimized vs Unoptimized demand");
xlabel ("Decimal Time in days");
ylabel ("Energy in MWh");
legend ("Nuclear Generation","Solar Generation", "Wind Generation", ...
"Total Generation", "Total Unoptimized demand", "Data center base demand");


###Error plots
##subplot(1,2,2);
##plot(Time_H, EU, Time_H, EO);
##legend("Unoptimized Error", "Optimized Error");
##
mean(EU)
mean(EO)






