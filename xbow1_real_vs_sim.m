% Example of use of NAVEGO. 
% GPS clock is master clock
% Trajectory from Toth2012

fprintf('\nStart simulation xbow1... \n')

clc
close all 
clear

%% Global variables
global d2r

addpath /home/rodralez/my/matlab/NaveGo_main/
addpath /home/rodralez/my/doctorado/dataset/melbourne/

%% PARAMETERS

load H764_DGPS.mat;

% REF           = 'ON';
% IMU1_INTERPOL = 'ON';
IMU1_SINS     = 'ON';
  
% GPS_SIMUL     = 'ON';
IMU2_SIMUL    = 'ON';
IMU2_SINS     = 'ON';

RMSE          = 'ON';
PLOT          = 'ON';

num_experiments = 1;

% Simulation interval (seconds)
tmin = 509880;
tmax = 510000; % quick tests
% tmax = 510380; % time up to yaw drift, 9 minutes
% tmax = 510420; % time up to first impase
% tmax = 510720; % time up to signal loss
% tmax = 510850; % include GPS signal partial loss

if (~exist('REF','var')), REF = 'OFF'; end
if (~exist('IMU1_DATA','var')), IMU1_DATA = 'OFF'; end
if (~exist('IMU2_SIMUL','var')), IMU2_SIMUL = 'OFF'; end
if (~exist('GPS_SIMUL','var')), GPS_SIMUL = 'OFF'; end
if (~exist('IMU1_SINS','var')), IMU1_SINS = 'OFF'; end
if (~exist('IMU1_INTERPOL','var')), IMU1_INTERPOL = 'OFF'; end
if (~exist('IMU2_SINS','var')), IMU2_SINS = 'OFF'; end
if (~exist('RMSE','var')), RMSE = 'OFF'; end
if (~exist('PLOT','var')), PLOT = 'OFF'; end

rmse_m = zeros(num_experiments, 24);
   
%% LEVER ARM

% GLADIATOR Lever arm vector taken from Toth2011
% larm = [-0.646 0.539 1.097 ]'; %  
% XSENS Lever arm vector taken from Toth2011
% larm = [-0.714 0.434 1.098]'; % 
% CROSSBOW 1 Lever arm vector taken from Toth2011
larm = [-0.781 0.438 1.072 ]'; %

%% CONVERSIONS

ms2kmh = 3.6;       % m/s to km/h  
d2r = (pi/180);     % degrees to rad
r2d = (180/pi);     % rad to degrees
mss2g = (1/9.81);   % m/s^2 to g  
g2mss = 9.81;
kt2ms = 0.514444444;% knot to m/s

% Magnetic declination
D = 13 * d2r; % http://www.ngdc.noaa.gov/geomag-web/#declination
% Total Earth magnetic field
Em =  48728.9 * 1e-9;

%% LOAD REF DATA

if strcmp(REF, 'ON')
    
fprintf('Processing trajectory generator data... \n')
    
idx  = find(H764_DGPS.t < tmin, 1, 'last' ); 
fdx  = find(H764_DGPS.t < tmax, 1, 'last' );

ref.t    = H764_DGPS.t  (idx:fdx, :);     % Time, seconds
ref.lat  = H764_DGPS.lat(idx:fdx, :);     % Latitude, radians
ref.lon  = H764_DGPS.lon(idx:fdx, :);     % Longitude, radians

ref.h    = H764_DGPS.h  (idx:fdx, :);     % Altitude, meters
ref.vel  = H764_DGPS.vel(idx:fdx, :);     % m/s NED

% I check that roll and pitch angles are swapped.
ref.pitch = H764_DGPS.roll(idx:fdx, :); 
ref.roll  = H764_DGPS.pitch(idx:fdx, :); 

ref.yaw  = (-H764_DGPS.yaw (idx:fdx,:) + 2*pi); 
index=find(ref.yaw >= pi); 
ref.yaw(index) = ref.yaw(index) - 2*pi;
    
ref.kn = max(size(ref.t));

% Calculate DCM 
ref.DCMnb = zeros(ref.kn,9);
for i=1:ref.kn
    dmc_nb = euler2dcm([ref.roll(i) ref.pitch(i) ref.yaw(i)]);
    ref.DCMnb(i,:) = reshape(dmc_nb,1,9);    
end

clear dmc_nb p51d
save  ref.mat ref

else
    fprintf('Loading trajectory generator data... \n')
    
    load ref.mat
end

%% IMU xbow1 error profile

load xbow1.mat;

dt=mean(diff(xbow1.t));

% Sincronize GPS data with IMU data.
idx  = find(xbow1.t > ref.t(1), 1,   'first' ); 
fdx  = find(xbow1.t < ref.t(end), 1, 'last' );
% idx  = find( abs(xbow1.t - ref.t(1)) == min (abs (xbow1.t - ref.t(1))) );
% fdx  = find( xbow1.t > ref.t(end), 1, 'first' );

