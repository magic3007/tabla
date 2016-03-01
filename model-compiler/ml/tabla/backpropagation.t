// As an example, here we use a 4 layer neural system.
// The number of nodes in each layer is 2, 3, 3, 2, respectively.
l1 = 3; // Number of nodes + 1 because a0  = 1 is added to each layer
l2 = 4;
l3 = 4;
l4 = 3;

mu = 1;

model_input x[l1];	// Assume x[0] is 1
model_output y[l4];

model w12[l2][l1];	// Parameter for mapping from layer 1 to layer 2. w12[0][x] is never used
model w23[l3][l2];
model w34[l4][l3];

gradient g12[l2][l1] -> w12;
gradient g23[l3][l2] -> w23;
gradient g34[l4][l3] -> w34;

iterator il1_[0:l1];
iterator il2_[0:l2];
iterator il3_[0:l3];
iterator il4_[0:l4];

iterator il1[1:l1];
iterator il2[1:l2];
iterator il3[1:l3];
iterator il4[1:l4];

a1[0] = 1;
a2[il2] = sigmoid(sum[il1_](w12[il2][il1_] * x[il1_]));
a2[0] = 1;
a3[il3] = sigmoid(sum[il2_](w23[il3][il2_] * a2[il2_]));
a3[0] = 1;
h[il4] = sigmoid(sum[il3_](w34[il4][il3_] * a3[il3_]));

d4[il4] = h[il4] - y[il4]
d3[il3] = sum[il4](w34[il4][il3] * d4[il4]) * (a3[il3] * (1 - a3[il3]));
d2[il2] = sum[il3](w23[il3][il2] * d3[il3]) * (a2[il2] * (1 - a2[il2]));

g12[il2][il1_] = x[il1_] * d2[il2];
g23[il3][il2_] = a2[il2_] * d3[il3];
g34[il4][il3_] = a3[il3_] * d4[il4];

// SGD
//w12[il2][il1_] = w12[il2][il1_] - mu * g12[il2][il1_];
//w23[il3][il2_] = w23[il3][il2_] - mu * g23[il3][il2_];
//w34[il4][il3_] = w34[il4][il3_] - mu * g34[il4][il3_];
