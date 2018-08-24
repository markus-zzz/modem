# PYTHONPATH=./tutorial-env/lib/python3.5/site-packages/commpy python rrc-coeffs.py

import numpy as np
import matplotlib.pyplot as plt
from commpy import filters

Fs = 1000 # Sampling rate of 1kHz
Ts = 0.01 # Symbol length of 10ms (i.e. 10 samples per symbol)

# the RRC filter should span 3 baseband samples to the left and to the right.
# Hence, it introduces a delay of 3Ts seconds.
t0 = 3*Ts

_, rrc = filters.rrcosfilter(N=int(2*t0*Fs), alpha=1,Ts=Ts, Fs=Fs)
t_rrc = np.arange(len(rrc)) / Fs
plt.plot(t_rrc/Ts, rrc)
plt.show()

# Now give us coefficients in A(2,13) format
for coeff in rrc:
    fp_coeff = int((2**13)*coeff);
    print(format(fp_coeff & 0xffff, '04x'))