xbow1.t = xbow1.t (idx:fdx,:);
xbow1.fb = xbow1.fb (idx:fdx,:);
xbow1.wb = xbow1.wb (idx:fdx,:);

xbow1.fb(:,3) = -xbow1.fb(:,3);

xbow1.vrw    = [ 1.353E-03 1.353E-03 9.850E-04];         % m/s/root-s  ~ m/s^2/root-Hz
xbow1.arw    = [ 3.996E-02 3.141E-02 3.581E-02 ].*d2r;   % rad/root-s  ~ rad/s/root-Hz
xbow1.astd   = xbow1.vrw ./ sqrt(dt);                    % m/s^2/root-Hz  ->  m/s^2
xbow1.gstd   = xbow1.arw ./ sqrt(dt);                    % rad/s/root-Hz  ->  rad/s
xbow1.ab_drift  = [ 1.787E-04 1.843E-04 2.149E-04 ];     % m/s^2
xbow1.gb_drift  = [ 3.427E-03 2.028E-03 2.153E-03 ].*d2r; % deg/s  ->  rad/s 
xbow1.acorr = [ 196.9 332.8 79.16];     % sec
xbow1.gcorr = [ 250.7 432.2 395.2];     % sec
xbow1.ab_fix = [ 0.151 0.007 (9.829-9.81)];     % m/s^2
xbow1.gb_fix = [ 0.441 0.040 0.114 ] .* d2r;   % degree/s
xbow1.gpsd = xbow1.gb_drift .* sqrt(xbow1.gcorr);  % rad/s/root-Hz;
xbow1.apsd = xbow1.ab_drift .* sqrt(xbow1.acorr);  % m/s^2/root-Hz

xbow1.freq = floor(1/dt);

%% GPS Novatel

load novatel.mat

% CEP to dev. std., Farrel2008, p. 152
CEP = 1.5; 

% Sincronize GPS data with IMU data.
% igdx  = find(novatel.t > xbow1.t(1), 1, 'first' ); 
% fgdx  = find(novatel.t < xbow1.t(end), 1, 'last' );
igdx  = find(novatel.t > ref.t(1), 1,   'first' ); 
fgdx  = find(novatel.t < ref.t(end), 1, 'last' );

% Sincronize GPS data with REF data.
% igdx  = find( abs(novatel.t - ref.t(1)) == min (abs (novatel.t - ref.t(1))) );
% fgdx  = find(  novatel.t < ref.t(end), 1, 'last' );

novatel.t    = novatel.t(igdx:fgdx,:);  % Latitude, radians
novatel.lat  = novatel.lat(igdx:fgdx,:);  % Latitude, radians
novatel.lon  = novatel.lon(igdx:fgdx,:);  % Longitude, radians   +1.406233951130261e-07 
novatel.h    = novatel.h  (igdx:fgdx,:); % Altitude, meters
novatel.vel  = novatel.vel(igdx:fgdx,:); % Velocity, m/s

novatel.vel(:,3)  = novatel.vel(:,3); % Velocity, m/s

novatel.stdm  = [CEP*0.8493, CEP*0.8493, CEP*0.8493]; 
% novatel.stdm  = [0.666, 0.888, 1.2241]; 
novatel.stdv = 0.3 .* ones(1,3);
novatel = gps_err_profile(ref.lat(1), ref.h(1), novatel);
% novatel.larm  = [0 0 larm(3)]'; % zeros(3,1); %larm;
novatel.larm  = larm;

%% INTERPOLATE

if strcmp(IMU1_INTERPOL, 'ON')
    
    fprintf('Interpolating reference data sets... \n')

    ref_i1 = interpolate(ref, xbow1);

    % Interpolation of GPS measurements
    ref_g1 = interpolate(ref, novatel);
        
    save ref_i1.mat ref_i1
    save ref_g1.mat ref_g1
else
    
    fprintf('Loading interpolated reference data sets ... \n')
    
    load ref_i1.mat
    load ref_g1.mat
end

%% imu1/GPS INTEGRATION WITH FK
 
% load imu2.mat
% xbow1 = imu2;

