m = 2;
m = 4;	// Test const reinitialization
n = 2;
model_input x[m];
model_input z[2], z'[2]; // Test integer
model_output y[n];
iterator i[0:4]; // Test integer
iterator j[0:n];
iterator k[2:4]; // Test non-zero start
gradient g[n][m];

s = sum[i](x[i] * 2);
h = sum[i](x[i] * 2);
h = norm[k](x[k] + n); // Test variable overwrite
a = m + n;
m = 5;	// Test if 5 is used for model_input; it shouldn't
m = 1 + 2; // Test const overwrite
b = m + n;
a = 1 + 2; // Test variable overwrite
