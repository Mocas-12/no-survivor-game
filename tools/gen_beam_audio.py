import math, random, struct, wave
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'assets/sounds'
SR=44100
rng=random.Random(619)
def write(name, samples):
    peak=max(max(map(abs,samples)),.001)
    data=b''.join(struct.pack('<h',int(max(-1,min(1,x/peak*.66))*32767)) for x in samples)
    with wave.open(str(OUT/name),'wb') as w:
        w.setparams((1,2,SR,0,'NONE','not compressed'));w.writeframes(data)
for variant in range(3):
    samples=[];phase=0
    for i in range(int(SR*.7)):
        t=i/SR;noise=rng.uniform(-1,1)
        if t<.12:
            p=t/.12;phase+=2*math.pi*(180+720*p)/SR
            s=(math.sin(phase)*.24+math.sin(phase*2.01)*.07)*p*p
        elif t<.20:
            p=(t-.12)/.08;phase+=2*math.pi*(280-170*p)/SR
            s=(math.sin(phase)*.75+noise*.24)*math.exp(-p*3)
        elif t<.58:
            p=(t-.20)/.38;phase+=2*math.pi*(155+variant*6)/SR
            s=(math.sin(phase)*.25+math.sin(phase*3.02)*.07+noise*.025)*(1+.12*math.sin(t*70))*min(1,p*20)
        else:
            p=(t-.58)/.12;phase+=2*math.pi*(180-100*p)/SR
            s=(math.sin(phase)*.24+noise*.03)*(1-p)**2
        samples.append(s*min(1,t/.008))
    write('beam-cycle-'+str(variant)+'.wav',samples)
samples=[];phase=0
for i in range(int(SR*.14)):
    t=i/SR;p=t/.14;phase+=2*math.pi*(1100-950*p)/SR
    samples.append((math.sin(phase)*.35+rng.uniform(-1,1)*.3)*min(1,t/.003)*(1-p)**3)
write('beam-impact.wav',samples)
print('BEAM_AUDIO four mono 44.1kHz PCM clips generated')