if strcmp(IMU1_SINS, 'ON')
    
    fprintf('SINS/GPS real integration ... \n')

   % Sincronize GPS data with IMU data.
   % SINS must be executed before EKF at least once
    if (xbow1.t(1) < novatel.t(1)),    

        igx  = find(xbow1.t > novatel.t(1), 1, 'first' ); 
     
        xbow1.t  = ( xbow1.t  (igx:end, :) );
        xbow1.fb = ( xbow1.fb (igx:end, :) );
        xbow1.wb = ( xbow1.wb (igx:end, :) );
        
        ref_i1.t =    ( ref_i1.t     (igx:end, :) );
        ref_i1.roll = ( ref_i1.roll  (igx:end, :) );
        ref_i1.pitch =( ref_i1.pitch (igx:end, :) );
        ref_i1.yaw =  ( ref_i1.yaw (igx:end, :) );
        ref_i1.lat =  ( ref_i1.lat (igx:end, :) );
        ref_i1.lon =  ( ref_i1.lon (igx:end, :) );
        ref_i1.h =    ( ref_i1.h   (igx:end, :) );
        ref_i1.vel =  ( ref_i1.vel (igx:end, :) ); 
        ref_i1.DCMnb =( ref_i1.DCMnb (igx:end, :) ); 
        ref_i1.kn  =  max(size(ref_i1.t)); 
    end
    
    % SINS must provide data until last GPS measurement
    if (xbow1.t(end) < novatel.t(end)),   
        
        fgx  = find(novatel.t < xbow1.t(end), 1, 'last' );
        
        novatel.t = novatel.t(1:fgx, :);
        novatel.lat = novatel.lat(1:fgx, :);
        novatel.lon = novatel.lon(1:fgx, :);
        novatel.h   = novatel.h(1:fgx, :);    
        novatel.vel = novatel.vel(1:fgx, :);
        ref_g1.t   = ref_g1.t(1:fgx, :);
        ref_g1.lat = ref_g1.lat(1:fgx, :);
        ref_g1.lon = ref_g1.lon(1:fgx, :);
        ref_g1.h   = ref_g1.h(1:fgx, :);    
        ref_g1.vel = ref_g1.vel(1:fgx, :);  
    end    
    
    [imu1_e] = ins(xbow1, novatel, ref_i1, 'single');
    
    save imu1_e.mat imu1_e 
    save ref_i1.mat ref_i1
    fprintf('\n')    
else
    
    fprintf('Loading SINS/GPS real integration ... \n')
    load imu1_e.mat
    load ref_i1.mat    
end

for j=1:num_experiments

    
fprintf('>>>> Experiment number %d... <<<<\n', j)

% s = RandStream('mcg16807', 'Seed', rand_num(j));
% RandStream.setGlobalStream(s);

%% SIMULATE GPS

rng('shuffle')

if strcmp(GPS_SIMUL, 'ON')

    fprintf('Generating GPS data... \n')
    
    % gps.stdm  = [CEP*0.8493, CEP*0.8493, CEP*0.8493*2]; 
    [RM,RN] = radius(ref_g1.lat);
    lat2m = RM+ref_g1.h; 
    lon2m = (RN+ref_g1.h).*cos(ref_g1.lat);  
    std1 = rmse(novatel.lat.*lat2m, ref_g1.lat.*lat2m);  
    std2 = rmse(novatel.lon.*lon2m, ref_g1.lon.*lon2m); 
    std3 = rmse(novatel.h, ref_g1.h);
    gps.stdm = [std1, std2, std3]; 
    
    stdv1 = rmse(novatel.vel(:,1), ref_g1.vel(:,1));  
    stdv2 = rmse(novatel.vel(:,2), ref_g1.vel(:,2)); 
    stdv3 = rmse(novatel.vel(:,3), ref_g1.vel(:,3));
    gps.stdv = [stdv1, stdv2, stdv3];
    
    gps.larm  = zeros(3,1); % -[larm(1) larm(1) 0]'; % Lever arm

    dt=mean(diff(ref_g1.t));
    gps.freq = round(1/dt);
    
    gps = gps_err_profile(ref_g1.lat(1), ref_g1.h(1), gps);
    
    gps.t = novatel.t;
    
    [gps, ref_g2] = gps_gen(ref, gps);

%     ref_g2 = ref_g1;
    
    save gps.mat gps
    save ref_g2.mat ref_g2
    
else
    
    fprintf('Loading GPS data... \n')
    load gps.mat 
    load ref_g2.mat    
end

%% SIMULATE imu2

rng('shuffle')

if strcmp(IMU2_SIMUL, 'ON')

    ref_i2 = ref_i1;
%     ref_i2 = interpolate(ref, xbow1);    
    % ref_i2 = downsampling (ref, xbow1);  

    dt=mean(diff(xbow1.t));
    
    imu2.t      = ref_i2.t;
    imu2.vrw    = xbow1.vrw ;
    imu2.arw    = xbow1.arw ;
    imu2.astd   = xbow1.vrw ./ sqrt(dt); % m/s^2/root-Hz  ->  m/s^2
    imu2.gstd   = xbow1.arw ./ sqrt(dt); % rad/s/root-Hz  ->  rad/s
    imu2.ab_drift  = xbow1.ab_drift ;
    imu2.gb_drift  = xbow1.gb_drift ;
    imu2.acorr = xbow1.acorr ;
    imu2.gcorr = xbow1.gcorr ;
    imu2.ab_fix  = xbow1.ab_fix ;
    imu2.gb_fix  = xbow1.gb_fix ;
    imu2.gpsd = xbow1.gb_n ;
    imu2.apsd = xbow1.ab_n ;
    imu2.freq   = floor(1/dt);
    
    fprintf('Generating imu2 ACCR data... \n')

    fb = acc_gen (ref_i2, imu2);
    
    fprintf('Generating imu2 GYRO data... \n')

    wb = gyro_gen (ref_i2, imu2);
    
    imu2.fb = fb;
    imu2.wb = wb;
    
    save imu2.mat imu2
    save ref_i2.mat ref_i2

    clear wb fb;

