"""Original deterministic two-layer impact synthesis, 44.1kHz mono PCM."""
import math, random, wave, struct
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/sounds'
for name,duration in [('metal_hit',.13),('heavy_hit',.23)]:
    rng=random.Random(47);data=[];sr=44100
    for i in range(int(sr*duration)):
        t=i/sr
        click=rng.uniform(-1,1)*math.exp(-t*65)*.22
        metal=sum(math.sin(math.tau*f*t)*math.exp(-t*k)*a for f,k,a in [(1430,38,.10),(2197,57,.07),(3611,74,.04)])
        low=math.sin(math.tau*(95*t-85*t*t))*math.exp(-t*19)*(.42 if name=='heavy_hit' else .09)
        sample=(click+metal+low)*min(1,t/.0007)
        data.append(struct.pack('<h',int(max(-1,min(1,sample))*32767)))
    with wave.open(str(out/(name+'.wav')),'wb') as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(sr);wav.writeframes(b''.join(data))
    print(name,len(data))
