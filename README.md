# scap


## Problem Statement

Given 8 groups of data, with 10 elements each, process them using different 
techniques for parallelism and concurrency.

Some groups depend on other groups, these dependencies must be respected.

Groups: A, B, C, D, E, F

Rules:
- All A must be processed before any B
- B1 must be processed before C1, B2 before C2, and so on
- C1 must be processed before D1, C2 before D2, and so on
- All D must be processed before E
- All D must be processed before F


Dependencies: 

```
A <- B
B1 <- C1
C1 <- D1
A <- E
D <- E
D <- F
```
