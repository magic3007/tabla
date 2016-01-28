Welcome to the Tabla compiler!

Tabla is an innovative framework that accelerates a class of statistical machine learning algorithms. It consists of the domain specific language, design builder, predesigned template, and model compiler. This document will help you get up and running on the model compiler portion.

To run the compiler, run the following command:

$ python3 main.py <*.t file>

This generates a JSON representation of data flow graph and schedule each in a separate file. It also creates a Dot file for a visual representation of data flow graph. Note that this reflects the graph after scheduling is done; every node in the same horizontal level is the operations scheduled to execute in the same cycle. Run the following command to generate a jpeg file:

$ dot -Tjpeg <*.dot file> -o <filename>.jpeg