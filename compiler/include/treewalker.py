from TablaListener import TablaListener

class ProgramPrinter(TablaListener):
    counter = 0
    isLeft = True
    lineBuilder = ""
    inStat = False
    ssaTable = {}
    ssaFile = open("ssa.txt", "a")
    temp = {}
    var = ""

    def enterProgram(self, ctx):
        #print(ctx.children)
        print("program node entered ")

    def exitProgram(self, ctx):
        print("program node exited")

    def enterData_decl_list(self, ctx):
        print("Data_decl_list node entered ")

    def exitData_decl_list(self, ctx):
        print("Data_decl_list node exited")
        self.lineBuilder = ""

    # Enter a parse tree produced by TablaParser#data_decl.
    def enterData_decl(self, ctx):
        print("Data_decl rule entered")

    # Exit a parse tree produced by TablaParser#data_decl.
    def exitData_decl(self, ctx):
        if self.var is not '':
            valueFromTemp = self.temp[self.var]
            self.ssaTable[self.var] = valueFromTemp 
        self.counter += 1
        self.temp = {}
        self.var = ""
        print("Data_decl node exited")
        print(self.ssaTable)

    # Enter a parse tree produced by TablaParser#data_type.
    def enterData_type(self, ctx):
        idToken = ctx.ID()
        assignToken = ctx.ASSIGN()
        if assignToken is not None: # means var is on left side
            key = str(idToken)
            value = "#" + str(self.counter)
            ctx.setID(value) # setID() sets the symbol to the input value
            print(str(ctx.ID()))
            self.var = key
            self.temp[key] = value
            self.lineBuilder += value + " " + str(assignToken)
            if ctx.INTLIT() is not None:
                self.lineBuilder = self.lineBuilder + " " + str(ctx.INTLIT())
#            self.counter =+ 1
        print("Data_type node entered")

#            if key not in self.ssaTable:
#                self.ssaTable[key] = [value]
#            else:
#                value_list = self.ssaTable[key]
#                value_list.append(value)
#                self.ssaTable[key] = value_list
#            self.lineBuilder = value + " " + str(assignToken)
#            self.counter += 1
#            self.isLeft = False




    # Exit a parse tree produced by TablaParser#data_type.
    def exitData_type(self, ctx):
        self.isLeft = True
        self.lineBuilder += ";"
        print(self.lineBuilder)
        print("Data_type node exited")
        self.ssaFile.write(self.lineBuilder + "\n")
        self.lineBuilder = ""

    # Enter a parse tree produced by TablaParser#non_iterator.
    def enterNon_iterator(self, ctx):
        self.lineBuilder += ctx.getText()
        print("Non_iterator node entered")

    # Exit a parse tree produced by TablaParser#non_iterator.
    def exitNon_iterator(self, ctx):
        print("Non_iterator node exited")

    # Enter a parse tree produced by TablaParser#iterator.
    def enterIterator(self, ctx):
        self.lineBuilder += ctx.getText()
        print("iterator rule entered")

    # Exit a parse tree produced by TablaParser#iterator.
    def exitIterator(self, ctx):
        print("iterator rule exited")


    # Enter a parse tree produced by TablaParser#var_list.
    def enterVar_list(self, ctx):
        print("var_list rule entered")

    # Exit a parse tree produced by TablaParser#var_list.
    def exitVar_list(self, ctx):
        print("var_list rule exited")


    # Enter a parse tree produced by TablaParser#var.
    def enterVar(self, ctx):
        print("var rule entered")

    # Exit a parse tree produced by TablaParser#var.
    def exitVar(self, ctx):
        if self.inStat is True and self.isLeft is True:
            self.lineBuilder = self.lineBuilder + " =" 
            #self.inStat = False
        print("var rule exited")


    # Enter a parse tree produced by TablaParser#var_id.
    def enterVar_id(self, ctx):
        if self.isLeft is False:
#            print("BLAHHHHHHHHHHHHHHHH")
            key = str(ctx.ID())

#            if key not in self.ssaTable:
#                print("[ERROR] " + key + "is an undefined variable!")

            value = self.ssaTable[key]
            ctx.setID(value)
            print(str(ctx.ID()))
            self.lineBuilder += " " + value

