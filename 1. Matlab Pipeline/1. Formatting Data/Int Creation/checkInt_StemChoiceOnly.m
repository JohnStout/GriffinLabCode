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
%
% written by John Stout

function [remStem2Choice] = checkInt_StemChoiceOnly(Int,pos_x,pos_y,pos_t)

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
        if ii == 1
            x_trial = pos_x(pos_t >= Int(i,1) & pos_t <= Int(i,3));
            y_trial = pos_y(pos_t >= Int(i,1) & pos_t <= Int(i,3));
            plot(x_trial,y_trial,'Color',[1, 0, 0, 1],'LineWidth',2);
            missingStem = numel(find(x_trial==0));
            numStem = numel(x_trial);
            rateStem = missingStem/numStem;
        elseif ii == 3
            try % plot stem entry->stem entry of following trial
                x_trial = pos_x(pos_t >= Int(i,3) & pos_t <= Int(i+1,1));
                y_trial = pos_y(pos_t >= Int(i,3) & pos_t <= Int(i+1,1));
                plot(x_trial,y_trial,'Color',[0, 0, 0, 0.5],'LineWidth',1);
                missingRet = numel(find(x_trial==0));
                numRet = numel(x_trial);
                rateRet = missingRet/numRet;
            catch % for final trial plot returm
                x_trial = pos_x(pos_t >= Int(i,3) & pos_t <= pos_t(end));
                y_trial = pos_y(pos_t >= Int(i,3) & pos_t <= pos_t(end));
                plot(x_trial,y_trial,'Color',[0, 0, 0, 0.5],'LineWidth',1);
                missingRet = numel(find(x_trial==0));
                numRet = numel(x_trial);
                rateRet = missingRet/numRet;
            end
        else
        end
    end
    title(['Trial #',num2str(i)])
    text(min(pos_x)+20,min(pos_y)+150,['stemLost=',num2str(round(rateStem,2))],'Color','r');
    axis off
end

set(gcf, 'Position', get(0, 'Screensize'));
disp('If rat is unplugged before the choice remove the corresponding trial');
disp('If rat is unplugged after the choice remove the following trial');
disp('If the rat appears in the start box, this means the rat was replugged/the testing sequence was paused');
disp('If red position data is in the start box, remove the corresponding trial');
disp('If black position data is in the start box, remove the following trial');
remStem2Choice = str2num(input('Enter trials with failed choice exit, unplug, double trial: ','s'));

