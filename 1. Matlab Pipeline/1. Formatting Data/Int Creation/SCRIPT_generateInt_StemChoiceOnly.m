%% SCRIPT_generateInt_StemChoiceOnly
%
% this code is meant for generation of the sequence cell on CA T-maze tasks. It
% provides a method to visualize all trials, then tag certain trials
% containing potential artifacts in the behavior that might interfere with
% analysis procedures. This code will find timestamps typically included in the
% Int file (stem entry, choice entry, goal arm entry) and will use them to generate a 
% Sequence Cell with timestamps, position data from the stem->goal arm entry, 
% and trial exclusion information.

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
taskType     = 'CA';
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
% i've shortened stem area to reduce accidental double trial occcurence,
% edit int_information for CA in the future
STM_fld(1)=250;
STM_fld(3)=220;
STM_fld(2)=220;
STM_fld(4)=60;
xv_stem = [STM_fld(1)+STM_fld(3) STM_fld(1) STM_fld(1) STM_fld(1)+STM_fld(3) STM_fld(1)+STM_fld(3)];
yv_stem = [STM_fld(2) STM_fld(2) STM_fld(2)+STM_fld(4) STM_fld(2)+STM_fld(4) STM_fld(2)];

% choice point
CP_fld(3)=100;
xv_cp = [CP_fld(1)+CP_fld(3) CP_fld(1) CP_fld(1) CP_fld(1)+CP_fld(3) CP_fld(1)+CP_fld(3)];
yv_cp = [CP_fld(2) CP_fld(2) CP_fld(2)+CP_fld(4) CP_fld(2)+CP_fld(4) CP_fld(2)];

% left reward field
xv_lr = [lRW_fld(1)+lRW_fld(3) lRW_fld(1) lRW_fld(1) lRW_fld(1)+lRW_fld(3) lRW_fld(1)+lRW_fld(3)];
yv_lr = [lRW_fld(2) lRW_fld(2) lRW_fld(2)+lRW_fld(4) lRW_fld(2)+lRW_fld(4) lRW_fld(2)];

% right reward field
xv_rr = [rRW_fld(1)+rRW_fld(3) rRW_fld(1) rRW_fld(1) rRW_fld(1)+rRW_fld(3) rRW_fld(1)+rRW_fld(3)];
yv_rr = [rRW_fld(2) rRW_fld(2) rRW_fld(2)+rRW_fld(4) rRW_fld(2)+rRW_fld(4) lRW_fld(2)];

% startbox
PED_fld(1)=470;
xv_sb = [PED_fld(1)+PED_fld(3) PED_fld(1) PED_fld(1) PED_fld(1)+PED_fld(3) PED_fld(1)+PED_fld(3)];
yv_sb = [PED_fld(2) PED_fld(2) PED_fld(2)+PED_fld(4) PED_fld(2)+PED_fld(4) lRW_fld(2)];

% figure; hold on;
% plot(x,y, 'Color',[.8 .8 .8])
% plot(xv_stem, yv_stem, 'Color', [0.6350 0.0780 0.1840], 'LineWidth', 1.5)
% plot(xv_cp, yv_cp, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5)
% plot(xv_lr, yv_lr, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5)
% plot(xv_rr, yv_rr, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5)
% plot(xv_sb, yv_sb, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5)

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
ga_entry  = []; % is choice point exit

whereWasRat = [];

