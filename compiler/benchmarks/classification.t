mu = 1;
m = 3; // num of features

model_input x[m];
model_output y;
model w[m];
gradient g[m] -> w;

iterator i[0:m];

h = sum[i](w[i] * x[i]);
c = y * h;
ny = 0 - y;
p = ((c > 1) * ny);
g[i] = p * x[i];

// SGD added
//g[i] = mu * g[i];
//w[i] = w[i] - g[i];
