import matplotlib.pyplot as plt
from pylab import scatter, plot, show, title
from mpl_toolkits.mplot3d import Axes3D
import numpy as np

import math
from mlinterface import MLinterface
import json

class Logistic(MLinterface):
    plot_input = []
    
    def gradient(self, input_row, output_row):
        mul = [a * b for a, b in zip(input_row, self.model)]
        h = 0
        for num in mul:
            h += num
        h = self.sigmoid(h)
        d = h - output_row
        self.grad = [d * x for x in input_row]
        print(self.grad)

    def sgd(self):
        self.grad = [self.learn_rate * g for g in self.grad]
        print(self.grad)
        self.model = [w - g for w, g in zip(self.model, self.grad)]
        print('after one iteration, model: ', self.model)
        print('================')

    def logistic(self):
        for input_row, output_row in zip(self.model_input, self.model_output):
            print('input row: ', input_row, 'output_row: ', output_row)
            self.gradient(input_row, output_row)
            self.sgd()

    def sigmoid(self, num):
        print(num)
        print( 1 / (1 + math.exp(-num)))
        return 1 / (1 + math.exp(-num))

    def read_trainingFile(self, filename):
        datafile = open(filename, 'r')
        datastring = datafile.read()
        data = json.loads(datastring)
        self.model_input = data['model_input']
        for num in self.model_input:
            self.plot_input.append(num)
        for i,inputs in enumerate(self.model_input):
            self.model_input[i] = [1, self.model_input[i]]
        self.model_output = data['model_output']
        self.iterator = len(self.model_input[0])
        self.model = [1] * self.iterator
        print(self.model)

if __name__ == '__main__':
    l = Logistic()
    l.read_trainingFile('somedata.json')
    l.logistic()
    print(l.model_output)
    fig = plt.figure()
    plt.scatter(np.array(l.plot_input), np.array(l.model_output), marker='o', c='b')
    title('Logistic Regression with one feature')
    #show()

    x = range(30, 100)
    y = []
    for x_i in x:
        x_input = [1, x_i]
        mul = [a * b for a, b in zip(x_input, l.model)]
        sum = 0
        for num in mul:
            sum += num
        sum = l.sigmoid(sum)
        y.append(sum)
    plot(x, y)
    show()

