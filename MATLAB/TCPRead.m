clear

height = 120;%received image dimensions
width = 160;
Range = 31999;
fovx = 74*pi/180;%horizontal field of view of the camera
colourRange = 255;

ip_address = '127.0.0.1';
remote_port = 15000;
Timer = 0;
MaxTimeout = 1000; 

MinX = -1; MaxX = 1; MinDist = 0; MaxDist = 1;

t = tcpip(ip_address,remote_port);%Initiate TCP connection
t.ByteOrder = 'littleEndian';%Set Endian to convert
set(t,'InputBufferSize', (2*width*height));
fopen(t);
pause(1)

figure(1);
guiH.DepthVisualisation = imagesc();
colorbar;
%caxis([0 1500]);
axis([0 160 0 120]);

figure(2); clf(); 
guiH.Vertices = plot3(0,0,0,'.', 'MarkerSize', 2);
axis([-0.8 0.8 -0.4 0.4 0 1]);
xlabel('x Horizontal'); ylabel('Y Vertical'); zlabel('Z Depth');
zoom on ; grid on;

figure(3); clf(); hold on;
guiH.DepthScan = plot(0,0,'b.');   %Depth map at horizon scatterplot handle
guiH.OOI = plot(0,0,'r*');  %Object of interest marker overlay Handle
axis([MinX, MaxX, MinDist, MaxDist]);    %in meters

while t.BytesAvailable == 0 %Wait for incoming bytes
    pause(1)
    disp('waiting for initial bytes...');
end

disp('Connected to server');

while ((Timer < MaxTimeout) || (get(t, 'BytesAvailable') > 0))         
    if(t.BytesAvailable > 0)    %if connected
        Timer = 0; %reset timer
    end
    
%     buff = fread(t, 19200*3, 'int16');
%     
%     x=buff(1:19200);
%     y=buff(19201:38400);
%     z=buff(38401:57600);
    
    DataReceivedXYZ = fread(t,width*height,'uint16');  %Read one depthmap frame
    
    counter = 1;
    
    for i = 1 : height
        for j = 1: width
          DepthMap(i,j) = DataReceivedXYZ(counter); %Capture depth for respective pixel
          counter = counter + 1;
          
          if (i == height/2)
            yDist(j) = DataReceivedXYZ(counter);
          end
        end
    end
    
    %DepthMap = reshape(DepthMap,[160,120]);
    %rotate image by 90 degree
    DepthMap = DepthMap'';
    %flip image upside down
    DepthMap = flipud(DepthMap);    
    
    yDist = yDist/1000;  %Convert from mm to m
    yDist(yDist < 0) = -1;    %Negative depths to be disregarded
    yDist(yDist > MaxDist) = -1;   %Value for depth too far away disregarded
    
    %estimate world x-coordinates of pixels:
    xDist = yDist*tan(fovx/2).*(-width/2 : (width - 1)/2)/width;%width - 1 for off-by one error
    
    DepthMap = DepthMap/1000;
    DepthMap(DepthMap > MaxDist) = 0;
    DepthMap(DepthMap < 0) = 0; %Negative depths to be disregarded
    OOIs = ExtractOOIs_cam(xDist, yDist);
    
    %Display necessary plots
    set(guiH.DepthVisualisation, 'CData', DepthMap/Range);   %divide by range to scale between 0-1 for colormpa
    %set(guiH.Vertices, 'xdata', x, 'ydata', y, 'zdata', z);
    set(guiH.DepthScan, 'xdata', xDist, 'ydata', yDist);
    PlotOOIs(OOIs, guiH.OOI);
    
    pause(0.01);    %~10ms delay
end

%program end
pause(1)
fclose(t);
delete(t);
clear t