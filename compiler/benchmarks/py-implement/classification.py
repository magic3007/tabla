class Classification(MLinterface):
    def gradient(self, input_row, output_row):
        mul = [a * b for a, b in zip(input_row, self.model)]
        h = 0
        for num in mul:
            h += num
        c = output_row * h
        c = 1 if c > 1 else -1
        gradient_row = [c * -output_row * x for x in input_row]
        return gradient_row

    def sgd(self, gradient):
        gradient = [self.meta * g for g in gradient]
        self.model = [w - g for w, g in zip(self.model, gradient)]

    def classification(self):
        for input_row, output_row in zip(self.model_input, self.model_output):
            gradient_row = self.gradient(input_row, output_row)
            self.sgd(gradient_row)
