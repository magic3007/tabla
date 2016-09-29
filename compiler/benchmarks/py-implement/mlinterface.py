class MLinterface():
    def __init__(self, model_input, model, model_ouput, gradient, iterator, meta):
        self.model_input = model_input
        self.model = model
        self.model_output = model_outut
        self.gradient = gradient
        self.iterator = iterator
        self.meta = meta

    def gradient(self):
        pass
    
    def sgd(self):
        pass    

    def read_trainingfile(self):
        pass
