%% This script was used for visualizing the results but now is deprecated, since we have a better way for visualization
rootPath = filepart(cd);
%% load network order and network assignment
netPath = fullfile(rootPath, 'parc/ColeAnticevicNetPartition');
net_order = load(fullfile(netPath, 'cortex_community_order.txt'));
net_assign = load(fullfile(netPath, 'cortex_parcel_network_assignments.txt'));
net = net_assign(net_order);

ind_tril = tril(true(length(net)), -1);
ind_triu = triu(true(length(net)), 1);

%% load label file
fig_pos = [0.1 0.15 0.8 0.8];
axs_pos = [-150 360 -150 360];
clr = 'w'; % color of dotted line
border = [];
for i = 1:length(net)-1
    if net(i) ~= net(i+1)
        border = [border; i+0.5];
    end
end
%% load beta value
tmp = importdata(fullfile(rootPath, 'beta_z.csv'));
beta = tmp.data;
beta = beta';
beta(ind_tril) = nan;
tmp = importdata(fullfile(rootPath, 'beta_group_z.csv'));
beta_g = tmp.data;
beta_g(ind_triu) = nan;
%% beta group
hdl1 = figure(1);
set(hdl1, 'Position', [400, 0, 700, 700]);
axs1 = axes;
img1 = imagesc(axs1, beta_g);axis square;
colormap(axs1, flipud(rdylbu))
clb1 = colorbar('southoutside');
clb1.Position = [0.304285714285714,0.102857142857143,0.597142857142857,0.031428601195415];
set(axs1, 'position', fig_pos);
set(img1, 'AlphaData', ~isnan(beta_g));
set(axs1, 'ColorScale', 'log');
axis(axs_pos)
hold on
axis off
%% beta_weighted
% hdl2 = figure(2);
axs2 = axes;
set(axs2, 'position', fig_pos);
img2 = imagesc(axs2, beta);axis square;
colormap(axs2, flipud(rdylbu))
clb2 = colorbar('eastoutside');
clb2.Position = [0.915238095238095,0.15,0.033333333333333,0.597857142857143];
set(axs2, 'position', fig_pos);
set(img2, 'AlphaData', ~isnan(beta));
set(axs2, 'ColorScale', 'log')
axis(axs_pos)
hold on
axis off
%% draw network border
for i = 1:length(border)
    line(ones(1,length(net)+1)*border(i), 0:length(net), 'LineStyle', '--', 'Color', clr);
    line(0:length(net), ones(1,length(net)+1)*border(i), 'LineStyle', '--', 'Color', clr);   
end

%% draw network
fid = fopen(fullfile(netPath, 'network_labelfile.txt'), 'r');
label = [];
name = cell(12,1);
i = 1;
while ~feof(fid)
    tline = fgetl(fid);
    tmp = str2num(tline);
    tmp(2:end) = tmp(2:end)/255;
    if ~isempty(tmp)
        label = [label; tmp];
    else
        
        name{i,1} = tline;
        i = i+1;
    end
end



label = sortrows(label, 1);
label = [label [0; border] [border; 360]];
label = [label label(:, 7)-label(:, 6)];
key = 1;
rgb = 2:4; alpha = 5;
pos = 6;
width = 8;
for i = 1:length(label)
    clr = label(i, rgb);
    rectangle('Position', [label(i, pos) -20 label(i, width) 20], 'FaceColor', clr, 'EdgeColor', 'none');
    rectangle('Position', [-20 label(i, pos) 20 label(i, width)], 'FaceColor', clr, 'EdgeColor', 'none');
    if i <= 9
        txtPos = mean([label(i, pos), label(i+1, pos)]);
    elseif i == 10
        txtPos = 343.5-5;
    elseif i == 11
        txtPos = 349.5;
    elseif i == 12
        txtPos = 359;
    end
    if i == 7
        clr = [0.9 0.9 0];
    end
    text(-30, txtPos, name{i}, 'Color', clr, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
end

%% draw single subject's fcMat
fc = importdata(fullfile(rootPath, 'subMat_100307.csv'));
hdl2 = figure(2);
img2 = imagesc(fc);axis square;
colormap(coolwarm)
clb3 = colorbar('eastoutside');
caxis([-0.5 0.5])
% set(axs2, 'ColorScale', 'log');
hold on
axis off
for i = 1:length(border)
    line(ones(1,length(net)+1)*border(i), 0:length(net), 'LineStyle', '--', 'Color', 'k');
    line(0:length(net), ones(1,length(net)+1)*border(i), 'LineStyle', '--', 'Color', 'k');   
end