else
    fprintf('Loading imu2 data... \n')
    
    load imu2.mat 
    load ref_i2.mat
end

    
%% imu2/GPS INTEGRATION WITH FK

if strcmp(IMU2_SINS, 'ON')
    
    fprintf('SINS/GPS integration ... \n')
    
    % DEBUG
%     gps = novatel;
%     [ref_g2] = downsampling(ref, gps);

   % Sincronize GPS data with IMU data.
   % SINS must be executed before EKF at least once
    if (imu2.t(1) < gps.t(1)),    

        igx  = find(imu2.t > gps.t(1), 1, 'first' ); 
     
        imu2.t  = ( imu2.t  (igx:end, :) );
        imu2.fb = ( imu2.fb (igx:end, :) );
        imu2.wb = ( imu2.wb (igx:end, :) );
        
        ref_i2.t =    ( ref_i2.t     (igx:end, :) );
        ref_i2.roll = ( ref_i2.roll  (igx:end, :) );
        ref_i2.pitch =( ref_i2.pitch (igx:end, :) );
        ref_i2.yaw =  ( ref_i2.yaw (igx:end, :) );
        ref_i2.lat =  ( ref_i2.lat (igx:end, :) );
        ref_i2.lon =  ( ref_i2.lon (igx:end, :) );
        ref_i2.h =    ( ref_i2.h   (igx:end, :) );
        ref_i2.vel =  ( ref_i2.vel (igx:end, :) ); 
    end
    
    % SINS must provide data until last GPS measurement
    if (imu2.t(end) < gps.t(end)),   
        
        fgx  = find(gps.t < imu2.t(end), 1, 'last' );
        
        gps.t = gps.t(1:fgx, :);
        gps.lat = gps.lat(1:fgx, :);
        gps.lon = gps.lon(1:fgx, :);
        gps.h   = gps.h(1:fgx, :);    
        gps.vel = gps.vel(1:fgx, :);
        ref_g2.t   = ref_g2.t(1:fgx, :);
        ref_g2.lat = ref_g2.lat(1:fgx, :);
        ref_g2.lon = ref_g2.lon(1:fgx, :);
        ref_g2.h   = ref_g2.h(1:fgx, :);    
        ref_g2.vel = ref_g2.vel(1:fgx, :);  
    end 
    
    [imu2_e] = ins(imu2, gps, ref_i2, 'single');
    
    save imu2_e.mat imu2_e
    save ref_i2.mat ref_i2
%     fprintf('\n')    
else
    
    fprintf('Loading SINS/GPS sim. integration ... \n')
    load imu2_e.mat
    load ref_i2.mat 
end
  
%% Calculate RMSE

    fe = max(size(imu1_e.t));
    fr = max(size(ref_i1.t));

    % Adjust ref size if it is bigger than estimates
    if (fe < fr)

        ref_i1.t     = ref_i1.t(1:fe, :);
        ref_i1.roll  = ref_i1.roll(1:fe, :);
        ref_i1.pitch = ref_i1.pitch(1:fe, :);
        ref_i1.yaw   = ref_i1.yaw(1:fe, :);
        ref_i1.vel   = ref_i1.vel(1:fe, :);
        ref_i1.lat   = ref_i1.lat(1:fe, :);
        ref_i1.lon   = ref_i1.lon(1:fe, :);
        ref_i1.h     = ref_i1.h(1:fe, :);
        
    else
        
        imu1_e.t     = imu1_e.t(1:fr, :);
        imu1_e.roll  = imu1_e.roll(1:fr, :);
        imu1_e.pitch = imu1_e.pitch(1:fr, :);
        imu1_e.yaw   = imu1_e.yaw(1:fr, :);
        imu1_e.vel   = imu1_e.vel(1:fr, :);
        imu1_e.lat   = imu1_e.lat(1:fr, :);
        imu1_e.lon   = imu1_e.lon(1:fr, :);
        imu1_e.h     = imu1_e.h(1:fr, :);
    end
    
    
    fe = max(size(imu2_e.t));
    fr = max(size(ref_i2.t));

    % Adjust ref size if it is bigger than estimates
    if (fe < fr)

        ref_i2.t     = ref_i2.t(1:fe, :);
        ref_i2.roll  = ref_i2.roll(1:fe, :);
        ref_i2.pitch = ref_i2.pitch(1:fe, :);
        ref_i2.yaw   = ref_i2.yaw(1:fe, :);
        ref_i2.vel   = ref_i2.vel(1:fe, :);
        ref_i2.lat   = ref_i2.lat(1:fe, :);
        ref_i2.lon   = ref_i2.lon(1:fe, :);
        ref_i2.h     = ref_i2.h(1:fe, :);
        
    else
        
        imu2_e.t     = imu2_e.t(1:fr, :);
        imu2_e.roll  = imu2_e.roll(1:fr, :);
        imu2_e.pitch = imu2_e.pitch(1:fr, :);
        imu2_e.yaw   = imu2_e.yaw(1:fr, :);
        imu2_e.vel   = imu2_e.vel(1:fr, :);
        imu2_e.lat   = imu2_e.lat(1:fr, :);
        imu2_e.lon   = imu2_e.lon(1:fr, :);
        imu2_e.h     = imu2_e.h(1:fr, :);
    end
    