for i = 2:numSamples-1

    % if the animal is in the stem, not in the choice, and whereWasRat is
    % undefined, then it is the very first trial
    if (in_stem(i) == 1 || on_stem(i) == 1) && in_cp(i) == 0  && isempty(whereWasRat)
        whereWasRat = 'stem';
        stem_entry = [stem_entry t(i)];
    end

    if in_stem(i) == 0 && on_stem(i) == 0 && (in_cp(i) == 1 || on_cp(i)==1) && ...
            contains(whereWasRat,'stem')
        whereWasRat = 'cp';
        cp_entry = [cp_entry t(i)];
    end

    % if the rat is not in the cp, is not in the stem, is not in the goal
    % fields, is not in the startbox, but his last position was in the
    % choice point
    if ~isempty(whereWasRat)
        if in_stem(i) == 0 && in_cp(i) == 0 && in_lr(i) == 0 && in_rr(i) == 0 && ...
                in_sb(i) == 0 && contains(whereWasRat,'cp')
            % store timestamp
            ga_entry = [ga_entry t(i)];
            % tracker
            whereWasRat = 'goalArm';
        end

        % now check for in stem
        if (in_stem(i) == 1 || on_stem(i) == 1) && in_cp(i) ==0 && on_cp(i) == 0 && contains(whereWasRat,'goalArm')
            stem_entry = [stem_entry t(i)];
            whereWasRat = 'stem';
        end
    end
end

%% create old Int file - ie Int file from 2006-2021
Int_old = zeros([length(stem_entry),3]);
% stem entry
Int_old(:,1) = stem_entry;
% cp
Int_old(:,2) = cp_entry;
% goal arm entry
Int_old(:,3) = ga_entry;

Int=[]; 
Int=Int_old;
   
%% New Int file (2021)
% define some variables for the table
trajNumber = (1:length(stem_entry))';
stemEntry  = stem_entry'; 
cpEntry    = cp_entry';
gaEntry    = ga_entry';

%% CHECK YOUR DATA!!!
[remStem2Choice] = checkInt_StemChoiceOnly(Int_old,x,y,t);
remStem2Choice(end+1)=1; %trial 1 should always be removed

% remove data selected by user
trackingErrorStem = zeros([size(Int_old,1) 1]);
trackingErrorStem(remStem2Choice)=1;

% convert logical
trackingErrorStem = logical(trackingErrorStem);

% ok to continue to sequence cell?
question=[];
question = 'Are you satisfied with the Int file and ready to create sequence cell? [Y/N] ';
answer   = input(question,'s');

if contains(answer,'Y') | contains(answer,'y')
    try
        cd(datafolder);

        % get trial specific data
        numTrials = size(Int_old,1);

        % identify and remove manually excluded data
        Int_old(trackingErrorStem,:) = NaN;

        % get data over trials
        pos = cell([1 size(Int_old,1)]);
        for triali = 1:size(Int_old,1)

            % only process the data if it exists
            try
                % get position around cp
                idx = [];
                idx = t>Int_old(triali,1) & t<Int_old(triali,3);
                pos{triali}(1,:) = x(idx);
                pos{triali}(2,:) = y(idx);
                pos{triali}(3,:) = t(idx);
            catch
                pos{triali} = [];
            end
        end

        % make a cell array out of the int data
        C = []; sequenceCell = []; IntC=[];
        IntC = [trajNumber,Int,trackingErrorStem];
        C = num2cell(IntC);
        sequenceCell = [{'trajNumber'},{'stemEntry'},{'cpEntry'},{'gaEntry'},{'trackingErrorStem'};C];

        % add new columns
        sequenceSize = size(sequenceCell);
        sequenceCell{1,sequenceSize(2)+1} = 'trialPosition';

        % add data
        sequenceCell(2:end,sequenceSize(2)+1) = pos;

        % information variable
        sequenceInfo.array = 'This is a cell array with various different kinds of variables for flexible addition of new information';
        sequenceInfo.pos = 'Position from the entire trial. Row 1 = X. Row 2 = Y. Row 3 = Timestamps';
        sequenceInfo.posSrate = 30; % hardcoded: check by numel(t)/((t(end)-t(1))/1e6);

        cd(datafolder);
        save('sequenceArray','sequenceCell','sequenceInfo');
    catch
        disp('Could not generate sequence array');
        %pause;
    end
    disp('Finished with session')
end

