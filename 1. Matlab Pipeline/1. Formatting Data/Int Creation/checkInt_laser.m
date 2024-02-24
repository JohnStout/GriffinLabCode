%% check int for timestamp - position accuracy - optogenetics experiment 
% This function was designed to check the users int file for accuracy and
% mark trials to be exlcuded from analysis 
%
% Currently for DA task with optogenetic stimulation at maze startbox (during delay), stem, 
% or return arm. 
% This script will need to be edited if user wants excluded trials to be grouped 
% by reason for exclusion (ex. exclude trial based on tracking at specific
% maze location). 
%
% -- INPUTS -- %
% Int: Int file in old formatting
% pos_x: x position data
% pos_y: y position data
% pos_t: timestamps from video camera
% vt_name: name of video tracking file
% location: where is laser on? (stem/goal/delay)
%
% -- OUTPUTS -- %
% remTrial : Remove trials with laser onset/offset failure, bad tracking,
% etc.
% laserID : laser type for each trial

function [laserID, remTrial] = checkInt_laser(Int,pos_x,pos_y,pos_t,vt_name,location)

% number of trials
numTrials = size(Int,1);
load('Events')
%plot laser on/off
%use event strings to get  timestamps for on/off
redON= contains(EventStrings, 'RedON');
redOFF= contains(EventStrings, 'RedOFF');
blueON=contains(EventStrings, 'BlueON');
blueOFF=contains(EventStrings, 'BlueOFF');
% redON= contains(EventStrings, '0002');
% redOFF= contains(EventStrings, '0000');

redON_ts = TimeStamps(redON);
redOFF_ts= TimeStamps(redOFF);
blueON_ts= TimeStamps(blueON);
blueOFF_ts= TimeStamps(blueOFF);

%use timestamps to get position data
load(vt_name)
idxRedON = dsearchn(TimeStamps', redON_ts');
idxRedOFF = dsearchn(TimeStamps', redOFF_ts');
idxBlueON = dsearchn(TimeStamps', blueON_ts');
idxBlueOFF = dsearchn(TimeStamps', blueOFF_ts');

figure('color','w'); hold on;    
p1 = []; p2 = [];
if numTrials < 40
    rowVal = 5;
    colVal = 8;
else
    rowVal = ceil(numTrials/10);
    colVal = 10;
end

laserID=[];
if contains(location,'delay')
    trialCheck = 2; %will start plotting from trial 2 (enter sb trial 1-> enter sb trial 2)
    laserID{1}=0; %no stim before first trial for delay testing day
elseif contains(location, [{'stem'},{'goal'}])
    trialCheck=1;
end

for i = trialCheck:numTrials
    
        subplot(rowVal,colVal,i); hold on;
        plot(pos_x,pos_y,'Color',[.8 .8 .8]); 
        
        %plot entire trial
        if contains(location, [{'stem'},{'goal'}])
            idxTrialPos = find(pos_t >= Int(i,1) & pos_t <= Int(i,8));
        elseif contains(location,'delay')
            idxTrialPos = find(pos_t >= Int(i-1,8) & pos_t <= Int(i,8));
        end
        x_trial = pos_x(idxTrialPos);
        y_trial = pos_y(idxTrialPos);
        plot(x_trial,y_trial,'Color',[0 0 0 0.5],'LineWidth',2); hold on;
        
        %plot when laser is on
        idxRMatch= find(ismember(idxRedON,idxTrialPos)==1);
        idxBMatch= find(ismember(idxBlueON,idxTrialPos)==1);
        if ~isempty(idxRMatch)
            try
                xlaser = pos_x(idxRedON(idxRMatch):idxRedOFF(idxRMatch));
                ylaser = pos_y(idxRedON(idxRMatch):idxRedOFF(idxRMatch));
                plot(xlaser,ylaser,'Color',[1 0 0 1],'LineWidth',2);
                laserID{i}='Red';
            catch
                disp('this trial may have laser error')
            end
        elseif ~isempty(idxBMatch)
            try
                xlaser = pos_x(idxBlueON(idxBMatch):idxBlueOFF(idxBMatch));
                ylaser = pos_y(idxBlueON(idxBMatch):idxBlueOFF(idxBMatch));
                plot(xlaser,ylaser,'Color',[0 0 1 1],'LineWidth',2);
                laserID{i}='Blue';
            catch
                disp('this trial may have laser error')
            end
        else
            laserID{i}= 0;
        end

        title(['Trial #',num2str(i)])
        axis off
 
end 
set(gcf, 'Position', get(0, 'Screensize'));
remTrial = str2num(input('Enter trials to be removed: ','s'));
laserID = laserID';

% update int file accuracy