[RM,RN] = radius(ref_i1.lat);
lat2m = RM+ref_i1.h; 
lon2m = (RN+ref_i1.h).*cos(ref_i1.lat);         
    
RMSE_roll_1   = rmse (imu1_e.roll,    ref_i1.roll) .*r2d;
RMSE_pitch_1  = rmse (imu1_e.pitch,   ref_i1.pitch).*r2d;

idx = find ( abs(imu1_e.yaw - ref_i1.yaw) < pi );
RMSE_yaw_1    = rmse (imu1_e.yaw(idx),   ref_i1.yaw(idx)).*r2d;

RMSE_vn_1 = rmse (imu1_e.vel(:,1) ,   ref_i1.vel(:,1));
RMSE_ve_1 = rmse (imu1_e.vel(:,2) ,   ref_i1.vel(:,2));
RMSE_vd_1 = rmse (imu1_e.vel(:,3) ,   ref_i1.vel(:,3));
RMSE_lat_1  = rmse (imu1_e.lat.*lat2m,   ref_i1.lat.*lat2m);
RMSE_lon_1  = rmse (imu1_e.lon.*lon2m,   ref_i1.lon.*lon2m);
RMSE_h_1    = rmse (imu1_e.h,     ref_i1.h);

[RM,RN] = radius(ref_i2.lat);
lat2m = RM+ref_i2.h; 
lon2m = (RN+ref_i2.h).*cos(ref_i2.lat);  

RMSE_roll_2   = rmse (imu2_e.roll,    ref_i2.roll).*r2d;
RMSE_pitch_2  = rmse (imu2_e.pitch,   ref_i2.pitch).*r2d;

idx = find ( abs(imu2_e.yaw - ref_i2.yaw) < pi );
RMSE_yaw_2    = rmse (imu2_e.yaw(idx),   ref_i2.yaw(idx)).*r2d;

RMSE_vn_2 = rmse (imu2_e.vel(:,1) ,   ref_i2.vel(:,1));
RMSE_ve_2 = rmse (imu2_e.vel(:,2) ,   ref_i2.vel(:,2));
RMSE_vd_2 = rmse (imu2_e.vel(:,3) ,   ref_i2.vel(:,3));
RMSE_lat_2  = rmse (imu2_e.lat.*lat2m,ref_i2.lat.*lat2m);
RMSE_lon_2  = rmse (imu2_e.lon.*lon2m,ref_i2.lon.*lon2m);
RMSE_h_2    = rmse (imu2_e.h,         ref_i2.h);

[RM,RN] = radius(ref_g2.lat);
lat2m = RM+ref_g2.h; 
lon2m = (RN+ref_g2.h).*cos(ref_g2.lat);  
RMSE_lat_g  = rmse (gps.lat.*lat2m,      ref_g2.lat.*lat2m);
RMSE_lon_g  = rmse (gps.lon.*lon2m,      ref_g2.lon.*lon2m);
RMSE_h_g    = rmse (gps.h,               ref_g2.h);
RMSE_vn_g   = rmse (gps.vel(:,1) ,       ref_g2.vel(:,1));
RMSE_ve_g   = rmse (gps.vel(:,2) ,       ref_g2.vel(:,2));
RMSE_vd_g   = rmse (gps.vel(:,3) ,       ref_g2.vel(:,3));

rmse_data = [   RMSE_roll_1, RMSE_roll_2, ...
                RMSE_pitch_1,RMSE_pitch_2, ...  
                RMSE_yaw_1,  RMSE_yaw_2, ... 
                RMSE_vn_1 ,  RMSE_vn_2,   RMSE_vn_g,  ... 
                RMSE_ve_1,   RMSE_ve_2,   RMSE_ve_g,    ...
                RMSE_vd_1,   RMSE_vd_2,   RMSE_vd_g,  ...
                RMSE_lat_1,  RMSE_lat_2,  RMSE_lat_g,  ... 
                RMSE_lon_1,  RMSE_lon_2,  RMSE_lon_g, ... 
                RMSE_h_1,    RMSE_h_2,    RMSE_h_g;                      
            ];  

