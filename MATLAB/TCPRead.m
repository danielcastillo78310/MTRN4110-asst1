clear
 
height = 120;%received image dimensions
width = 160;

ip_address = '127.0.0.1';
remote_port = 15000;
MaxTimeout = 1000; 
Timer = 0;
MaxDist = 1;
MaxRecordSize = 100;

t = tcpip(ip_address,remote_port);%Initiate TCP connection
t.ByteOrder = 'littleEndian';%Set Endian to convert
set(t,'InputBufferSize', width*height*3*2);

fopen(t);
pause(1)

close all;
figure(1); hold on;
guiH.DepthVisualisation = imagesc();
colorbar;
caxis([0 1]);
axis([0 160 0 120]);

figure(2); hold on;zoom on ; grid on; axis equal;
guiH.Vertices = plot3(0,0,0,'.');
guiH.roi = scatter3(0, 0, 0, 'g');
guiH.normalLine = plot3(0, 0, 0, 'r');
xlabel('x'); ylabel('y'); zlabel('z');
title('untransformed point cloud data');
view(90, 0);


figure(3); hold on;
guiH.DepthScan = plot(0,0,'b.');   %Depth map at horizon scatterplot handle
guiH.Marker = plot(0,0,'g.','MarkerSize',20);  %Object of interest marker overlay Handle
axis([-0.4 0.4 0 1]);    %in meters
title('scan of middle row');

figure(4); hold on; axis equal; zoom on;grid on;
guiH.pct = scatter3(0, 0, 0, 'b.');
guiH.roit = scatter3(0, 0, 0, 'g');
xlabel('x'); ylabel('y'); zlabel('z');
title('transformed pts');
view(90, 0);

rosbagXYZ = repmat(struct('x', [], 'y', [], 'z', []),1,150);
rosbagFrame = 0;

while t.BytesAvailable == 0 %Wait for incoming bytes
    pause(1)
    disp('waiting for initial bytes...');
end

disp('Connected to server');

while ((Timer < MaxTimeout) || (get(t, 'BytesAvailable') > 0))         
    if(t.BytesAvailable > 0)    %if connected
        Timer = 0; %reset timer
    end
    
    buff = fread(t, height*width*3, 'int16');
    Timer = Timer + 1;
    rosbagFrame = rosbagFrame + 1;
    
    x = buff(1:19200);
    y = buff(19201:38400);
    z = buff(38401:57600);
    
    x = x/1000; y = y/1000; z = z/1000;  %Convert from mm to m
    z(z < 0) = -10;    %Negative depths to be disregarded
    z(z > MaxDist) = -10;   %Value for depth too far away disregarded
    
    %plot depthmap before bad points are removed
    DepthMap = reshape(z,[160,120]);
    %flip image upside down and rotate 90 deg
    DepthMap = flipud(DepthMap');   
    set(guiH.DepthVisualisation, 'CData', DepthMap);

    x = x(z ~= -10);
    y = y(z ~= -10);
    z = z(z ~= -10);
    
    set(guiH.Vertices, 'xdata', x, 'ydata', y, 'zdata', z);
    xScan = x(y==0);
    zScan = z(y==0);
    set(guiH.DepthScan, 'xdata', xScan, 'ydata', zScan);
%     PlotOOIs(OOIs, guiH.Marker);

    %% plotting and transformation of live camera data:
    
    pc = [x'; y'; z'];
    roi = camROI(pc);
    set(guiH.roi, 'xdata', roi(1, :), 'ydata', roi(2, :), 'zdata', roi(3, :));
    if numel(roi) < 10*3
        pause(0.01);
        disp('not enough pts');
        continue
    end
    [~, n, ~] = getOrientation(roi);
    pct = cloudTransform(pc, n);
    roit = cloudTransform(roi, n);

    x = x(z ~= -10);
    y = y(z ~= -10);
    z = z(z ~= -10);
    pc = [x;y;z];
    %create a line to visualise n:
    nLine = [roi(:, 1), roi(:, 1) + n'*0.2/(norm(n))];
    set(guiH.normalLine, 'xdata', nLine(1, :), 'ydata', nLine(2, :), 'zdata', nLine(3, :));
%     plot3(nLine(1, :), nLine(2, :), nLine(3, :), 'linewidth', 10);
    
    set(guiH.pct, 'xdata', pct(1, :), 'ydata', pct(2, :), 'zdata', pct(3, :));
%     scatter3(pct(1, :), pct(2, :), pct(3, :), 'b.');
    set(guiH.roit, 'xdata', roit(1, :), 'ydata', roit(2, :), 'zdata', roit(3, :))
%     scatter3(roit(1, :), roit(2, :), roit(3, :), 'r*');

    
    
    
    %%

    


    %record a rosbag
%     if (rosbagFrame < MaxRecordSize)
%         rosbagXYZ(rosbagFrame).x = x;
%         rosbagXYZ(rosbagFrame).y = y;
%         rosbagXYZ(rosbagFrame).z = z;
%     else 
%         disp('Rosbag Full');
%     end
    pause(0.01);    %~10ms delay
end

%program end
pause(1)
fclose(t);
delete(t);
clear t