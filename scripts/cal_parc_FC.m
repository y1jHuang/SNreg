%% This script is for calculating parcellated connectome, and Kong's parcellation was utilized
clear;
addpath(genpath(fullfile(cd, 'matlab_ext')));
%% Initialize parameters
rootPath = fileparts(cd);
% Path of each subject's preprocessed rs-fMRI data
dataPath = fullfile(rootPath, 'denoise_A');
% output Path
outPath = rootPath;
% list of subjects' ID
subject = load(fullfile(rootPath, 'subjectsID_SAVE.txt'));
% Path of the folder containing Kong's parcellation
parcPath = fullfile(rootPath, 'parc', 'Yeo');
% Path of the Kong's parcellation
fid = fopen(fullfile(parcPath, 'fslr32k', 'Schaefer2018_400Parcels_Kong2022_17Networks_order_info.txt'), 'r');
label = [];
i = 1;
while ~feof(fid)
    tline = fgetl(fid);
    tmp = str2num(tline);
    tmp(2:end) = tmp(2:end)/255;
    if ~isempty(tmp)
        label = [label; tmp];
    else
        tname = strsplit(tline,'_');
        if size(tname) ~= 5
            name(i,[1:3,5]) = tname;
        else
            name(i,:) = tname;
        end
        i = i+1;
    end
end
N = length(label); % number of nodes

% array of parts of parcels' information, including each parcel's color
% and its index
label = array2table(label, 'VariableNames', {'idx','R','G','B','A'});
% array of parts of parcels' information, including the version of the 
% parcellation, hemispheres they situated, networks they belong to, their
% names and their subindexes
name = cell2table(name, 'VariableNames', {'ver','hem','network','parcel','sub_idx'});
net_info = [label, name];

%%
% read in each parcels' coordination in MNI space (which is relabeled manually by Yingjie Huang)
% and update the networks' information

fid = fopen(fullfile(parcPath, 'Schaefer2018_400Parcels_Kong2022_17Networks_order_FSLMNI152_1mm.Centroid_RAS.txt'), 'r');
coord = [];
while ~feof(fid)
    tline = fgetl(fid);
    tmp = str2num(tline);
    tmp = tmp(2:end);
    if ~isempty(tmp)
        coord = [coord; tmp];
    end
end
net_info = [net_info, array2table(coord, 'VariableNames', {'Ri', 'Ant', 'Sup'})];
network_name = unique(net_info.network);
% reorder networks
network_order = [15:17 1 13:14 10 11:12 2:4 5:7 8:9];
network_order = [1:size(network_order,2); network_order]';
network_name = network_name(network_order(:,2));

for i = 1:length(network_name)
    net_info{strcmp(net_info.network,network_name{i}), 'net_idx'} = network_order(i,1);
end

net_info = sortrows(net_info,{'net_idx'},{'ascend'});
writetable(net_info, fullfile(outPath, 'net_info.csv'), 'delimiter',',');

%% Calculate functional connectivity with pearson correlation
fc = zeros(length(subject), nchoosek(N, 2));
idx = net_info.idx;
for i = 1:length(subject)
ptseriesFile = 'rfMRI_REST1.ptseries.nii';
ptseries = cifti_read(fullfile(dataPath, num2str(subject(i)), ptseriesFile));
ts = ptseries.cdata;
ts_order = ts(idx, :);
subMat = double(nets_netmats(ts_order', 0, 'corr'));
ind = tril(true(N), -1);
fc(i, :) = reshape(subMat(ind), 1, []);
end
csvwrite(fullfile(outPath, 'fc.csv'), fc);