rmse_m(j,:) = rmse_data; 


end

% Delete variables
% imu1 = rmfield(imu1, {'wb','fb','t'});
% imu2 = rmfield(imu2, {'wb','fb','t'});
% gps = rmfield(gps, {'lat', 'lon', 'h', 'vel'});


%% Get RMSE

if strcmp(RMSE, 'ON')
    
    save rmse_m.mat rmse_m
else
    
    load rmse_m
end

[n,m] = size(rmse_m);

if (n == 1)
    rmse_data = (rmse_m);    
else
    rmse_data = mean(rmse_m);    
end

fprintf('\n\nRoot mean square errors (RMSE):\n');

fprintf(1, 'RMSE Roll \n');
fprintf(1, ' imu1 = %.4e [deg], imu2 = %.4e [deg]\n', ...
             rmse_data(1), rmse_data(2));
fprintf(1, 'RMSE Pitch \n');
fprintf(1, ' imu1 = %.4e [deg], imu2 = %.4e [deg]\n', ...
             rmse_data(3), rmse_data(4));
fprintf(1, 'RMSE Yaw \n');
fprintf(1, ' imu1 = %.4e [deg], imu2 = %.4e [deg]\n', ...
             rmse_data(5), rmse_data(6));
         
fprintf(1, '\nRMSE Vel. North \n');
fprintf(1, ' imu1 = %.4e [m], imu2 = %.4e [m], gps = %.4e [m]\n', ...
             rmse_data(7), rmse_data(8), rmse_data(9));
fprintf(1, 'RMSE Vel. East \n');
fprintf(1, ' imu1 = %.4e [m], imu2 = %.4e [m], gps = %.4e [m]\n', ...
             rmse_data(10), rmse_data(11), rmse_data(12));
fprintf(1, 'RMSE Vel. Down \n');
fprintf(1, ' imu1 = %.4e [m], imu2 = %.4e [m], gps = %.4e [m]\n', ...
             rmse_data(13), rmse_data(14), rmse_data(15));
         
fprintf(1, '\nRMSE Latitude \n');
fprintf(1, ' imu1 = %.4e [m], imu2 = %.4e [m], gps = %.4e [m]\n', ...
             rmse_data(16), rmse_data(17), rmse_data(18));
fprintf(1, 'RMSE Longitude \n');
fprintf(1, ' imu1 = %.4e [m], imu2 = %.4e [m], gps = %.4e [m]\n', ...
             rmse_data(19), rmse_data(20), rmse_data(21));
fprintf(1, 'RMSE Heigth \n');
fprintf(1, ' imu1 = %.4e [m], imu2 = %.4e [m], gps = %.4e [m]\n', ...
             rmse_data(22), rmse_data(23), rmse_data(24));
         
