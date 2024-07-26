%% Classifier K Nearest Neighbors
% Determine if data can be classified as belonging to true group using KNN
% method
% 2 groups
% leave one out
%
% INPUTS
% data1: matrix with group 1 data (rows= measured variables, columms= subjects/sessions/etc)
% data2: matrix with group 2 data (# rows must be equal to data1)
% k= # nearest neighbors
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


function [cmat,classAcc] = classifier_KNN(data1, data2, k, metric, visualize3D)

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
    
    %find distance between vectors
    if isempty(metric)
        metric='euclidean';
    end

    for num = 1:length(id)
        dist2data(num) =pdist([training(:,num),testing]',metric); %or 'cosine' or 'correlation'...etc
    end

    idx=[]; orderID=[];
    [~,idx]=sort(dist2data);
    orderID= id(idx);

    if isempty(visualize3D)
        visualize3D= 'n';
    end

    if i==1 && visualize3D== 'y' %if want to visualize some dimensions, can change idx if want to view other dimensions 
    sortedTrainData=training(:,idx);
    figure('color','w'); 
    plot3(sortedTrainData(1,orderID(1:k)==1),sortedTrainData(2,orderID(1:k)==1),sortedTrainData(3,orderID(1:k)==1),'.r','markersize', 15); hold on %nearest neighbors group1
    plot3(sortedTrainData(1,orderID(1:k)==2),sortedTrainData(2,orderID(1:k)==2),sortedTrainData(3,orderID(1:k)==2),'.b','markersize', 15); %nearest neighbors group2
    plot3(testing(1),testing(2),testing(3),'.k','markersize', 15) %test data
    remainingData=[];remainingData=sortedTrainData(:,k+1:end);
    plot3(remainingData(1,orderID(k+1:end)==1),remainingData(2,orderID(k+1:end)==1),remainingData(3,orderID(k+1:end)==1),'.r','markersize', 5); %rest of group 1
    plot3(remainingData(1,orderID(k+1:end)==2),remainingData(2,orderID(k+1:end)==2),remainingData(3,orderID(k+1:end)==2),'.b','markersize', 5); %rest of group 2
    end

     %classify test data
    if nnz(orderID(1:k)==1)>=round(k/2)
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
   