#            if len(value_list) > 1:
#                value = value_list.pop(0)
#                self.ssaTable[key] = value_list
#                self.lineBuilder = self.lineBuilder + " " + value
#            elif len(value_list) is 1:
#                value = value_list[0]
#                self.lineBuilder = self.lineBuilder + " " + value
            print("[THIS IS RIGHT SIDE!!]var_id rule entered and ID is ", ctx.ID())
        elif self.isLeft is True:
#            print("BLAHHHHHHHHHHHHHHHH")
            key = str(ctx.ID())
            value = "#" + str(self.counter)
            ctx.setID(value)
            self.var = key
            self.temp[key] = value
#            self.lineBuilder += value + " " + str(assignToken)
            self.lineBuilder += " " + value
#            key = str(ctx.ID())
#            value = "#" + str(self.counter)
#            if key in self.ssaTable:
#                value_list = self.ssaTable[key]
#                value_list.append(value)
#                self.ssaTable[key] = value_list
#            else:
#                self.ssaTable[key] = [value]
#            if self.inStat is True:
#                self.lineBuilder += value
#            else:
#                self.lineBuilder += " " + value
#            self.counter = self.counter + 1
            print("[THIS IS LEFT SIDE!!]var_id rule entered and ID is ", ctx.ID())


    # Exit a parse tree produced by TablaParser#var_id.
    def exitVar_id(self, ctx):
        print("var_id rule exited")


    # Enter a parse tree produced by TablaParser#id_tail.
    def enterId_tail(self, ctx):
        if ctx.LEFT_BRACK() is not None:
            if ctx.ID() is not None:
                iter_id = str(ctx.ID())
                value = self.ssaTable[iter_id]
                ctx.setID(value)
                self.lineBuilder += "[" + str(ctx.ID()) + "]"
            elif ctx.INTLIT() is not None:
                self.lineBuilder += "[" + str(ctx.INTLIT()) + "]"
        print("id_tail rule entered")

    # Exit a parse tree produced by TablaParser#id_tail.
    def exitId_tail(self, ctx):
        print("id_tail rule exited")


    # Enter a parse tree produced by TablaParser#var_list_tail.
    def enterVar_list_tail(self, ctx):
        if ctx.children is not None:
            valueFromTemp = self.temp[self.var]
            self.ssaTable[self.var] = valueFromTemp 
            self.counter += 1
        print("var_list_tail rule entered")

    # Exit a parse tree produced by TablaParser#var_list_tail.
    def exitVar_list_tail(self, ctx):
        print("var_list_tail rule exited")


    # Enter a parse tree produced by TablaParser#var_list_iterator.
    def enterVar_list_iterator(self, ctx):
        idList = ctx.ID()
        key = str(idList[0])
        print(key)
        print(idList[1])
        value = "#" + str(self.counter)
        ctx.setID(value, 0)
        iterSize = str(idList[1])
        size = self.ssaTable[iterSize]
        ctx.setID(size, 1)
        print(str(ctx.ID()))
        self.var = key
        self.temp[key] = value

        self.lineBuilder += " " + ctx.getText()
#        self.lineBuilder += idList[0] + ctx.LEFT_BRACK() + ctx.COLON() + ctx.RIGHT_BRACK()
        print("var_list_iterator rule entered")

    # Exit a parse tree produced by TablaParser#var_list_iterator.
    def exitVar_list_iterator(self, ctx):
        print("var_list_iterator rule exited")


    # Enter a parse tree produced by TablaParser#stat_list.
    def enterStat_list(self, ctx):
        self.isLeft = True
        print("stat_list rule entered")
        self.lineBuilder = ""

    # Exit a parse tree produced by TablaParser#stat_list.
    def exitStat_list(self, ctx):
        self.Linebuilder = ""
        print("stat_list rule exited")
        self.lineBuilder = ""

    # Enter a parse tree produced by TablaParser#stat.
    def enterStat(self, ctx):
        self.inStat = True
        print("stat rule entered")

    # Exit a parse tree produced by TablaParser#stat.
    def exitStat(self, ctx):
        self.lineBuilder += ";"
        print(self.lineBuilder)
        self.ssaFile.write(self.lineBuilder + "\n")
        print("stat rule exited")
        self.lineBuilder = ""
        self.inStat = False

        valueFromTemp = self.temp[self.var]
        self.ssaTable[self.var] = valueFromTemp 
        self.counter += 1
        self.temp = {}
        self.var = ""


    # Enter a parse tree produced by TablaParser#expr.
    def enterExpr(self, ctx):
        print("expr rule entered")

    # Exit a parse tree produced by TablaParser#expr.
    def exitExpr(self, ctx):
        print("expr rule exited")


    # Enter a parse tree produced by TablaParser#function.
    def enterFunction(self, ctx):
        self.isLeft = False
        self.lineBuilder = self.lineBuilder + " " + ctx.getText()
        print("function rule entered and function is: ", ctx.getText())

    # Exit a parse tree produced by TablaParser#function.
    def exitFunction(self, ctx):
        print("function rule exited")


    # Enter a parse tree produced by TablaParser#function_args.
    def enterFunction_args(self, ctx):
        if ctx.LEFT_BRACK() is not None:
