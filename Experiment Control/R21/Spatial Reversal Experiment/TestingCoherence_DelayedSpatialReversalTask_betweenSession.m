%% prep 1 - clear history, workspace, get working directory
% _____________________________________________________

% --- MAKE SURE YOU RUN STARTUP_EXPERIMENTCONTROL --- %

%______________________________________________________

%% 
% sometimes if the session is not exceeding the time limit of 30 minutes,
% then the code will continue performing trials, but not save the data.
% Cheetah w%%

% clear/clc
clear; clc

% get directory that houses this code
codeDir = getCurrentPath();
addpath(codeDir)

%% confirm this is the correct code
prompt = ['What is your rats name? '];
targetRat = input(prompt,'s');
prompt   = ['Confirm that your rat is ' targetRat,' [y/Y OR n/N] '];
confirm  = input(prompt,'s');
if ~contains(confirm,[{'y'} {'Y'}])
    error('This code does not match the target rat')
end

prompt = ['Is today testing or a reset day? enter "E" or "R" '];
testingType = input(prompt,'s');
prompt     = ['copy/paste the datafolder of the previous days testing session with the MATLAB data saved: '];
datafolder = input(prompt,'s');
prompt     = ['copy/paste the title of the previous days MATLAB data saved out: '];
data2load  = input(prompt,'s'); 
cd(datafolder);
prevTrajData = load(data2load,'traj');
prevTraj = prevTrajData.traj; 
clear traj

% randomize MW and BW, then use previous days to offset
numTrials = 10*20;
maxDelay = 30;
minDelay = 5;
rng('shuffle')
delayLenTrial = [];
next = 0;
while next == 0

    if numel(delayLenTrial) >= numTrials
        next = 1;
    else
        shortDuration  = randsample(minDelay:15,6,'true');
        longDuration   = randsample(16:maxDelay,6,'true');

        % used for troubleshooting ->
        %shortDuration  = randsample(1:5,5,'true');
        %longDuration   = randsample(6:10,5,'true');        

        allDurations   = [shortDuration longDuration];
        interleaved    = allDurations(randperm(length(allDurations)));
        delayLenTrial = [delayLenTrial interleaved];
    end
end  

if contains(prevTraj,'R')
    traj='L';
elseif contains(prevTraj,'L')
    traj='R';
end    

% half trials high coh, half control
indicatorOUT = [];
for i = 1:10:numTrials
    delays2pull = delayLenTrial(i:i+9);
    numExp = length(delays2pull)/2;
    numCon = length(delays2pull)/2;
    totalN = numExp+numCon;

    % high and low must happen before yoked
    next = 0;
    while next == 0
        idx = randperm(10,totalN);
        idx1 = randsample(idx,numExp);
        idx2 = randsample(idx,numCon);
        if idx1 < idx2 & numel(unique([idx1,idx2]))==8
            next = 1;
        end
    end

    % first is always high, second low, third, con h, 4 con L
    %indicator = cellstr(repmat('Norm',[12 1]));

    % now replace
    indicator(idx1) = {'high'};
    indicator(idx2) = {'contH'};

    % store indicator variable
    indicatorOUT = horzcat(indicatorOUT,indicator);

end      

