%% Classifier
% Determine if data can be classified as belonging to true group
% 2 groups
% leave one out
%
% INPUTS
% data1: matrix with group 1 data (rows= measured variables, columms= subjects/sessions/etc)
% data2: matrix with group 2 data (# rows must be equal to data1)
% metric: distance metric (default is euclidean, although choose any 
%           metric (cosine, correlation, etc)
% visualize3D: visualize the first 3 dimensions of your data from 1 iteration 'n' is default, 'y' for yes 
%
% OUTPUTS
% cmat: confusion matrix
% classAcc: classifier accuracy (%)
% confusion chart
% 
% HR 2024


function [cmat,classAcc] = classifier_Euclidean(data1, data2, metric, visualize3D)

%concatenate data 
dataCat=horzcat(data1, data2);

%vector defining actual group
group=[];
group(1:size(data1,2))=1; %group 1
group(end+1:end+size(data2,2))=2; %group 2

accuracy=[]; classification=[];
for i=1:length(group)

    %get training and testing data for the iteration
    training=[]; testing=[];
    training= dataCat;
    training(:,i)=[]; %training data
    testing=dataCat(:,i); %test data

    % get condition of test data
    testID=[];
    testID = group(i);

    % separate groups to find group means of training data
    id=[];
    id=group;
    id(i)=[]; %remove testing rat

    group1=[]; group2=[];
    group1= mean(training(:,id==1),2); %group 1 training data mean vector
    group2= mean(training(:,id==2),2); %group 2 training data mean vector
    
    %find distance between vectors
    if isempty(metric)
        metric='euclidean';
    end
    dist21 =pdist([group1,testing]',metric); %or 'cosine' or 'correlation'...etc
    dist22 =pdist([group2,testing]',metric);

    if isempty(visualize3D)
        visualize3D= 'n';
    end
    if i==1 && visualize3D== 'y' %if want to visualize some dimensions, can change if want to view other dimensions 
    figure('color','w'); 
    plot3(training(1,id==1),training(2,id==1),training(3,id==1),'.r','markersize', 15); hold on
    plot3(training(1,id==2),training(2,id==2),training(3,id==2),'.b','markersize', 15)
    plot3(testing(1),testing(2),testing(3),'.k','markersize', 15) %test data
    plot3(group1(1),group1(2),group1(3),'rx','markersize', 15) %centroid group 1
    plot3(group2(1),group2(2),group2(3),'bx','markersize', 15) %centroid group 2
    end

    %classify test data
    if dist21<dist22
        classification(i) = 1; %classify as group 1
    else
        classification(i) = 2; %classify as group 2
    end

    if testID==classification(i)
        accuracy(i)=1; %correct classifiction
    else
        accuracy(i)=0; %incorrect classification
    end
end

classAcc=mean(accuracy)*100;
%disp(['classifier accuracy: ', num2str(classAcc)]) % classifier accuracy


cmat = confusionmat(group,classification); % confusion matrix
%figure('color','w'); confusionchart(cmat) % chart
   
