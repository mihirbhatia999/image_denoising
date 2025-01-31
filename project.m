%% loading image and it's dimensions, X_clean is the clean image to test
X_clean = imread('C:\Users\Test\Desktop\lena.tiff');
X_clean = rgb2gray(X_clean);
X_clean = imresize(X_clean, 0.125);
[h,w] = size(X_clean);

%% adding noise to our image 
mean_noise = 0;
var_noise = 0.01;
Y = imnoise(X_clean,'gaussian',mean_noise, var_noise);
imshowpair(Y,X_clean, 'montage')
    %initializing clean image with noisy image at first 
Y = double(Y);
X = double(imnoise(X_clean,'gaussian',mean_noise, 0.0001));

%{
Y = Noisy Image 
Penalty parameters = lambda_1, lambda_2, mu 
Smoothing parameter = delta 
Stopping tolerance = e1, e2 
Clean Image = X 
%}

%% from table 1 for p =1 
lambda_1 = 10; 
lambda_2 = 5;
sigma = 3 ; %for additive noise 
mu = sigma/30;
%delta = 0.12;  %p=1
delta = 0;
e1 = 0.001;
e2 = 0.001;

%initializing
%k > n ---> it limits the rank of dictionary to n
n = h;
k = 81;

%dictionary 
phi = zeros(power(n,0.5),power(k,0.5));
for i = 1:power(n,0.5)
    for j = 1:power(k,0.5)
      phi(i,j) = cos((i-1)*(j-1)*(pi/11)) ;
    end
end
size(phi)
phi = kron(phi,phi);

patch_size = 8;
S = zeros(h,w,'double');
X_2 = zeros(h,w);
X_1 = zeros(h,w);   %change

no_of_patches = (h*w)/(power(patch_size,2));
Omega = zeros(k,no_of_patches);

L = (1/9)*[-1 -1 -1; -1 8 -1; -1 -1 -1];
t = 0;
 a = 1;
j = 1;
delta_1 = e1 + 1;
delta_2 = e2 + 1;
tmax = 3;  % to change
smax = 10 ; % change
p=2;
T=20;       %own value

%% while loop
while (delta_1>=e1) && (t<=tmax)
    s=0;
    while (delta_2>=e2) && (s<=smax)
        S_s1 = argmin_S(Y,X,S,lambda_2);  %EQ 17
        S_s1
        X_s1 = argmin_X(Y,X,S_s1,lambda_1,L,delta,mu,X_2,p);
        X_s1
        delta_2 = min(power(norm(X_s1-X,'fro'),2),power(norm(S_s1-S,'fro'),2));
        delta_2
        X = X_s1;
        S = S_s1;
        s=s+1;
    end 
    X_1_t1 = X;
    X_2_t1 = argmin(mu,X,X_1_t1,phi,Omega,no_of_patches,patch_size);
    delta_1 = min(power(norm(X_1_t1-X_1,'fro'),2),power(norm(X_2_t1-X_2,'fro'),2));
    X_1 = X_1_t1;
    X_2 = X_2_t1;
    t = t+1;
end

%% line 16
X = X_2;

% Sparse coding stage
k_0 = 15;   %change
for i = 1:no_of_patches
    Omega(:,i) = omp(phi,patch(i,patch_size, X),k_0);
end

%% Update dictionary

%Line 18
%phi = (X*Omega')*((Omega*Omega')^(-1))

A=2;
K=k;
a=1;

