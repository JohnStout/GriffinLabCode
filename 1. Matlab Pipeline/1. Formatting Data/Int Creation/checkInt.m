%% check int for timestamp - position accuracy
% this function was designed to check the users int file for accuracy
%
% -- INPUTS -- %
% Int: Int file in old formatting
% pos_x: x position data
% pos_y: y position data
% pos_t: timestamps from video camera
%
% -- OUTPUTS -- %
% remStem2Choice: remove trials with tracking errors on stem and if failed
%                   stem entry/choice exit found
% remReturn: remove trials with tracking error on return
% remDelay: remove trials with failed startbox entrance
% remDoubleTrial: remove trials if there are multiple overlapping trials
%                   being characterized as a single trial
%
% written by John Stout

function [remStem2Choice, remReturn, remDelay, remDoubleTrial, remBehavior] = checkInt(Int,pos_x,pos_y,pos_t)

% number of trials
numTrials = size(Int,1);

figure('color','w'); hold on;    
p1 = []; p2 = [];
if numTrials < 40
    rowVal = 5;
    colVal = 8;
else
    rowVal = ceil(numTrials/10);
    colVal = 10;
end
for i = 1:numTrials
        subplot(rowVal,colVal,i); hold on;
        plot(pos_x,pos_y,'Color',[.8 .8 .8]); 
        for ii = 1:size(Int,2)
            Int_x = pos_x(pos_t == Int(i,ii));
            Int_y = pos_y(pos_t == Int(i,ii));
            % plot
            if ii == size(Int,2)
            elseif ii == 1
                x_trial = pos_x(pos_t >= Int(i,1) & pos_t <= Int(i,6));
                y_trial = pos_y(pos_t >= Int(i,1) & pos_t <= Int(i,6));
                plot(x_trial,y_trial,'Color',[1, 0, 0, 1],'LineWidth',2);
                missingStem = numel(find(x_trial==0));
                numStem = numel(x_trial);
                rateStem = missingStem/numStem;
            elseif ii == 6
                x_trial = pos_x(pos_t >= Int(i,6) & pos_t <= Int(i,8));
                y_trial = pos_y(pos_t >= Int(i,6) & pos_t <= Int(i,8));
                plot(x_trial,y_trial,'Color',[0, 0, 0, 0.5],'LineWidth',1);
                missingRet = numel(find(x_trial==0)); 
                numRet = numel(x_trial);
                rateRet = missingRet/numRet;
            else
            end
        end
        title(['Trial #',num2str(i)])
        text(min(pos_x)+20,min(pos_y)+150,['stemLost=',num2str(round(rateStem,2))],'Color','r');
        text(min(pos_x)+20,min(pos_y)+50,['retLost=',num2str(round(rateRet,2))],'Color','b');
        axis off
 
end 
set(gcf, 'Position', get(0, 'Screensize'));
remStem2Choice = str2num(input('Enter trials with >10% tracking error in stem/choice, failed stem entry or choice exit: ','s'));
remReturn = str2num(input('Enter trials with >10% tracking error in return: ','s'));
remDelay = str2num(input('Enter trials with failed startbox entry: ','s'));
remDoubleTrial = str2num(input('Enter "double trials" - trials that have two trajectories overlapping: ','s'));
disp('If rat is unplugged before the choice remove the corresponding trial');
disp('If rat is unplugged after the choice remove the following trial');
remBehavior = str2num(input('Enter trials that should be removed due to disturbance in behavior room (unplug, sounds, etc): ','s'));

%remData = logical(remData);

% update int file accuracy
