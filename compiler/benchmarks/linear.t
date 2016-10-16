mu = 1; // learning rate
m = 3; // num of features

model_input x[m]; // Assume x[0] is 1
model_output y;
model w[m];
gradient g[m] -> w;

iterator i[0:m];

h = sum[i](w[i] * x[i]);
d = h - y;
g[i] = d * x[i];

// SGD added
//g[i] = mu * g[i];
//w[i] = w[i] - g[i];