#            if ctx.ID() is not None:
            iter_id = str(ctx.ID())
            value = self.ssaTable[iter_id]
            ctx.setID(value)
            self.lineBuilder += "[" + str(ctx.ID()) + "]"
#            elif ctx.INTLIT() is not None:
#                self.lineBuilder += "[" + str(ctx.INTLIT()) + "]"

        self.lineBuilder += str(ctx.LEFT_PAREN())
        print("function_args rule entered")

    # Exit a parse tree produced by TablaParser#function_args.
    def exitFunction_args(self, ctx):
        self.lineBuilder = self.lineBuilder + str(ctx.RIGHT_PAREN())
        print("function_args rule exited")


    # Enter a parse tree produced by TablaParser#term2_tail.
    def enterTerm2_tail(self, ctx):
        print("term2_tail rule entered")

    # Exit a parse tree produced by TablaParser#term2_tail.
    def exitTerm2_tail(self, ctx):
        self.isLeft = True
        print("term2_tail rule exited")


    # Enter a parse tree produced by TablaParser#term2.
    def enterTerm2(self, ctx):
        self.isLeft = False
        print("term2 rule entered")

    # Exit a parse tree produced by TablaParser#term2.
    def exitTerm2(self, ctx):
        print("term2 rule exited")


    # Enter a parse tree produced by TablaParser#term1_tail.
    def enterTerm1_tail(self, ctx):
        print("term1_tail rule entered")

    # Exit a parse tree produced by TablaParser#term1_tail.
    def exitTerm1_tail(self, ctx):
        print("term1_tail rule exited")


    # Enter a parse tree produced by TablaParser#term1.
    def enterTerm1(self, ctx):
        print("term1 rule entered")

    # Exit a parse tree produced by TablaParser#term1.
    def exitTerm1(self, ctx):
        print("term1 rule exited")


    # Enter a parse tree produced by TablaParser#term0_tail.
    def enterTerm0_tail(self, ctx):
        print("term0_tail rule entered")

    # Exit a parse tree produced by TablaParser#term0_tail.
    def exitTerm0_tail(self, ctx):
        print("term0_tail rule exited")


    # Enter a parse tree produced by TablaParser#term0.
    def enterTerm0(self, ctx):
        if self.isLeft is False and ctx.INTLIT() is not None:
            self.lineBuilder = self.lineBuilder + " " + str(ctx.INTLIT())
            print("[THIS IS RIGHT SIDE]term0 rule entered ", ctx.INTLIT())
        elif self.isLeft is True:
            print("[THIS IS LEFT SIDE]term0 rule entered ", ctx.INTLIT())


    # Exit a parse tree produced by TablaParser#term0.
    def exitTerm0(self, ctx):
        print("term0 rule exited")


    # Enter a parse tree produced by TablaParser#mul_op.
    def enterMul_op(self, ctx):
        self.lineBuilder = self.lineBuilder + " " + ctx.getText()
        print("mul_op rule entered")

    # Exit a parse tree produced by TablaParser#mul_op.
    def exitMul_op(self, ctx):
        print("mul_op rule exited")


    # Enter a parse tree produced by TablaParser#add_op.
    def enterAdd_op(self, ctx):
        self.lineBuilder += " " + ctx.getText()
        print("add_op rule entered")

    # Exit a parse tree produced by TablaParser#add_op.
    def exitAdd_op(self, ctx):
        print("add_op rule exited")


    # Enter a parse tree produced by TablaParser#compare_op.
    def enterCompare_op(self, ctx):
        self.lineBuilder = self.lineBuilder + " " + ctx.getText()
        print("compare_op rule entered")

    # Exit a parse tree produced by TablaParser#compare_op.
    def exitCompare_op(self, ctx):
        print("compare_op rule exited")


