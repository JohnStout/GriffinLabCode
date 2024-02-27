%% SCRIPT_generateInt
%
% this code is meant for generation of the Int file on T-maze tasks. It
% provides a method to visualize all trials, then tag certain trials
% containing potential artifacts in the behavior that might interfere with
% analysis procedures. This code also saves out a Table.

%% user parameters -- CHANGE ME --
% MAKE SURE THAT YOUR CURRENT FOLDER IS THE DATAFOLDER YOU WANT TO WORK
% WITH
disp('If you have poor tracking data, you will have poor estimations of things. ')
disp('Make sure your current directory is set to your datafolder of interest')
disp('Make sure you view the details of this script to make sure it matches what you want');
disp('Make sure you have an Int_information added to path or in your datafolder of interest')
disp('Please see the details of this code for help with generating Int_information');

% prep
clear;
datafolder   = pwd;
missing_data = 'exclude';
vt_name      = 'VT1.mat';
taskType     = 'DA';
load('Int_information')

% display information
disp(['Int parameters ']); disp(' ')
disp(['missing_data: ',missing_data])
disp(['task type: ',taskType])
    
%% pull in video tracking data
% meat
[x,y,t] = getVTdata(datafolder,missing_data,vt_name);

% number of position samples
numSamples = length(t);

%% define rectangles for all coordinates

% stem
xv_stem = [STM_fld(1)+STM_fld(3) STM_fld(1) STM_fld(1) STM_fld(1)+STM_fld(3) STM_fld(1)+STM_fld(3)];
yv_stem = [STM_fld(2) STM_fld(2) STM_fld(2)+STM_fld(4) STM_fld(2)+STM_fld(4) STM_fld(2)];

% choice point
xv_cp = [CP_fld(1)+CP_fld(3) CP_fld(1) CP_fld(1) CP_fld(1)+CP_fld(3) CP_fld(1)+CP_fld(3)];
yv_cp = [CP_fld(2) CP_fld(2) CP_fld(2)+CP_fld(4) CP_fld(2)+CP_fld(4) CP_fld(2)];

% left reward field
xv_lr = [lRW_fld(1)+lRW_fld(3) lRW_fld(1) lRW_fld(1) lRW_fld(1)+lRW_fld(3) lRW_fld(1)+lRW_fld(3)];
yv_lr = [lRW_fld(2) lRW_fld(2) lRW_fld(2)+lRW_fld(4) lRW_fld(2)+lRW_fld(4) lRW_fld(2)];

% right reward field
xv_rr = [rRW_fld(1)+rRW_fld(3) rRW_fld(1) rRW_fld(1) rRW_fld(1)+rRW_fld(3) rRW_fld(1)+rRW_fld(3)];
yv_rr = [rRW_fld(2) rRW_fld(2) rRW_fld(2)+rRW_fld(4) rRW_fld(2)+rRW_fld(4) lRW_fld(2)];

% startbox
xv_sb = [PED_fld(1)+PED_fld(3) PED_fld(1) PED_fld(1) PED_fld(1)+PED_fld(3) PED_fld(1)+PED_fld(3)];
yv_sb = [PED_fld(2) PED_fld(2) PED_fld(2)+PED_fld(4) PED_fld(2)+PED_fld(4) lRW_fld(2)];

%% identify where each sample in the position data belongs to

% stem 
[in_stem,on_stem] = inpolygon(x,y,xv_stem,yv_stem);

% choice point
[in_cp,on_cp] = inpolygon(x,y,xv_cp,yv_cp);

% left reward field 
[in_lr,on_lr] = inpolygon(x,y,xv_lr,yv_lr);

% right reward field 
[in_rr,on_rr] = inpolygon(x,y,xv_rr,yv_rr);

% startbox 
[in_sb,on_sb] = inpolygon(x,y,xv_sb,yv_sb);

%% loop across data, identify entry and exit points and get timestamps

% intialize some variables
stem_entry     = [];
cp_entry       = []; % is stem exit
goalArm_entry  = []; % is choice point exit
goalZone_entry = []; % is goal arm exit
retArm_entry   = []; % is goal field exit
startBox_entry = []; % is return arm exit
trajectory     = [];

whereWasRat = [];

for i = 2:numSamples-1

    % if the animal is in the stem, not in the choice, and whereWasRat is
    % undefined, then it is the very first trial
    if (in_stem(i) == 1 || on_stem(i) == 1) && in_cp(i) == 0  && isempty(whereWasRat)
        whereWasRat = 'stem';
        stem_entry = [stem_entry t(i)];
    end

    if in_stem(i) == 0 && on_stem(i) == 0 && (in_cp(i) == 1 || on_cp(i)==1)
        whereWasRat = 'cp';
        cp_entry = [cp_entry t(i)];
    end

    % if the rat is not in the cp, is not in the stem, is not in the goal
    % fields, is not in the startbox, but his last position was in the
    % choice point
    if in_stem(i) == 0 && in_cp(i) == 0 && in_lr(i) == 0 && in_rr(i) == 0 && ...
            in_sb(i) == 0 && contains(whereWasRat,'cp')
        % store timestamp
        goalArm_entry = [goalArm_entry t(i)];
        % tracker
        whereWasRat = 'goalArm';
    end

    % now check for in stem
    if in_stem(i) == 1 || on_stem(i) == 1 && in_cp ==0 && on_cp == 0 && contains(whereWasRat,'goalArm')
        stem_entry = [in_stem t(i)];
        whereWasRat = 'stem';
    end
end

%% create old Int file - ie Int file from 2006-2021
Int_old = zeros([length(stem_entry),8]);
% stem entry
Int_old(:,1) = stem_entry;
% cp
Int_old(:,5) = cp_entry;
% goal arm entry
Int_old(:,6) = goalArm_entry;
