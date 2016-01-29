# Welcome to Tabla!

Tabla is an innovative framework that accelerates a class of statistical machine learning algorithms. It consists of a domain specific language, Design Builder, a predesigned template, and a model compiler. This document will help you get up and running on the model compiler portion.  


### Dependencies  
The parser is implemented with ANTLR v4.5 parser generator, with Python 3.4.3 as the target language. You also need Java Runtime Environment 1.6 or higher in order to run the compiler, since ANTLR is primarily written in Java. Please refer to the respective online resources in order to install them on your environment.  


### How to invoke the compiler   
To run the compiler, run the following command:

```
$ python3 main.py <*.t file>
```


This generates a JSON representation of data flow graph and schedule each in a separate file. It also creates a Dot file for a visual representation of data flow graph. Note that this reflects the graph after scheduling is done; every node in the same horizontal level is the operations scheduled to execute in the same cycle. Run the following command to generate a jpeg file:

```
$ dot -Tjpeg <*.dot file> -o <filename>.jpeg
```  

### To generate lexer and parser directly  
Run the following command:

```
$ java -cp "/usr/local/lib/antlr-4.5-complete.jar:$CLASSPATH" org.antlr.v4.Tool -Dlanguage=Python3 Tabla.g
```

If you would like to see the lexer tokens, run:

```
$ python3 pygrun.py Tabla program --tokens TEST_FILE
```  

### Developers
This compiler was developed by Joon Kyung Kim and Chenkai Shao, both undergraduate students at Georgia Institute of Technology. For any inquiries, please contact *jkkim@gatech.edu* or *cshao31@gatech.edu*.