R  = Ri(patch_size,h,w);
rit=0;
rit_2=0;
for i=1:no_of_patches
   rit = rit+R(:,:,i)'*R(:,:,i);
   rit_2 = rit_2 + (R(:,:,i)'*phi*Omega(:,i));
end

while(a<=A)
    X=(((1/mu)*eye(h*w)+rit)^(-1))*(((1/mu)*X_1)+rit_2);
    E=X-(phi*Omega);
    j=1;
    while(j<=K)
        E_j = E + phi(:,j)*Omega(j,:);
        t_j = find(Omega(j,:));
        phi(:,j) = E_j(:,t_j)*(Omega(j,t_j))';
        Omega(j,t_j) = (phi(:,j))'*E_j(:,t_j);
        E = E_j - phi(:,j)*Omega(j,:);
        j=j+1;
    end
    a=a+1;
end


%% functions  
%Function argmin
function [S] = argmin_S(Y, X, S, lambda_2)
    fprintf('argmin S called')
    [h,w] = size(X);
    cvx_begin
        variable S(h,w)
        minimize (power(2,norm(Y-X-S,'fro'))+(lambda_2*norm(S,1)))
        %minimize (power(2,norm(Y-X-S,'fro')))
        %minimize(lambda_2*norm(S,1))
    cvx_end
end
    
function [X] = argmin_X(Y,X,S,lambda_1,L,delta,mu,X_2,p)
    fprintf('argmin X function called')
    [h,w] = size(X);
    %kernel = -1 * ones(3);
    %kernel(2,2) = 8; 
    %LX = conv2(X, kernel, 'same');
     
    cvx_begin
        variable X(h,w)
        %minimize (power(2,norm(Y-X-S,'fro'))+(lambda_1*trace(power((p/2),((LX.')*LX)+(delta*delta*eye(w)))))+(mu*power(2,norm(X-X_2,'fro'))))
        minimize (power(2,norm(Y-X-S,'fro'))+(lambda_1*(power(2,norm((laplace(X)),'fro'))+(w*w*delta*delta)))+(mu*power(2,norm(X-X_2,'fro'))))
    cvx_end
end 


function [X] = argmin(mu,X,X_1_t1,phi,Omega,no_of_patches,patch_size)
    fprintf('argmin function called')
    [h,w] = size(X);
    kernel = -1 * ones(3);
    kernel(2,2) = 8; 
    LX = conv2(X, kernel, 'same');
    T=20;   %change
   
    cvx_begin
        variable X(h,w)
        minimize ((1/mu)*power(2,norm(X-X_1_t1,'fro'))+patch_sum(X,phi,Omega,patch_size,no_of_patches)) 
        subject to
        for i=1:size(Omega,2)
            norm(Omega(:,i),0) <= T;
        end
        
    cvx_end
end

function [image_patch] = patch(i,patch_size, X)
    [h,w] = size(X);
    c = mod(i,(w/(patch_size))) ;
    if c==0
        c=patch_size;
    end
    r = floor(i/(w/(patch_size))) + 1;
    if r==patch_size+1
        r=patch_size;
    end
    xmin = (r-1)*patch_size + 1; 
    ymin = (c-1)*patch_size + 1 ;
    image_patch = X(xmin:xmin+(patch_size-1),ymin:ymin+(patch_size-1));
    image_patch = reshape(image_patch,[],1);
end

function [p_sum] = patch_sum(X,phi,Omega,patch_size,no_of_patches)
    p_sum=0;
    for i = 1:no_of_patches
        p_sum=p_sum+power(2,norm((patch(i,patch_size,X)-(phi*Omega(:,i))),2));
    end
end

function [R] = Ri(patch_size,h,w)
    %image_patch = X(xmin:xmin+(patch_size-1),ymin:ymin+(patch_size-1));
    %image_patch = reshape(image_patch,[],1);
no_of_patches = (h*w)/(patch_size*patch_size);
R = zeros(patch_size*patch_size, h*w, no_of_patches);
for k = 1:no_of_patches
    c = mod(k,(w/(patch_size))) ;
    if c==0
        c=patch_size;
    end
    r = floor(k/(w/(patch_size))) + 1;
    if mod(k,(w/(patch_size)))==0 
        r=k/(w/(patch_size));
    end
    xmin = (r-1)*patch_size + 1; 
    ymin = (c-1)*patch_size + 1 ;
    
    %giving 1 
      for b = 1:patch_size 
       for a = 1:patch_size
           R((b - 1)*patch_size + a,(xmin-1 + b - 1)*w + ymin + (a-1),k) = 1 ;
       end 
      end
  
end 
end