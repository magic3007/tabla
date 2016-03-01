import json

class MLinterface():
    def __init__(self):
        self.model_input = []
        self.model_output = []
        self.model = []
        self.grad = []
        self.iterator = 0
        self.learn_rate = 0.01
    
    def gradient(self):
        pass
    
    def sgd(self):
        pass    

    def read_trainingfile(self, filename):
        pass
