import matplotlib.pyplot as plt
from pylab import scatter, plot, show, title
from mpl_toolkits.mplot3d import Axes3D
import numpy as np

from mlinterface import MLinterface
import json

class Linear(MLinterface):
    plot_input = []
    def gradient(self, input_row, output_row):
        mul = [a * b for a, b in zip(input_row, self.model)]
        print('model model_input multiplied: ', mul)
        h = 0
        for num in mul:
            h += num
        print('sum: ', h)
        d = h - output_row
        print('diff: ', d)
        self.grad = [d * x for x in input_row]
        print('gradient is: ', self.grad)

    def sgd(self):
        self.grad = [self.learn_rate * g for g in self.grad]
        self.model = [w - g for w, g in zip(self.model, self.grad)]
        print('after one iteration, model: ', self.model)
        print('==================')

    def linear(self):
        # for each row in training set:
        for input_row, output_row in zip(self.model_input, self.model_output):
            print('data read: ', input_row, output_row)
            print('model: ', self.model)
            self.gradient(input_row, output_row)
            self.sgd()

    def read_trainingFile(self, filename):
        datafile = open(filename, 'r')
        datastring = datafile.read()
        data = json.loads(datastring)
        self.model_input = data['model_input']
        for num in self.model_input:
            #self.plot_input_x.append(num[0])
            #self.plot_input_y.append(num[1])
            self.plot_input.append(num)
        #for inputs in self.model_input:
        #    inputs.insert(0, 1)
        for i,inputs in enumerate(self.model_input):
            self.model_input[i] = [1, self.model_input[i]]
        self.model_output = data['model_output']
        self.iterator = len(self.model_input[0])
        self.model = [1] * self.iterator
        
if __name__ == '__main__':
    l = Linear()
    l.read_trainingFile('somedata.json')
    l.linear()
    #print('learned model params are: ', l.model)
    #print('plot input and model input are same: ', l.plot_input == l.model_input)
    #print(l.plot_input)
    print(l.model_output)
    #print('the lengths are: ',len(np.array(l.plot_input)), len(np.array(l.model_output)))
    fig = plt.figure()
    #ax = fig.add_subplot(111, projection='3d')
    #ax.scatter(np.array(l.plot_input_x), np.array(l.plot_input_y),  np.array(l.model_output), marker='o', c='b')
    print('plotinput: ',np.array(l.plot_input))
    print('model output: ', np.array(l.model_output))
    plt.scatter(np.array(l.plot_input), np.array(l.model_output), marker='o', c='b')
    title('Linear Regression with Two Features')
    x = range(30)
    y = []
    for x_i in x:
        x_input = [1, x_i]
        mul = [a * b for a, b in zip(x_input, l.model)]
        sum = 0
        for num in mul:
            sum += num
        y.append(sum)
    plot(x, y)

    '''
    X, Y = np.meshgrid(np.array(l.plot_input_x), np.array(l.plot_input_y))
    print (X)
    print (Y)
    Z = l.model [0] + X * l.model [1] + Y * l.model [2]
    #Z = [a * b for a, b in l.model_input, l.model]
    ax.plot_surface(X, Y, Z)
    '''
    show()
