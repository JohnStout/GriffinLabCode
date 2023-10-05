%% ADD A DESCRIPTION OF WHAT THIS CODE DOES
%{

This code does cool things. WHy is it important

%}
clear;

% Lets eventually change this dependency to automatically detect the
% MATLAB_M_files in the pipeline
% /GriffinLabCode/Experiment Control/R21/NetComDevelopmentPackage_v3.1.0/MATLAB_M-files
pathName = 'C:\Users\zgemzik\GriffinCode\Experiment Control\R21\NetComDevelopmentPackage_v3.1.0\MATLAB_M-files';
%serverName = '192.168.3.100'; %Dell Tower in room 153 IPv4 address
serverName = '192.168.3.100';
connect2netcom(pathName,serverName);

%% setup

% get cheetah objects to stream with
[succeeded, cheetahObjects, cheetahTypes] = NlxGetDASObjectsAndTypes; % gets cheetah objects and types
%[succeeded, cheetahReply] = NlxSendCommand('-StopAcquisition');    
%[succeeded, cheetahReply] = NlxSendCommand('-StartAcquisition');    

% open stream with video track data
NlxOpenStream('VT1'); %Open data stream of VT1(Video data)

% define startbox coordinates
minY = 180; addY = 330-minY;
minX = 540; addX = 675-minX;
SB_fld = [minX minY addX addY];

% this is required for the inpolygon function
XV_sb = [SB_fld(1)+SB_fld(3) SB_fld(1) SB_fld(1) SB_fld(1)+SB_fld(3) SB_fld(1)+SB_fld(3)];
YV_sb = [SB_fld(2) SB_fld(2) SB_fld(2)+SB_fld(4) SB_fld(2)+SB_fld(4) SB_fld(2)];

%% TEST ME
%{
tester_var = [];
for i = 1:10
    % pause for "i" seconds
    disp(['pausing for ',num2str(i),' second(s), then extracting data'])
    pause(i)

    % pull in real-time tracking data
    [succeeded,  timeStampArray, locationArray, ...
        extractedAngleArray, numRecordsReturned, numRecordsDropped ] = NlxGetNewVTData('VT1');
    Y = locationArray(2:2:length(locationArray));
    X = locationArray(1:2:length(locationArray));

    % save data
    tester_var(i) = length(X)/30;
end
figure; plot(1:10,tester_var); xlabel('time waited (sec)'); ylabel('length of data (in sec)')
title('does waiting x-seconds change y?')
%}

%% set up for trial types
numTrials = 40;

% DONT CHANGE FOR NOW
cut = 2;
numTrials_setup = numTrials/cut; % required for what is below

% run once
laser_delay_temp = cell([1 cut]);
for n = 1:cut
    redo = 1;
    while redo == 1
        % create possible laser and delay duration combos
        blue_short = repmat('Bs',[numTrials_setup/4 1]);
        blue_long  = repmat('Bl',[numTrials_setup/4 1]);
        red_short  = repmat('Rs',[numTrials_setup/4 1]);
        red_long   = repmat('Rl',[numTrials_setup/4 1]);  

        all  = [blue_short; blue_long; red_short; red_long];
        all_shuffled = all;
        for i = 1:1000
            % notice how it rewrites the both_shuffled variable
            all_shuffled = all_shuffled(randperm(numTrials_setup),:);
        end
        laser_delay_temp{n} = cellstr(all_shuffled);

        % no more than 3 turns in one direction
        idxBl = double(contains(laser_delay_temp{n},'Bl'));
        idxBs = double(contains(laser_delay_temp{n},'Bs'));
        idxRl = double(contains(laser_delay_temp{n},'Rl'));
        idxRs = double(contains(laser_delay_temp{n},'Rs'));   

        for i = 1:length(laser_delay_temp{n})-3
            if idxBl(i) == 1 && idxBl(i+1) == 1 && idxBl(i+2) == 1 && idxBl(i+3)==1
                redo = 1;
                break        
            elseif idxRl(i) == 1 && idxRl(i+1) == 1 && idxRl(i+2) == 1 && idxRl(i+3)==1
                redo = 1;
                break 
            elseif idxBs(i) == 1 && idxBs(i+1) == 1 && idxBs(i+2) == 1 && idxBs(i+3)==1
                redo = 1;
                break  
            elseif idxBl(i) == 1 && idxBl(i+1) == 1 && idxBl(i+2) == 1 && idxBl(i+3)==1
                redo = 1;
                break              
            else
                redo = 0;
            end
        end
    end