% load in thresholds
disp('Getting rat-specific data')
cd(['X:\01.Experiments\R21\',targetRat,'\thresholds']);
load('thresholds');
cd(['X:\01.Experiments\R21\',targetRat,'\baseline']);
load('baselineData');
cd(['X:\01.Experiments\R21\',targetRat]);
%load('SRT_testingDays')
%testingDay = testingConditions(dayTesting);

% interface with cheetah setup
threshold.coh_duration = 0.5;
[srate,timing] = realTimeDetect_setup(LFP1name,LFP2name,threshold.coh_duration);    

if srate > 2035 || srate < 2000
    error('Sampling rate is not correct')
end

%% auto maze prep.

% -- automaze set up -- %

% check port
if exist("s") == 0
    % connect to the serial port making an object
    s = serialport("COM6",19200);
end

% load in door functions
doorFuns = DoorActions;

% test reward wells
rewFuns = RewardActions;

% get IR information
irBreakNames = irBreakLabels;

% for arduino
if exist("a") == 0
    % connect arduino
    a = arduino('COM5','Uno','Libraries','Adafruit\MotorShieldV2');
end

% digital ports for reverse maze
irArduino.Delay       = 'D8';
irArduino.rGoalArm    = 'D10';
irArduino.lGoalArm    = 'D12';
irArduino.rGoalZone   = 'D7';
irArduino.lGoalZone   = 'D2';
irArduino.choicePoint = 'D6';

%{
for i = 1:10000000
    readDigitalPin(a,irArduino.choicePoint)
end
%}
%writeline(s,doorFuns.tRightClose)

%% coherence and real-time LFP extraction parameters

% define pauseTime as 250ms and windowDuration as 1.25 seconds
pauseTime      = 0.25;
windowDuration = 1.25;

% Need to approximate idealized window lengths and true window lengths
% clear stream   
clearStream(LFP1name,LFP2name);
pause(windowDuration)
[succeeded, dataArray, timeStampArray, ~, ~, ...
numValidSamplesArray, numRecordsReturned, numRecordsDropped , funDur.getData ] = NlxGetNewCSCData_2signals(LFP1name, LFP2name);  

% choose numOver - because the code isn't zero lag, there is some timeloss.
% Account for it
windowLength  = srate*windowDuration;    
trueWinLength = length(dataArray);
timeLoss      = trueWinLength-windowLength;
windowStep    = (srate*pauseTime)+timeLoss;

% initialize some variables
dataWin      = [];
cohAvg_data  = [];
coh          = [];

% prep for coherence
window = []; noverlap = []; 
fpass = [1:.5:20];
deltaRange = [1 4];
thetaRange = [6 11];

actualDataDuration = [];
time2cohAndSend = [];

% define a noise threshold in standard deviations
noiseThreshold = 4;
% define how much noise you're willing to accept
noisePercent = 1; % 5 percent

%% clean the stored data just in case IR beams were broken
s.Timeout = 1; % 1 second timeout

% close all maze doors - this gives problems with solenoid box
pause(0.25)
writeline(s,[doorFuns.centralClose doorFuns.sbLeftClose ...
    doorFuns.sbRightClose doorFuns.tLeftClose doorFuns.tRightClose]);

pause(0.25)
writeline(s,[doorFuns.gzLeftClose doorFuns.gzRightClose])

%% interface with cheetah
% downloaded location of github code - automate for github
github_download_directory = 'C:\Users\jstout\Documents\GitHub\NeuroCode\MATLAB Code\R21';
addpath(github_download_directory);

% connect to netcom - automate this for github
pathName   = 'C:\Users\jstout\Documents\GitHub\NeuroCode\MATLAB Code\R21\NetComDevelopmentPackage_v3.1.0\MATLAB_M-files';
serverName = '192.168.3.100';
connect2netcom(pathName,serverName)

% open a stream to interface with Nlx objects - this is required
[succeeded, cheetahObjects, cheetahTypes] = NlxGetDASObjectsAndTypes; % gets cheetah objects and types

%% start recording - make a noise when recording begins
[succeeded, reply] = NlxSendCommand('-StartRecording');
load gong.mat;
sound(y);
pause(5)

%% trials
open_t  = [doorFuns.tLeftOpen doorFuns.tRightOpen];
close_t = [doorFuns.tLeftClose doorFuns.tRightClose];
maze_prep = [doorFuns.sbLeftOpen doorFuns.sbRightOpen ...
    doorFuns.tRightClose doorFuns.tLeftClose doorFuns.centralOpen ...
    doorFuns.gzLeftClose doorFuns.gzRightClose];

% mark session start
sStart = [];
sStart = tic;
sessEnd = 0;

c = clock;
session_start = str2num(strcat(num2str(c(4)),num2str(c(5))));
session_time  = session_start-session_start; % quick definitio of this so it starts the while loop

% neuralynx timestamp command
[succeeded, cheetahReply] = NlxSendCommand('-PostEvent "SessionStart" 700 3');
writeline(s,doorFuns.centralOpen);

% neuralynx timestamp command
[succeeded, cheetahReply] = NlxSendCommand('-PostEvent "TrialStart" 700 2');
 
% make this array ready to track amount of time spent at choice
time2choice = []; numRev = traj; detected = [];
coh = []; dataClean = []; dataDirty = []; % important to initiate these variables
yokH = []; yokL = []; critMet = 0; trialMet = [];
for triali = 1:numTrials    
    disp(['Rewarded Trajectory: ',traj])
    trajRewarded{triali} = traj;

    % break out when the rat has performed 10 trials past criterion
    if isempty(trialMet)==0 || (toc(sStart)/60) > 30
        if (triali-trialMet) > 10 || (toc(sStart)/60) > 30
            break % break out of for loop
        end      
    end

    % set central door timeout value
    s.Timeout = .05; % 5 minutes before matlab stops looking for an IR break    

    % first trial - set up the maze doors appropriately
    writeline(s,[doorFuns.sbRightOpen doorFuns.sbLeftOpen doorFuns.centralOpen]);
    
    % set irTemp to empty matrix
    irTemp = []; 

    % t-beam
    
    %disp('Tracking choice-time')
    disp('Choice-entry')
    tEntry = [];
    tEntry = tic;
    
    next = 0;
    while next == 0
        if readDigitalPin(a,irArduino.choicePoint) == 0   % if central beam is broken
            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "CPentry" 202 2');
            next = 1; % break out of the loop
        end
    end    
    
    % check which direction the rat turns at the T-junction
    next = 0;
    while next == 0
        if readDigitalPin(a,irArduino.rGoalArm)==0
            disp(['Chosen Trajectory: L'])

            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "CPexit" 202 2');
            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "Left" 312 2');
            
            % track the trajectory_text
            time2choice(triali) = toc(tEntry); % amount of time it took to make a decision
            trajectory_text{triali} = 'L';
            trajectory(triali)      = 0;            
            
            %pause(1);
            % Reward zone and eating
            % send to netcom 
            if contains(traj,'L')
                writeline(s,rewFuns.right)
            end
            
            pause(5)
            writeline(s,[doorFuns.gzRightOpen doorFuns.gzLeftOpen doorFuns.sbRightClose doorFuns.sbLeftClose doorFuns.tLeftClose doorFuns.tRightOpen]);
            %pause(5)
            %writeline(s,[doorFuns.gzRightOpen doorFuns.gzLeftOpen doorFuns.sbRightClose doorFuns.sbLeftClose doorFuns.tLeftClose doorFuns.tRightOpen]);

            % break while loop
            next = 1;

        elseif readDigitalPin(a,irArduino.lGoalArm)==0
             disp(['Chosen Trajectory: R'])

            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "CPexit" 202 2');
            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "Right" 322 2');
            
            % track the trajectory_text
            time2choice(triali) = toc(tEntry); % amount of time it took to make a decision
            trajectory_text{triali} = 'R';
            trajectory(triali)      = 1;            
            
            %pause(1);
            % Reward zone and eating
            % send to netcom 
            if contains(traj,'R')
                writeline(s,rewFuns.left)
            end             

            pause(5)
            writeline(s,[doorFuns.gzRightOpen doorFuns.gzLeftOpen doorFuns.sbRightClose doorFuns.sbLeftClose doorFuns.tRightClose doorFuns.tLeftOpen]);
           % pause(5)
            %writeline(s,[doorFuns.gzRightOpen doorFuns.gzLeftOpen doorFuns.sbRightClose doorFuns.sbLeftClose doorFuns.tRightClose doorFuns.tLeftOpen]);

            % break out of while loop
            next = 1;
        end
    end 
    
    % identify choice accuracy on last 10 trials
    if length(trajectory_text) >= 10 && critMet == 0
        if contains(traj,'R')
            % temp var
            tempVar = []; propCorrect = [];
            tempVar = trajectory_text(end-9:end);
            % find proportion of correct choices
            propCorrect = nanmean(contains(tempVar,'R'));
        elseif contains(traj,'L')
            % temp var
            tempVar = []; propCorrect = [];
            tempVar = trajectory_text(end-9:end);
            % find proportion of correct choices
            propCorrect = nanmean(contains(tempVar,'L'));
        end

        % once rats reach 80%, have them execute the rule for 10 additional
        % trials?
        if propCorrect >= 0.8
            critMet  = 1; % tag for criterion met
            trialMet = triali;
        end
        disp(['Proportion correct: ',num2str(propCorrect)])
    end

    % return arm
    next = 0;
    while next == 0
        
        if readDigitalPin(a,irArduino.lGoalZone) == 0
            
            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "ReturnRight" 422 2');
            
            % close both for audio symmetry and do opposite doors first
            % with a slightly longer delay so the rats can have a fraction
            % of time longer to enter
            %pause(0.5)
            pause(0.5)
            writeline(s,[doorFuns.gzRightClose])
            pause(0.25)
            writeline(s,[doorFuns.gzLeftClose])
            pause(0.25)
            writeline(s,[doorFuns.sbLeftOpen doorFuns.sbRightOpen]);
            pause(0.25)
            writeline(s,[doorFuns.sbLeftOpen doorFuns.sbRightOpen]); 
            
            next = 1;
            
        elseif readDigitalPin(a,irArduino.rGoalZone) == 0

            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "ReturnLeft" 412 2');            
            
            % close both for audio symmetry
            pause(0.5)
            writeline(s,[doorFuns.gzLeftClose])
            pause(0.25)
            writeline(s,[doorFuns.gzRightClose])
            pause(0.25)
            writeline(s,[doorFuns.sbLeftOpen doorFuns.sbRightOpen]);
            pause(0.25)
            writeline(s,[doorFuns.sbLeftOpen doorFuns.sbRightOpen]);            

            next = 1;
        end
    end
    writeline(s,doorFuns.centralClose);  
   
    next = 0;
    while next == 0   
        % track choice entry
        if readDigitalPin(a,irArduino.Delay)==0 
            disp('DelayEntry')
            % neuralynx timestamp command
            [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "DelayEntry" 102 2');  
            writeline(s,[doorFuns.tLeftClose doorFuns.tRightClose])
            next = 1;
        end
    end
   
    % break out when the rat has performed 10 trials past criterion
    if isempty(trialMet)==0 || (toc(sStart)/60) > 30
        if (triali-trialMet) > 10 || (toc(sStart)/60) > 30
            break % break out of for loop
        end      
    end
    
    % the meat
    if contains(indicatorOUT{triali},'high')
        dStart = [];
        dStart = tic;        
        pause(3.5);
        for i = 1:1000000000 % nearly infinite loop. This is needed for the first loop

            if i == 1
                clearStream(LFP1name,LFP2name);
                pause(windowDuration)
                [succeeded, dataArray, timeStampArray, ~, ~, ...
                numValidSamplesArray, numRecordsReturned, numRecordsDropped , funDur.getData ] = NlxGetNewCSCData_2signals(LFP1name, LFP2name);  

                % 2) store the data
                % now add and remove data to move the window
                dataWin    = dataArray;
            end

            % 3) pull in 0.25 seconds of data
            % pull in data at shorter resolution   
            pause(pauseTime)
            [succeeded, dataArray, timeStampArray, ~, ~, ...
            numValidSamplesArray, numRecordsReturned, numRecordsDropped , funDur.getData ] = NlxGetNewCSCData_2signals(LFP1name, LFP2name);  

            % 4) apply it to the initial array, remove what was there
            dataWin(:,1:length(dataArray))=[]; % remove 560 samples
            dataWin = [dataWin dataArray]; % add data

            % detrend by removing third degree polynomial
            data_det=[];
            data_det(1,:) = detrend(dataWin(1,:),3);
            data_det(2,:) = detrend(dataWin(2,:),3);

            % calculate coherence
            coh = [];
            [coh,f] = mscohere(data_det(1,:),data_det(2,:),window,noverlap,fpass,srate);

            % perform logical indexing of theta and delta ranges to improve
            % performance speed
            %cohAvg   = nanmean(coh(f > thetaRange(1) & f < thetaRange(2)));
            cohDelta = nanmean(coh(f > deltaRange(1) & f < deltaRange(2)));
            cohTheta = nanmean(coh(f > thetaRange(1) & f < thetaRange(2)));

            % determine if data is noisy
            zArtifact = [];
            zArtifact(1,:) = ((data_det(1,:)-baselineMean(1))./baselineSTD(1));
            zArtifact(2,:) = ((data_det(2,:)-baselineMean(2))./baselineSTD(2));
            idxNoise = find(zArtifact(1,:) > noiseThreshold | zArtifact(1,:) < -1*noiseThreshold | zArtifact(2,:) > noiseThreshold | zArtifact(2,:) < -1*noiseThreshold );
            percSat = (length(idxNoise)/length(zArtifact))*100;                
            
            % only include if theta coherence is higher than delta. Reject
            % if delta is greater than theta or if saturation exceeds
            % threshold
            if cohDelta > cohTheta || percSat > noisePercent
                detected{triali}(i)=1;
                rejected = 1;
                %disp('Rejected')  
            % accept if theta > delta and if minimal saturation
            elseif cohTheta > cohDelta && percSat < noisePercent
                rejected = 0;
                detected{triali}(i)=0;
            end

            % store data
            dataZStored{triali}{i} = zArtifact;
            dataStored{triali}{i}  = dataWin;
            cohOUT{triali}{i}      = coh;

            % if coherence is higher than your threshold, and the data is
            % accepted, then let the rat make a choice
            if cohTheta > cohHighThreshold && rejected == 0
                met_high = 1;
                indicatorOUT{triali} = 'highMET';                
                break 
            % if you exceed 30s, break out
            elseif toc(dStart) > maxDelay
                met_high = 0;
                indicatorOUT{triali} = 'highFAIL'; 
                break
            end  
        end

        % IMPORTANT: Storing this for later
        cohEnd = toc(dStart);
        disp(['Coh detect high end at ', num2str(cohEnd)])

        % now replace the delayLenTrial with coherence delay
        %delayLenTrial(triali) = cohEnd;
   
        % now identify yoked high, and replace with control delay        
        if met_high == 1
            % if coherence was met, replace the delay trial time with the
            % amount of time it took to finish the delay
            delayLenTrial(triali) = cohEnd; 
            yokH = [yokH cohEnd];
        elseif met_high == 0
            % if coherence wasn't met, replace the next yokeH with a 'Norm'
            % replace the next high with a 'norm'
            delayLenTrial(triali) = cohEnd; 
            idxRem = find(contains(indicatorOUT,'contH')==1);
            indicatorOUT{idxRem(1)}='NormHighFail';
        end
        
            %yokH = [yokH NaN];
        
    elseif contains(indicatorOUT{triali},'low')
        dStart = [];
        dStart = tic;
        pause(3.5);        
        for i = 1:1000000000 % nearly infinite loop. This is needed for the first loop

            if i == 1
                clearStream(LFP1name,LFP2name);
                pause(windowDuration)
                [succeeded, dataArray, timeStampArray, ~, ~, ...
                numValidSamplesArray, numRecordsReturned, numRecordsDropped , funDur.getData ] = NlxGetNewCSCData_2signals(LFP1name, LFP2name);  

                % 2) store the data
                % now add and remove data to move the window
                dataWin    = dataArray;
            end

            % 3) pull in 0.25 seconds of data
            % pull in data at shorter resolution   
            pause(pauseTime)
            [succeeded, dataArray, timeStampArray, ~, ~, ...
            numValidSamplesArray, numRecordsReturned, numRecordsDropped , funDur.getData ] = NlxGetNewCSCData_2signals(LFP1name, LFP2name);  

            % 4) apply it to the initial array, remove what was there
            dataWin(:,1:length(dataArray))=[]; % remove 560 samples
            dataWin = [dataWin dataArray]; % add data

            % detrend by removing third degree polynomial
            data_det=[];
            data_det(1,:) = detrend(dataWin(1,:),3);
            data_det(2,:) = detrend(dataWin(2,:),3);

            % calculate coherence
            coh = [];
            [coh,f] = mscohere(data_det(1,:),data_det(2,:),window,noverlap,fpass,srate);

            % identify theta > delta or delta > theta
            % take averages
            %thetaIdx = find(f > thetaRange(1) & f < thetaRange(2));
            %thetaIdx = find(f > thetaRange(1) & f < thetaRange(2));
            
            % perform logical indexing of theta and delta ranges to improve
            % performance speed
            %cohAvg   = nanmean(coh(f > thetaRange(1) & f < thetaRange(2)));
            cohDelta = nanmean(coh(f > deltaRange(1) & f < deltaRange(2)));
            cohTheta = nanmean(coh(f > thetaRange(1) & f < thetaRange(2)));

            % determine if data is noisy
            zArtifact = [];
            zArtifact(1,:) = ((data_det(1,:)-baselineMean(1))./baselineSTD(1));
            zArtifact(2,:) = ((data_det(2,:)-baselineMean(2))./baselineSTD(2));

            idxNoise = find(zArtifact(1,:) > noiseThreshold | zArtifact(1,:) < -1*noiseThreshold | zArtifact(2,:) > noiseThreshold | zArtifact(2,:) < -1*noiseThreshold );
            percSat = (length(idxNoise)/length(zArtifact))*100;                
            
            % only include if theta coherence is higher than delta. Reject
            % if delta is greater than theta or if saturation exceeds
            % threshold
            if cohDelta > cohTheta || percSat > noisePercent
                detected{triali}(i)=1;
                rejected = 1;
                %disp('Rejected')  
            % accept if theta > delta and if minimal saturation
            elseif cohTheta > cohDelta && percSat < noisePercent
                rejected = 0;
                detected{triali}(i)=0;
            end            

            % store data
            dataZStored{triali}{i} = zArtifact;
            dataStored{triali}{i}  = dataWin;
            cohOUT{triali}{i}      = coh;

            % if coherence is less than your threshold, and the data is
            % accepted, then let the rat make a choice
            if cohTheta < cohLowThreshold && rejected == 0
                %writeline(s,[doorFuns.sbRightOpen doorFuns.sbLeftOpen doorFuns.centralOpen]); 
                met_low = 1;
                indicatorOUT{triali} = 'lowMET';
                break
            % if you exceed 30s, break out
            elseif toc(dStart) > maxDelay
                met_low = 0;
                indicatorOUT{triali} = 'lowFAIL';
                break
            end
                
        end
        
        % IMPORTANT: Storing this for later
        cohEnd = toc(dStart);
        disp(['Coh detect low end at ', num2str(cohEnd)])

        % now replace the delayLenTrial with coherence delay
        %delayLenTrial(triali) = cohEnd;
   
        % now identify yoked high, and replace with control delay
        if met_low == 1
            % if coherence was met, replace the delay trial time with the
            % amount of time it took to finish the delay
            delayLenTrial(triali) = cohEnd; 
            yokL = [yokL cohEnd];
        elseif met_low == 0
            % if coherence wasn't met, replace the next yokeH with a 'Norm'
            % replace the next high with a 'norm'
            delayLenTrial(triali) = cohEnd; 
            idxRem = find(contains(indicatorOUT,'contL')==1);
            indicatorOUT{idxRem(1)}='NormLowFail';
        end
        
    % only yoke up if you have options to pull from, if not then it'll
    % become a 'norm' trial
    elseif contains(indicatorOUT{triali},'contL')
        
        if isempty(yokL)==0
            % pause for yoked control
            disp(['Pausing for low yoked control of ',num2str(yokL(1))])
            pause(yokL(1));
            indicatorOUT{triali} = 'yokeL_MET';
            delayLenTrial(triali) = yokL(1);            
            % delete so that next time, 1 is the updated delay
            yokL(1)=[];
        elseif isempty(yokL)==1
            disp(['Normal delay of ',num2str(delayLenTrial(triali))])
            pause(delayLenTrial(triali));
            indicatorOUT{triali} = 'yokeL_FAIL';
        end
        
    elseif contains(indicatorOUT{triali},'contH')
        % if you have a yoke to pull from
        if isempty(yokH)==0
            disp(['Pausing for high yoked control of ',num2str(yokH(1))])
            pause(yokH(1));
            indicatorOUT{triali} = 'yokeH_MET';  
            delayLenTrial(triali) = yokH(1);
            yokH(1)=[];
        % if you don't have a yoke to pull from
        elseif isempty(yokH)==1
            disp(['Normal delay of ',num2str(delayLenTrial(triali))])
            pause(delayLenTrial(triali));
            indicatorOUT{triali} = 'yokeH_FAIL';          
        end        
    end     
end 
[succeeded, reply] = NlxSendCommand('-StopRecording');

% get amount of time past since session start
c = clock;
session_time_update = str2num(strcat(num2str(c(4)),num2str(c(5))));
session_time = session_time_update-session_start;

% END TIME
endTime = toc(sStart)/60;

%% compute accuracy array and create some figures
for i = 1:length(trajRewarded)
    if trajRewarded{i} == trajectory_text{i}
        accuracy(i) = 0;
    else
        accuracy(i) = 1;
    end
end
movingAcc=[]; time2ChoiceMov=[];
looper = 1:length(trajRewarded);
for i = 1:length(looper)
    try
        movingAcc(i) = 1-nanmean(accuracy(looper(i):looper(i)+3));
        time2ChoiceMov(i) = nanmean(time2choice(looper(i):looper(i)+3));
    catch
    end
end
idxRev=(find(reversalTraj==1));

figure('color','w'); hold on;
xVar = 1:length(movingAcc);
xVar = xVar+3;
plot(xVar,smoothdata(movingAcc,'gauss',5),'b','LineWidth',2)
plot(xVar,movingAcc,'k','LineWidth',1)
ylimits = ylim;
xlimits = xlim;
for i = 1:length(idxRev)
    line([idxRev(i) idxRev(i)],[ylimits(1) ylimits(2)],'Color','r','LineStyle','--')
end
axis tight
xlabel('Trial')
ylabel('Choice Accuracy')
title('Spatial Reversal Task')
yyaxis right;
plot(xVar,time2ChoiceMov,'Color',[0.9100 0.4100 0.1700],'LineWidth',1)
ylabel('Time 2 choice')

%% ending noise - a fitting song to end the session
load handel.mat;
sound(y, 2*Fs);
%writeline(s,[doorFuns.closeAll])

%% save data
% save data
c = clock;
c_save = strcat(num2str(c(2)),'_',num2str(c(3)),'_',num2str(c(1)),'_','EndTime',num2str(c(4)),num2str(c(5)));

prompt   = 'Please enter the rats name ';
rat_name = input(prompt,'s');

prompt   = 'Please enter the task ';
task_name = input(prompt,'s');

prompt   = 'Enter notes for the session ';
info     = input(prompt,'s');

if contains(testingType,[{'E'} {'e'}])
    testingInfo = 'experimental';
else 
    testingInfo = 'control';
end
if contains(testingCond,'BW')
    addOn = 'BW';
elseif contains(testingCond,'MW')
    addOn = 'MW';
elseif contains(testingCond,'NA')
    addOn = 'NA';
end
save_var = strcat(rat_name,'_',task_name,'_',testingInfo,'_',addOn,'_',c_save);

% what trials to exclude
clear prompt
prompt   = 'Enter number of trajectories that you recorded: ';
expTotalTraj = str2num(input(prompt,'s'));
if expTotalTraj ~= numel(accuracy)
    error('You have entered the wrong number of trials')
end
clear prompt
prompt   = 'Enter trajectories to exclude. For example: 1 4 5 20 45: ';
remTraj  = str2num(input(prompt,'s'));

% clean up variables
accuracy2use = accuracy;
accuracy2use(1)=[]; % remove first trajectory
% to account for traj1 removal, subtract 1 from remTraj
remTrajFix = remTraj-1;
% correct the trialType variable
trialType = indicatorOUT;
trialType(numel(accuracy2use)+1:end)=[];
% correct delay length
delayLength = delayLenTrial;
delayLength(numel(accuracy2use)+1:end)=[];
% remove trajectories
accuracy2use(remTrajFix)=[];
trialType(remTrajFix)=[];
delayLength(remTrajFix)=[];

% split data
idxHmet = find(contains(trialType,'highMET'));
idxYmet = find(contains(trialType,'yokeH_MET'));

% get accuracy
accuracyHigh     = accuracy2use(idxHmet);
accuracyYokeHigh = accuracy2use(idxYmet);
% get trial type and delay length
ttHigh     = trialType(idxHmet);
ttYokeHigh = trialType(idxYmet);
dlHigh     = delayLength(idxHmet);
dlYokeHigh = delayLength(idxYmet);
% identify mismatches in delay duration
remData = [];
for i = 1:length(dlYokeHigh)
    idxFind = [];
    idxFind = find(dlHigh == dlYokeHigh(i));
    if isempty(idxFind)
        remData(i)=1;
    else 
        remData(i)=0;
    end
end
dlYokeHigh(logical(remData))=[];
accuracyYokeHigh(logical(remData))=[];
ttYokeHigh(logical(remData))=[];
idxYmet(logical(remData))=[];
remData1 = remData;

remData = [];
for i = 1:length(dlHigh)
    idxFind = [];
    idxFind = find(dlYokeHigh == dlHigh(i));
    if isempty(idxFind)
        remData(i)=1;
    else 
        remData(i)=0;
    end
end
dlHigh(logical(remData))=[];
accuracyHigh(logical(remData))=[];
ttHigh(logical(remData))=[];
idxHmet(logical(remData))=[];
remData2 = remData;
remAll = horzcat(remData1, remData2);

% split by reversal
% split data by rule 1 and rule 2 according to testing day
idxHmet1 = find(idxHmet <= idxRev(1));
idxHmet2 = find(idxHmet > idxRev(1));
idxYmet1 = find(idxYmet <= idxRev(1));
idxYmet2 = find(idxYmet > idxRev(1)); 

% get times out of the variables above
dlHmet1 = dlHigh(idxHmet1);
dlHmet2 = dlHigh(idxHmet2);
dlYmet1 = dlYokeHigh(idxYmet1);
dlYmet2 = dlYokeHigh(idxYmet2);

remData = [];
for i = 1:length(dlHmet1)
    idxFind = [];
    idxFind = find(dlYmet1 == dlHmet1(i));
    if isempty(idxFind)
        remData(i)=1;
    else 
        remData(i)=0;
    end
end
dlHmet1(logical(remData))=[];
idxHmet1(logical(remData))=[];

remData = [];
for i = 1:length(dlYmet1)
    idxFind = [];
    idxFind = find(dlHmet1 == dlYmet1(i));
    if isempty(idxFind)
        remData(i)=1;
    else 
        remData(i)=0;
    end
end
dlYmet1(logical(remData))=[];
idxYmet1(logical(remData))=[];

% now do it for post reversal
remData = [];
for i = 1:length(dlHmet2)
    idxFind = [];
    idxFind = find(dlYmet2 == dlHmet2(i));
    if isempty(idxFind)
        remData(i)=1;
    else 
        remData(i)=0;
    end
end
dlHmet2(logical(remData))=[];
idxHmet2(logical(remData))=[];

remData = [];
for i = 1:length(dlYmet2)
    idxFind = [];
    idxFind = find(dlHmet2 == dlYmet2(i));
    if isempty(idxFind)
        remData(i)=1;
    else 
        remData(i)=0;
    end
end
dlYmet2(logical(remData))=[];
idxYmet2(logical(remData))=[];

% now we have to backwards index
idxHmet1bi = idxHmet(idxHmet1);
idxYmet1bi = idxYmet(idxYmet1);
idxHmet2bi = idxHmet(idxHmet2);
idxYmet2bi = idxYmet(idxYmet2);
% now check
trialType(idxHmet1bi)
trialType(idxHmet2bi)
trialType(idxYmet1bi)
trialType(idxYmet2bi)
% now because trial type and accuracy are the same dimensions, we get
% accuracy as such:
if contains(testingCond,'MW')
    memoryRuleHighAcc   = accuracy2use(idxHmet1bi);
    memoryRuleYokeAcc   = accuracy2use(idxYmet1bi);
    withinRevHighAcc    = accuracy2use(idxHmet2bi);
    withinRevYokeAcc    = accuracy2use(idxYmet2bi); 
    % calculate prop correct
    memoryRuleHighPerf = 1-nanmean(memoryRuleHighAcc);
    memoryRuleYokePerf = 1-nanmean(memoryRuleYokeAcc);
    withinRevHighPerf  = 1-nanmean(withinRevHighAcc);
    withinRevYokePerf  = 1-nanmean(withinRevYokeAcc); 
    % figure
    figure('color','w'); hold on;
    bar([1 2 3 4],[memoryRuleYokePerf memoryRuleHighPerf withinRevYokePerf withinRevHighPerf]);
    name = {'MemoryYoke';'MemoryHigh';'WithinRevYoke';'WithinRevHigh'};
    %set(gca,'xticklabel',name)
    %xtickangle(45)
    box off
    ax = gca;
    ax.XTick = [1:4];
    ax.XTickLabel = name;
    ax.XTickLabelRotation = 45;
    ylabel('Proportion Correct');
elseif contains(testingCond,'BW')
    betweenRevHighAcc   = accuracy2use(idxHmet1bi);
    betweenRevYokeAcc   = accuracy2use(idxYmet1bi);
    withinRevHighAcc    = accuracy2use(idxHmet2bi);
    withinRevYokeAcc    = accuracy2use(idxYmet2bi);   
    % calculate prop correct
    betweenRevHighPerf = 1-nanmean(betweenRevHighAcc);
    betweenRevYokePerf = 1-nanmean(betweenRevYokeAcc);     
    withinRevHighPerf  = 1-nanmean(withinRevHighAcc);
    withinRevYokePerf  = 1-nanmean(withinRevYokeAcc);  
    % figure
    figure('color','w'); hold on;
    bar([1 2 3 4],[betweenRevYokePerf betweenRevHighPerf withinRevYokePerf withinRevHighPerf]);
    name = {'BetweenReversal';'BetweenReversalHigh';'WithinReversalYoke';'WithinReversalHigh'};
    %set(gca,'xticklabel',name)
    %xtickangle(45)
    box off
    ax = gca;
    ax.XTick = [1:4];
    ax.XTickLabel = name;
    ax.XTickLabelRotation = 45;
    ylabel('Proportion Correct');
end

place2store = ['X:\01.Experiments\R21\',targetRat,'\SRT\Testing'];
cd(place2store);
save(save_var);

%% clean maze

% close doors
writeline(s,doorFuns.closeAll);  

next = 0;
while next == 0
    
    % open doors and stop treadmill
    prompt = ['Are you finished cleaning (ie treadmill, walls, floors clean)? '];
    cleanUp = input(prompt,'s');

    if contains(cleanUp,[{'Y'} {'y'}])
        next = 1;
    else
        disp('Clean the maze!!!')
    end
end



