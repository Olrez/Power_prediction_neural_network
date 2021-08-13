% Noise data clenaing algorithm
clc; clear;
data = xlsread('data.xlsx','data','A1:A140256'); // Private national data import
data_qty=length(data);
samples1=15;
samples2=300;

%Samples medayn calculation
for n = 1:data_qty-samples1

    L(n,1)=medayn(data(n:(n+samples1),1));
     
end

%Standard deviation
for n = 1:data_qty-samples1*2
    
    SD(n,1)=std(data(n:(n+samples1),1)-L(n:(n+samples1),1)); 
    
end

% Sensibility bands
L2(1:data_qty-samples1*2,1)=L(1:data_qty-samples1*2,1);
usb=L2+3*SD;
lsb=L2-3*SD;
%graph
figure(1)
plot(data)
hold on
plot(usb)
plot(lsb)
legend('original data', 'Upper sensible band', 'Lower sensible band')

%medayn
for n = 1:data_qty-samples2
    
    L_large(n,1)=medayn(data(n:(n+samples2),1));
     
end

%SD
for n = 1:data_qty-samples2*2
    
    SD_large(n,1)=std(data(n:(n+samples2),1)-L_large(n:(n+samples2),1)); 
     
end

% Lower sensibility band
L3(1:data_qty-samples2*2,1)=L_large(1:data_qty-samples2*2,1);
usb_large=L3+3*SD_large;
lsb_large=L3-3*SD_large;
%graph
figure(2)
plot(data)
hold on
plot(usb_large)
plot(lsb_large)
legend('original data', 'Upper sensible band', 'Lower sensible band')

%% Noise data erasure
clc;
forward1=7; %band forward
forward2=8;
corrected_data=data;
for n = samples1*2:data_qty-samples1*2
   
    if data(n,1) > usb(n-forward1,1)
    error1(n,1)=data(n,1);
    disp(n) %data errors (4)
    %linear extrapolation
    corrected_data(n,1)=(data(n+1,1)+data(n-1,1))/2;
    else
    error1(n,1)=0;
    end
    
    if data(n,1) < lsb(n-forward2,1)
    error2(n,1)=data(n,1);
    disp(n) %no error
    else
    error2(n,1)=0;        
    end
end
corrected_data(87909,1)=(data(87910,1)+data(87908,1))/2;
%% large bands
for n = samples2*2:data_qty-samples2*2
   
    if data(n,1) > usb_large(n-samples2,1)% & data(n,1) < lsb_large(n-samples2,1)
    
    disp(data(n,1))   
    
%else 
    end
end
%% clean data arrangement
%corrected_data = xlsread('corrected_data.xlsx','data','A1:A140256');
for D = 1:(366+365*3)
    
    for H = 1:96
        
        fixed_data(H,D) = corrected_data(H+96*(D-1),1);
        
    end
end
%save('fixed_data')

%% Data merge code

% load the clean data arranged as a daily matrix
% train the neural network to get code input 1 and the predictive network
% size 2 matrix to build a 4 bit array
nctool
%save('netclustering')
%save('output')


%% Input and target creation
clc;
%weely code logic
day_num=[7 1 2 3 4 5 6];
for n=0:7:1461
    
    for i=1:7    
    
    day(1,i+n)=day_num(i);
    if (i+n)>1460
        break
    end
    end
    
end

%monthly code logic
leap=29;
total_acum=0;
month_days=[31 leap 31 30 31 30 31 31 30 31 30 31];
for n=1:4
    day_acum=0;
    if n>=2
       month_days(2)=28;
    end
    for j=1:12
        for i=1:month_days(j)    
    
        month(1,i+day_acum+total_acum)=j;
    
        end
    day_acum=day_acum+i;
    end
    total_acum=total_acum+day_acum;
end

%holidays logic, Costa Rica
a=0;
for n=1:1461
   if n==122+365*a
      work_day(1,n)=1;
      a=a+1;
   else
      work_day(1,n)=0; 
   end
end

%concatenate arrays
input_comp = vertcat(fixed_data,output,day,month,work_day);
%the last 2 days are deteled to perform a 48 hours prediction
input=input_comp(1:103,1:1459);
%save('input')

%first two days are deleted to create the training target
target=fixed_data(1:96,3:1461);
%save('target')

%% Power predictive Neural Network
% the neural network is trained for a number of neurons such that the mean square error 
% is th less possible, the network and the output are stored to calculate the training error
nftool
%save('netprediction34')
%save('error')
%save('output_pred')

%% created network error
load('error','error')
load('output_pred','output_pred')
load('target','target')
clc;
error_percent=abs(target-output_pred)*100./target;

error=mean(error_percent);
min_error=min(error);
max_error=max(error);
absolute_error=mean(error);
plot(error)
xlabel('Time (days)')
ylabel('%')
title(['Max. %error = ',num2str(max_error),'  Min. %error = ',num2str(min_error),'  %mean error = ',num2str(absolute_error)])

%% Prediction
clc; clear;
load('netclustering','netclustering')
load('error','error')
load('output_pred','output_pred')
load('target','target')
load('fixed_data','fixed_data')
load('netprediction34','netprediction34')

%input preparation from the measured day
med_day=fixed_data(:,1);
codigo=sim(netclustering,med_day);% group code
day=7; %sunday
month=1; %january
work_day=0;
input_day=vertcat(med_day,codigo,day,month,work_day);

%national power preduction to 48 h
prediction=sim(netprediction34,input_day);

% prediction error
error_pred=mean(abs(target(:,1)-prediction)*100./target(:,1));
disp(error_pred)

% plot
plot(target(:,1),'color',[0.9290    0.6940    0.1250],'LineWidth',2)
hold on
plot(prediction,'color',[0    0.7500    0.7500],'LineWidth',2)
legend('Power measured',['Power prediction, %error = ',num2str(error_pred)])
grid on
ylabel('Power (MVA)')
xlabel('Time (hour quarter)')
%grid minor
%save('prediction')