end

% concatenate arrays that contain trials that contain a controlled amount
% of laser types
laser_delay = [];
laser_delay = vertcat(laser_delay_temp{:});

%% checker
laserCheck = laser_delay(1:numTrials/cut);
check1 = numel(find(contains(laserCheck,'Rs')==1)) == numTrials_setup/4;
check2 = numel(find(contains(laserCheck,'Bs')==1)) == numTrials_setup/4;
check3 = numel(find(contains(laserCheck,'Rl')==1)) == numTrials_setup/4;
check4 = numel(find(contains(laserCheck,'Bl')==1)) == numTrials_setup/4;
if check1 ~= 1 || check2 ~= 1 || check3 ~= 1 || check4 ~= 1
    error('Something is wrong with number of laser types')
end

laserCheck = laser_delay(numTrials/cut+1:numTrials);
check1 = numel(find(contains(laserCheck,'Rs')==1)) == numTrials_setup/4;
check2 = numel(find(contains(laserCheck,'Bs')==1)) == numTrials_setup/4;
check3 = numel(find(contains(laserCheck,'Rl')==1)) == numTrials_setup/4;
check4 = numel(find(contains(laserCheck,'Bl')==1)) == numTrials_setup/4;
if check1 ~= 1 || check2 ~= 1 || check3 ~= 1 || check4 ~= 1
    error('Something is wrong with number of laser types')
end


% Set the testing day
question = 'Enter tesing condition [stem/goal/delay]: ';
testing   = input(question,'s');

if contains(testing,'stem') | contains(testing,'Stem') | contains(testing,'goal') | contains(testing,'Goal') 
    laser_delay = ['nS';laser_delay]; % for stem2cp and gb2return days, no laser on trial 1
    totalTrials = length(laser_delay); %set up trial number for loop over trials
elseif contains(testing,'delay') | contains(testing,'Delay')
    totalTrials = length(laser_delay)+1; %set up trial number for loop over trials (laser won't turn on until rat 
                                         %enters startbox at the end of trial 1 -- either way will end up w/ 41 trials) 
end

