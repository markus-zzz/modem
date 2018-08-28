import numpy as np
import matplotlib.pyplot as plt

def sext16(x):
    r = int(x, 16)
    return r if r < 2**15 else r - 2**16

with open('stdout.txt') as my_file:
    array = my_file.readlines()

y = []

for a in array:
    y.append(sext16(a.rstrip()))

yy = np.asarray(y, dtype=float)
yy /= 2**13

print(yy)

plt.plot(yy)
plt.show()
