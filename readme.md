./dfa dfa1.txt ababab	1
./dfa dfa1.txt ab	0
./dfa dfa1.txt ""	1 (empty string, start state accepts)
./dfa dfa2.txt aaa	1
./dfa nofile.txt a	prints “could not read”, because the function returned NULL