fid = fopen('xbow1.txt','w');
fprintf(fid,'%1.4f  %1.4f\n', rmse_data(1:6)');
fprintf(fid,'%1.4f  %1.4f  %1.4f\n', rmse_data(7:24)');
fclose(fid);

seg = ref.t(end)-ref.t(1);

fprintf('\nNavegation time: %4.0f hrs., %4.2f min. \n', seg/60/60, seg/60)
    
%% PLOT

if (strcmp(PLOT,'ON'))

sig31 = imu1_e.P_diag.^(0.5) .* 3;
sig32 = imu2_e.P_diag.^(0.5) .* 3; 

    % TRAJECTORY
%     figure; 
%     plot3(ref_i2.lon.*r2d, ref_i2.lat.*r2d, ref_i2.h, '-k', 'Linewidth',2)
%     axis tight
%     xlabel('Longitude [deg]') 
%     ylabel('Latitude [deg]')
%     zlabel('Height [m]')
%     grid
    
    % ATTITUDE
    msz = 2;
    figure;
    subplot(311)
    plot(ref_i1.t, r2d.*ref_i1.roll, '--k', imu1_e.t, r2d.*imu1_e.roll, '-b', imu2_e.t, r2d.*imu2_e.roll,'-r', 'Linewidth',1.5, 'MarkerSize',msz);
    ylabel('[deg]')
    xlabel('Time [s]')
    legend('True', 'imu1', 'imu2');
    title('ROLL');
    
    subplot(312)
    plot(ref_i1.t, r2d.*ref_i1.pitch, '--k', imu1_e.t, r2d.*imu1_e.pitch, '-b', imu2_e.t, r2d.*imu2_e.pitch,'-r', 'Linewidth', 1.5, 'MarkerSize',msz);
    ylabel('[deg]')
    xlabel('Time [s]')
    legend('True', 'imu1', 'imu2');
    title('PITCH');
    
    subplot(313)
    plot(ref.t, r2d.*ref.yaw, '--k', imu1_e.t, r2d.*imu1_e.yaw, '-b', imu2_e.t, r2d.*imu2_e.yaw,'-r', 'Linewidth',1.5 ,'MarkerSize',msz);
    ylabel('[deg]')
    xlabel('Time [s]')
    legend('True', 'imu1', 'imu2');
    title('YAW');
    
    % ATTITUDE ERRORS
    msz = 2;
    figure;
    subplot(311)
    plot(imu1_e.t, (imu1_e.roll-ref_i1.roll).*r2d, '-b', imu2_e.t, (imu2_e.roll-ref_i2.roll).*r2d, '-r', 'Linewidth',1.5, 'MarkerSize',msz);
    hold on
    plot (novatel.t, r2d.*sig31(:,1), '--b', novatel.t, -r2d.*sig31(:,1), '--b')
%     hold on
%     plot (gps.t, r2d.*sig32(:,1), '--r', gps.t, -r2d.*sig32(:,1), '--r')
    ylabel('[deg]')
    xlabel('Time [s]')
    legend('imu1', 'imu2');
    title('ROLL ERROR');
    
    subplot(312)
    plot(imu1_e.t, (imu1_e.pitch-ref_i1.pitch).*r2d, '-b', imu2_e.t, (imu2_e.pitch-ref_i2.pitch).*r2d, '-r', 'Linewidth',1.5, 'MarkerSize',msz);
    hold on
    plot (novatel.t, r2d.*sig31(:,2), '--b', novatel.t, -r2d.*sig31(:,2), '--b')
    hold on
%     plot (gps.t, r2d.*sig32(:,2), '--r', gps.t, -r2d.*sig32(:,2), '--r')
    ylabel('[deg]')
    xlabel('Time [s]')
    legend('imu1', 'imu2');
    title('PITCH ERROR');
    
    subplot(313)
    plot(imu1_e.t, (imu1_e.yaw-ref_i1.yaw).*r2d, '-b', imu2_e.t, (imu2_e.yaw-ref_i2.yaw).*r2d, '-r', 'Linewidth',1.5, 'MarkerSize',msz);
    hold on
    plot (novatel.t, r2d.*sig31(:,3), '--b', novatel.t, -r2d.*sig31(:,3), '--b')
    hold on
%     plot (gps.t, r2d.*sig32(:,3), '--r', gps.t, -r2d.*sig32(:,3), '--r')
    ylabel('[deg]')
    xlabel('Time [s]')
    legend('imu1', 'imu2');
    title('YAW ERROR');
    
    % VELOCITY
    figure;
    subplot(311)
    plot(gps.t, gps.vel(:,1), '.c', ref_i1.t, ref_i1.vel(:,1), '--k', imu1_e.t, imu1_e.vel(:,1), '-b', imu2_e.t, imu2_e.vel(:,1),'-r');
    xlabel('Time [s]')
    ylabel('[m/s]')
    legend('GPS', 'True', 'imu1', 'imu2');
    title('VELOCITY NORTH');
    
    subplot(312)
    plot(gps.t, gps.vel(:,2), '.c', ref_i1.t, ref_i1.vel(:,2), '--k', imu1_e.t, imu1_e.vel(:,2), '-b', imu2_e.t, imu2_e.vel(:,2),'-r');
    xlabel('Time [s]')
    ylabel('[m/s]')
    legend('GPS', 'True', 'imu1', 'imu2');
    title('VELOCITY EAST');
    
    subplot(313)
    plot(gps.t, gps.vel(:,3), '.c', ref_i1.t, ref_i1.vel(:,3), '--k', imu1_e.t, imu1_e.vel(:,3), '-b', imu2_e.t, imu2_e.vel(:,3),'-r');
    xlabel('Time [s]')
    ylabel('[m/s]')
    legend('GPS', 'True', 'imu1', 'imu2');
    title('VELOCITY DOWN');

    % VELOCITY ERRORS
    figure;
    subplot(311)
    plot(imu1_e.t, (imu1_e.vel(:,1) - ref_i1.vel(1:end,1)), '-b', imu2_e.t, (imu2_e.vel(:,1) - ref_i2.vel(1:end,1)), '-r')
    hold on
    plot (novatel.t, sig31(:,4), '--b', novatel.t, -sig31(:,4), '--b')
%     hold on
%     plot (gps.t, sig32(:,4), '--r', gps.t, -sig32(:,4), '--r')
    xlabel('Time [s]')
    ylabel('[m/s]')
    legend('GPS', 'imu1', 'imu2');
    title('VELOCITY NORTH ERROR');
    
    subplot(312)
    plot(imu1_e.t, (imu1_e.vel(:,2) - ref_i1.vel(1:end,2)), '-b', imu2_e.t, (imu2_e.vel(:,2) - ref_i2.vel(1:end,2)), '-r' );
    hold on
    plot (novatel.t, sig31(:,5), '--b', novatel.t, -sig31(:,5), '--b')
%     hold on
%     plot (gps.t, sig32(:,5), '--r', gps.t, -sig32(:,5), '--r')
    xlabel('Time [s]')
    ylabel('[m/s]')
    legend('GPS', 'imu1', 'imu2');
    title('VELOCITY EAST ERROR');
    
    subplot(313)
    plot(imu1_e.t, (imu1_e.vel(:,3) - ref_i1.vel(1:end,3)), '-b', imu2_e.t, (imu2_e.vel(:,3) - ref_i2.vel(1:end,3)), '-r' );
    hold on
    plot (novatel.t, sig31(:,6), '--b', novatel.t, -sig31(:,6), '--b')
%     hold on
%     plot (gps.t, sig32(:,6), '--r', gps.t, -sig32(:,6), '--r')
    xlabel('Time [s]')
    ylabel('[m/s]')
    legend('GPS', 'imu1', 'imu2');
    title('VELOCITY DOWN ERROR');
    
    % POSITION
    
    [RM,RN] = radius(gps.lat);
    lat2gm = RM+gps.h; 
    lon2gm = (RN + gps.h).*cos(gps.lat);  
    
    [RM,RN] = radius(novatel.lat);
    lat2gmt = RM+novatel.h; 
    lon2gmt = (RN + novatel.h).*cos(novatel.lat); 
    
    [RM,RN] = radius(ref_i2.lat);
    lat2m = RM +  ref_i2.h; 
    lon2m = (RN + ref_i2.h) .* cos(ref_i2.lat); 
    
    [RM,RN] = radius(ref_i1.lat);
    lat2mt = RM +  ref_i1.h; 
    lon2mt = (RN + ref_i1.h) .* cos(ref_i1.lat); 
    
    figure;
    subplot(311)
    plot(ref_i1.t, ref_i1.lat.*lat2mt, '--k', imu1_e.t, imu1_e.lat .*lat2mt, '-b', imu2_e.t, imu2_e.lat.*lat2m, '-r');
    xlabel('Time [s]')
    ylabel('[m]')
    legend('True','imu1', 'imu2');
    title('LATITUDE');

    subplot(312)
    plot( ref_i1.t, ref_i1.lon.*lat2mt, '--k', imu1_e.t, imu1_e.lon.*lon2mt, '-b', imu2_e.t, imu2_e.lon.*lon2m , '-r');
    xlabel('Time [s]')
    ylabel('[m]')
    legend('True','imu1', 'imu2');
    title('LONGITUDE');
    
    subplot(313)
    plot(ref_i1.t, ref_i1.h, '--k', imu1_e.t, imu1_e.h, '-b', imu2_e.t, imu2_e.h, '-r');
    xlabel('Time [s]')
    ylabel('[m]')
    legend('True','imu1', 'imu2');
    title('HEIGHT');
    

    % POSITION ERRORS
    figure;
    subplot(311)
    plot(imu1_e.t, (imu1_e.lat - ref_i1.lat ).*lat2mt, '-b',...
         imu2_e.t, (imu2_e.lat - ref_i2.lat) .*lat2m,  '-r' ); 
    hold on
    plot (novatel.t, sig31(:,7) .*lat2gmt, '--b', novatel.t, -sig31(:,7).*lat2gmt, '--b')
    hold on
    plot (gps.t, sig32(:,7) .*lat2gm, '--r', gps.t, -sig32(:,7).*lat2gm, '--r')
     xlabel('[s]')
    ylabel('[m]')
    legend('imu1', 'imu2');
    title('LATITUDE ERROR');
    
    subplot(312)
    plot(imu1_e.t, (imu1_e.lon - ref_i1.lon).*lon2mt, '-b',...
         imu2_e.t, (imu2_e.lon - ref_i2.lon).*lon2m, '-r' ); 
    hold on
    plot (novatel.t, sig31(:,8) .*lon2gmt, '--b', novatel.t, -sig31(:,8).*lon2gmt, '--b')
    hold on
    plot (gps.t, sig32(:,8) .*lon2gm, '--r', gps.t, -sig32(:,8).*lon2gm, '--r')
    xlabel('[s]')
    ylabel('[m]')
    legend('imu1', 'imu2');
    title('LONGITUDE ERROR');
    
    subplot(313)
    plot(imu1_e.t, (imu1_e.h - ref_i1.h), '-b',...
         imu2_e.t, (imu2_e.h - ref_i2.h), '-r' ); 
    hold on
    plot (novatel.t, sig31(:,9), '--b', novatel.t, -sig31(:,9), '--b')
    hold on
    plot (gps.t, sig32(:,9), '--r', gps.t, -sig32(:,9), '--r')     
    xlabel('[s]')
    ylabel('[m]')
    legend('imu1', 'imu2');
    title('HEIGHT ERROR');
end         