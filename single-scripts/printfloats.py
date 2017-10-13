

NEND = 2**32 # 4294967296; 4294967296/2 = 2147483648
print(NEND)

def toBinary(n):
  return ''.join(str(1 & int(n) >> i) for i in range(32)[::-1])

import struct
def binToFloat(instr):
  i = int(instr, 2)
  return struct.unpack('f', struct.pack('I', i))[0]

# 2139095040 is inf; 2139095041+ is nan;
# 2147483648 : 10000000000000000000000000000000 is -0;
# 2147483649+ : 10000000000000000000000000000001+ are negative numbers from -1.40129846432e-45
# delta is -1.401298e-45

#~ i = 1
i = 2139093000 #2147483630 #2139095000
#~ for ix in range(0,NEND): # OverflowError: range() result has too many items
#~ for ix in xrange(0,NEND): # OverflowError: Python int too large to convert to C long
prevf = 0
while (i%NEND!=0):
#~ while (i%10!=0):
  strbin = toBinary(i)
  iflt = binToFloat(strbin)
  delta = iflt-prevf
  print("% 10i : %s : "%(i, strbin) + str(iflt) + " : %e\n\t%.150f"%(delta,iflt))
  i += 1
  prevf = iflt

# NB:
# 170: 0.00000000000000000000000000000000000000000001261168617892335363831356624960924518152235747688864194581361455500811974417274541337974369525909423828125000000000000000000000
# 170-21 = 149
