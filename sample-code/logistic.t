mu = 1;
m = 3;

model_input x[m];
model_output y;
model w[m];
gradient g[m] -> w;

iterator i[0:m];

h = sum[i](w[i] * x[i]);
h = sigmoid(h);
d = h - y;
g[i] =  d * x[i];

// SDG
//g[i] = mu * g[i];
//w[i] = w[i] - g[i];
