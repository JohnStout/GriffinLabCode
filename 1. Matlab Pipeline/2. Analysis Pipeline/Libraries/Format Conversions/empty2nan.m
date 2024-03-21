%% function that takes a cell array and replaces 
% empty values with NaN
function [array,idx2nan] = empty2nan(array)
idx2nan=zeros(size(array));
    for rowi = 1:size(array,1)
        for coli = 1:size(array,2)
            if isempty(array{rowi,coli})
                array{rowi,coli} = NaN; 
                idx2nan(rowi,coli)=1;
            end
        end
    end
    idx2nan=logical(idx2nan);
end