% No variable is defined here?
horzcat(num2cell((1:length(laser_delay))'), laser_delay) %copy delay order before starting

%% set up

% stem2cp: within each trial (minus first trial), when the rat breaks the
% stem ir beam, turn on laser. turn off laster when rat breaks chocie exit ir beam

% gb2return: within each trial (minus first trial), when the rat breaks
% the goalbox ir beam, turn on laser. turn off laser when rat enters sb 

% delay: within each trial, when the rat enters the startbox, and they just came
% from the return arm or the goal zone, turn on laser for a specific period
% of time

% parameters
short = 5; % seconds 10
long  = 10; % seconds 30

% for arduino
if exist("a") == 0
    % connect arduino
    a = arduino('COM4','Mega2560','Libraries','Adafruit\MotorShieldV2');
end

%Set up IR beams
%irArduino.stem = 'D4'; % define me *location in arduino 
irArduino.lRet = 'D6'; % define me: left return beam
irArduino.rRet = 'D8'; % define me: right return beam
irArduino.stem1 = 'D10'; % define me: stem start beam 
irArduino.lCP = 'D2'; % define me: left choice exit beam 
irArduino.rCP = 'D5'; % define me: right choice exit beam
irArduino.lGB = 'D13'; % define me: left goal entry beam
irArduino.rGB = 'D3'; % define me: right goal entry beam

% {
% quick test arduino
% for i = 1:10000000
%     readDigitalPin(a,irArduino.lGB)
% end
% }

%% Task

% variable prep.
trajectory_text = [];
accuracy_text   = [];
trajectory      = [];
accuracy        = [];

% automatically start recording
[succeeded, cheetahReply] = NlxSendCommand('-StartRecording');    
load gong.mat;
sound(y);
pause(5)

% start for loop
disp('Session begin...')
for triali = 1:totalTrials    
    next = 0;
    
    %enter the stem 
    while next == 0
        if readDigitalPin(a,irArduino.stem1) == 0
            % spit out a timestamp to cheetah
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "stemEntry" 102 2');
            disp('enter stem')

            % turn on laser (stem2cp days)
            if contains(testing,'stem') | contains(testing,'Stem')
                if contains(laser_delay{triali},'B') % blue laser
                    if contains(laser_delay{triali},'Bs')
                        disp('Trial Type Blue Short')
                    elseif contains(laser_delay{triali},'Bl')
                        disp('Trial Type Blue Long')
                    end

                    % trigger on Blue
                    NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 2'); % ON
                    [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "BlueON" 102 2');

                    next =1;

                elseif contains(laser_delay{triali},'R') %  red laser
                    if contains(laser_delay{triali},'Rs')
                        disp('Trial Type Red Short')
                    elseif contains(laser_delay{triali},'Rl')
                        disp('Trial Type Red Long')
                    end
                    
                    % trigger on Red
                    NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 2'); % ON
                    [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "RedON" 100 2');
                    
                    next = 1;
                    
                elseif contains(laser_delay{triali},'nS')
                    next = 1; %for ns trial, move on
                end

            % can also do something like this: elseif contains(testing,[{'goal'},{'Goal'}])
            elseif contains(testing,'goal') | contains(testing,'Goal') | contains(testing,'delay') | contains(testing,'Delay')
                next = 1; %for gb2return and delay days, do not turn on laser, move on
            end
        else
            next = 0;
        end
    end

    next = 0;

    % choice point exit
    while next == 0
        if readDigitalPin(a,irArduino.lCP) == 0 ||  readDigitalPin(a,irArduino.rCP) ==0
            if readDigitalPin(a,irArduino.lCP)==0
                % spit out a timestamp to cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "leftChoiceExit" 312 2');
                disp('exit left choice')
                
                % track the trajectory_text
                trajectory_text{triali} = 'L';
                trajectory(triali)      = 1;

                %  turn off laser (stem2cp days)
                if contains(testing,'stem') | contains(testing,'Stem')
                    if contains(laser_delay{triali},'B') %for blue laser
                        % trigger off Blue
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 0'); % OFF
                        [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "BlueOFF" 102 0');

                        next = 1;

                    elseif contains(laser_delay{triali},'R') % for red laser
                        % trigger off Red
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 0'); % OFF
                        [succeeded, ~] = NlxSendCommand('-PostEvent "RedOFF" 100 0');

                        next = 1;
                        
                    elseif contains(laser_delay{triali},'nS')
                        next = 1; %for ns trial
                    end
                elseif contains(testing,'goal') | contains(testing,'Goal') | contains(testing,'delay') | contains(testing,'Delay')
                    next = 1; %for gb2return and delay days, move on
                end

            elseif readDigitalPin(a,irArduino.rCP)==0
                % spit out a timestamp to cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "rightChoiceExit" 322 2');
                disp('exit right choice')

                % track the trajectory_text
                trajectory_text{triali} = 'R';
                trajectory(triali)      = 0;

                %  turn off laser (stem2cp days)
                if contains(testing,'stem') | contains(testing,'Stem')
                    if contains(laser_delay{triali},'B') %for blue laser                       
                        % trigger off Blue
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 0'); % OFF
                        [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "BlueOFF" 102 0');
                        
                        next = 1; % move on
                        
                    elseif contains(laser_delay{triali},'R') % for red laser                        
                        % trigger off Red
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 0'); % OFF
                        [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "RedOFF" 100 0');
                        
                        next = 1; %move on
                        
                    elseif contains(laser_delay{triali},'nS')
                        next = 1; %for ns trial
                    end
                elseif contains(testing,'goal') | contains(testing,'Goal') | contains(testing,'delay') | contains(testing,'Delay')
                    next = 1; %for gb2return and delay days, move on
                end
            end
        else
            next = 0;
        end
    end
    
    next = 0;
    % goal box entry
    while next == 0
        if readDigitalPin(a,irArduino.lGB) == 0 ||  readDigitalPin(a,irArduino.rGB) ==0
            if readDigitalPin(a,irArduino.lGB)==0
                % spit out a timestamp to cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "leftGoalEntry" 312 2');
                disp('enter left goal')
                
                % turn on laser (gb2return days)
                if contains(testing,'goal') | contains(testing,'Goal')
                    if contains(laser_delay{triali},'B') %for blue laser
                        if contains(laser_delay{triali},'Bs')
                            disp('Trial Type Blue Short')
                        elseif contains(laser_delay{triali},'Bl')
                            disp('Trial Type Blue Long')
                        end
                        
                        % trigger on Blue
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 2'); % ON
                        [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "BlueON" 102 2');
                        
                        next = 1; % move on
                        
                    elseif contains(laser_delay{triali},'R') % for red laser
                        if contains(laser_delay{triali},'Rs')
                            disp('Trial Type Red short')
                        elseif contains(laser_delay{triali},'Rl')
                            disp('Trial Type Red long')
                        end
                        
                        % trigger on Red
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 2'); % ON
                        [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "RedON" 100 2');
                        
                        next = 1; % move on
                        
                    elseif contains(laser_delay{triali},'nS')
                        next = 1; %for ns trial, move on
                    end
                elseif contains(testing,'stem') | contains(testing,'Stem') | contains(testing,'delay') | contains(testing,'Delay')
                    next = 1; % for stem and delay days, move on
                end
            elseif readDigitalPin(a,irArduino.rGB)==0
                % spit out a timestamp to cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "rightGoalEntry" 322 2');
                disp('enter right goal')
                
                % turn on laser (gb2return days)
                if contains(testing,'goal') | contains(testing,'Goal')
                    if contains(laser_delay{triali},'B') %for blue laser
                        if contains(laser_delay{triali},'Bs')
                            disp('Trial Type Blue short')
                        elseif contains(laser_delay{triali},'Bl')
                            disp('Trial Type Blue long')
                        end
                        
                        % trigger on Blue
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 2'); % ON
                        [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "BlueON" 102 2');
                        
                        next = 1; % move on
                        
                    elseif contains(laser_delay{triali},'R') % for red laser
                        if contains(laser_delay{triali},'Rs')
                            disp('Trial Type Red short')
                        elseif contains(laser_delay{triali},'Rl')
                            disp('Trial Type Red long')
                        end
                        
                        % trigger on Red
                        NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 2'); % ON
                        [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "RedON" 100 2');
                        
                        next = 1; % move on
                        
                    elseif contains(laser_delay{triali},'nS')
                        next = 1; %for ns trial
                    end
                elseif contains(testing,'stem') | contains(testing,'Stem') | contains(testing,'delay') | contains(testing,'Delay')
                    next = 1; %for stem and delay days, move on
                end
            end
        else
            next = 0;
        end
    end
    
    % enter a return arm
    next = 0;
    while next == 0
        if readDigitalPin(a,irArduino.lRet) == 0 ||  readDigitalPin(a,irArduino.rRet) ==0    
            
            if readDigitalPin(a,irArduino.lRet)==0
                disp('enter left return')
                
                % spit out a timestamp to cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "leftReturn" 312 2');  
                
            elseif readDigitalPin(a,irArduino.rRet)==0
                disp('enter right return')

                % spit out a timestamp to cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "rightReturn" 322 2');                   
            end
            
            % move on
            next = 1;
        else
            next = 0;
        end
    end
 
    % EMPTY the cache in cheetah
    [succeeded,  timeStampArray, locationArray, ...
        extractedAngleArray, numRecordsReturned, numRecordsDropped ] = NlxGetNewVTData('VT1');
    pause(0.50);
    
    % track position data to detect when they enter the startbox polygon
    % taken from davids code for delay
    next = 0;
    while next == 0
        
        % pull in real-time tracking data
        [succeeded,  timeStampArray, locationArray, ...
            extractedAngleArray, numRecordsReturned, numRecordsDropped ] = NlxGetNewVTData('VT1');
        Y = locationArray(2:2:length(locationArray));
        X = locationArray(1:2:length(locationArray));
        
        % use inpolygon to detect whether the rat in the location you wanted.
        % take average and median to be safe
        [IN_all,ON_all]   = inpolygon(mean(X),mean(Y),XV_sb,YV_sb);
        [IN2_all,ON2_all] = inpolygon(double(median(X)),double(median(Y)), XV_sb,YV_sb);
        
        % if the rat is in or on the polygon (on average or based on median),
        % break out of the while loop as the rat is in the delay, and begin the
        % next part of the for loop - laser stim
        if IN_all == 1 || ON_all == 1 || IN2_all == 1 || ON2_all == 1
            next = 1;
        elseif IN_all == 0 || ON_all == 0 && IN2_all == 0 || ON2_all == 0
            next = 0;
        end
    end

    % spit out a timestamp to cheetah
    [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "sbReturn" 322 2');
    disp('enter start box')
    
    % MAKE sure to build in cheetah communication to communicate which kind
    % of trial so you can easily extract lfp from those trials
    % start laser protocol
    % pause(1);
    %turn off laser
    if contains(testing,'goal') | contains(testing,'Goal')
        if contains(laser_delay{triali},'B')
            % trigger off Blue
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 0'); % OFF
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "BlueOFF" 102 2');
        elseif contains(laser_delay{triali},'R')
            % trigger off Red
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 0'); % OFF
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "RedOFF" 100 0');
        end
        
    elseif contains(testing,'delay') | contains(testing,'Delay')
        if contains(laser_delay{triali},'Bs')
            disp('Trial Type Blue Short')
            % trigger on and off Blue
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 2'); % ON
            pause(short); % PAUSE FOR SHORT DURATION
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 0'); % OFF
        elseif contains(laser_delay{triali},'Bl')
            disp('Trial Type Blue Long')
            % trigger on and off Blue
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 2'); % ON
            pause(long); % PAUSE FOR LONG DURATION
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 2 0'); % OFF
        elseif contains(laser_delay{triali},'Rs')
            disp('Trial Type Red Short')
            % trigger on and off Red
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 2'); % ON
            pause(short); % PAUSE FOR SHORT DURATION
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 0'); % OFF
        elseif contains(laser_delay{triali},'Rl')
            disp('Trial Type Red Long')
            % trigger on and off Red
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 2'); % ON
            pause(long); % PAUSE FOR LONG DURATION
            NlxSendCommand('-SetDigitalIOPortValue AcqSystem1_0 0 0'); % OFF
        end
    elseif contains(testing,'stem') | contains(testing,'Stem')
        disp(['Finished with trial ' num2str(triali)])
        continue
    end

    % interface
    disp(['Finished with trial ' num2str(triali)])
    
end

% session end
load handel.mat;
sound(y, 2*Fs);

% compute accuracy array
accuracy = [];
accuracy_text = cell(1, length(trajectory_text)-1);
for triali = 1:length(trajectory_text)-1
    if trajectory_text{triali} ~= trajectory_text{triali+1}
        accuracy(triali) = 0; % correct trial
        accuracy_text{triali} = 'correct';
    elseif trajectory_text{triali} == trajectory_text{triali+1}
        accuracy(triali) = 1; % incorrect trial
        accuracy_text{triali} = 'incorrect';
    end
end

%% save data
% save data
c = clock;
c_save = strcat(num2str(c(2)),'_',num2str(c(3)),'_',num2str(c(1)),'_','EndTime',num2str(c(4)),num2str(c(5)));

prompt   = 'Please enter the rats name ';
rat_name = input(prompt,'s');

prompt   = 'Please enter the task ';
task_name = input(prompt,'s');

prompt   = 'Enter the directory to save the data ';
dir_name = input(prompt,'s');

save_var = strcat(rat_name,'_',task_name,'_',c_save);

cd('C:\Users\zgemzik\Desktop\Hailey_Testing_matllab_saved_variables'); %%INSERT DIRECTORY HERE
save(save_var);
