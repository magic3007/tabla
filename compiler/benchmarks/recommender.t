mu = 1;
m = 3; // num of movies
n = 3; // num of users
k = 2; // num of features

model_input x1[k]; //it is from the movies-feature model
model_input x2[k]; //it is from the users-feature model

model_output r1[m]; // 1 if the item is rated, 0 otherwise
model_output y1[m];

model_output r2[n]; // 1 if the item is rated, 0 otherwise
model_output y2[n];

model w1[m][k];
model w2[n][k];

gradient g1[m][k] -> w1;
gradient g2[n][k] -> w2;

iterator i[0:m];
iterator j[0:n];
iterator l[0:k];

h1[i] = sum[l](w1[i][l] * x2[l]) * r1[i];
h2[j] = sum[l](x1[l] * w2[j][l]) * r2[j];

d1[i] = h1[i] - y1[i];
d2[j] = h2[j] - y2[j];

g1[i][l] = d1[i] * x2[l];
g2[j][l] = d2[j] * x1[l];

// SGD added
//w1[i][l] = w1[i][l] - g1[i][l];
//w2[j][l] = w2[j][l] - g2[j][l];
