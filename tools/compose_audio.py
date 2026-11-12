#!/usr/bin/env python3
"""Original StarRun score and sound design. Requires numpy, scipy, ffmpeg.
No recorded samples or third-party music are used. Assets are committed for builds.
"""
from pathlib import Path
import numpy as np
import subprocess
import wave
from scipy.signal import butter, sosfilt

SR = 32000
BPM = 112
BEAT = 60 / BPM
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4419)

def hz(note): return 440 * 2 ** ((note - 69) / 12)
def noise(n, cutoff=1800):
    return sosfilt(butter(2, cutoff, fs=SR, btype='highpass', output='sos'), rng.normal(size=n))
def tone(freq, t): return np.sin(2*np.pi*freq*t)
def write(name, audio, music=False):
    audio = np.tanh(audio * 1.15)
    audio *= min(1.0, .94 / max(.001, np.max(np.abs(audio))))
    fade = min(128, len(audio)//10)
    ramp = np.linspace(0,1,fade)
    if audio.ndim == 2: ramp = ramp[:,None]
    audio[:fade] *= ramp
    audio[-fade:] *= ramp[::-1]
    destination = OUT / (name + ('.ogg' if music else '.wav'))
    channels = 2 if audio.ndim == 2 else 1
    pcm = (audio*32767).astype('<i2').tobytes()
    if music:
        subprocess.run(['ffmpeg','-v','error','-y','-f','s16le','-ar',str(SR),'-ac',str(channels),'-i','pipe:0','-c:a','libvorbis','-q:a','5',str(destination)],input=pcm,check=True)
    else:
        with wave.open(str(destination),'wb') as file:
            file.setnchannels(channels); file.setsampwidth(2); file.setframerate(SR); file.writeframes(pcm)
def add(track, sample, when, gain=1, pan=0):
    start=int(when*SR); end=min(len(track),start+len(sample))
    if start>=len(track): return
    n=end-start
    track[start:end,0] += sample[:n]*gain*np.sqrt((1-pan)/2)
    track[start:end,1] += sample[:n]*gain*np.sqrt((1+pan)/2)
def synth_note(note,duration,kind='pluck'):
    t=np.arange(int(duration*SR))/SR
    f=hz(note)
    if kind=='bass':
        wave=sum(tone(f*k,t)/k**1.6 for k in range(1,7)) + tone(f/2,t)*.35
        env=(1-np.exp(-t*180))*np.exp(-t*6)
    else:
        wave=tone(f,t)+.24*tone(f*2,t)+.1*tone(f*3,t)
        env=(1-np.exp(-t*300))*np.exp(-t*8)
    return wave*env

def score(boss=False):
    duration=64*BEAT; n=int(duration*SR)
    track=np.zeros((n,2))
    t=np.arange(int(.5*SR))/SR
    kick=np.sin(2*np.pi*(48*t+105*(1-np.exp(-t*32))/32))*np.exp(-t*15)
    kick+=noise(len(t),7000)*np.exp(-t*150)*.07
    snare=(noise(len(t),1500)*.48+tone(175,t)*.17)*np.exp(-t*21)
    ht=np.arange(int(.12*SR))/SR
    hat=noise(len(ht),6500)*np.exp(-ht*65)*.15
    roots=[40,40,36,36,33,33,35,35]*2
    chord_types=[[0,3,7,14],[0,3,7,14],[0,4,7,11],[0,4,7,11],[0,3,7,14],[0,3,7,14],[0,5,7,10],[0,4,7,10]]*2
    arp=[0,2,1,3,2,1,3,2]
    for bar,(root,chord) in enumerate(zip(roots,chord_types)):
        start=bar*4*BEAT
        pt=np.arange(int(4*BEAT*SR))/SR
        env=np.minimum(1,pt/.3)*np.minimum(1,(4*BEAT-pt)/.4)
        for k,interval in enumerate(chord):
            f=hz(root+12+interval)
            pad=(tone(f,pt)+tone(f*1.003,pt)*.5+tone(f*.998,pt)*.3)*env
            add(track,pad,start,.038 if not boss else .026,(-1 if k%2 else 1)*.65)
        for beat in range(4):
            now=start+beat*BEAT
            add(track,kick,now,.50 if boss else .38)
            if beat in [1,3]: add(track,snare,now,.58 if boss else .39,.08)
        for step in range(8):
            now=start+step*BEAT/2
            add(track,hat,now,.6 if step%2 else .3,(-1 if step%2 else 1)*.35)
            bass_note=root+(12 if step in [3,7] else 0)
            add(track,synth_note(bass_note,BEAT*.48,'bass'),now,.16 if boss else .13)
            add(track,synth_note(root+24+chord[arp[step]],BEAT*.8),now,.055 if not boss else .08,(-1 if step%2 else 1)*.45)
        if boss:
            for step in range(16):
                if step%2:
                    add(track,hat,start+step*BEAT/4,.38,.5 if step%4==1 else -.5)
            for j,interval in enumerate([7,10,7,3,0,3,7,12]):
                if bar%4 in [2,3]:
                    add(track,synth_note(root+24+interval,BEAT*.8),start+j*BEAT/2,.075,np.sin(j)*.4)
            if bar%4==3:
                for fill in [0,1,2,3]: add(track,snare,start+(3+fill/4)*BEAT,.16+fill*.035,fill*.15-.3)
    # Stereo dotted-eighth echo wraps with the musical loop.
    delay=int(BEAT*.75*SR)
    track+=np.roll(track[:,::-1],delay,axis=0)*.12+np.roll(track,delay*2,axis=0)*.045
    write('score-boss' if boss else 'score-cruise',track,True)

score(False); score(True)

def sfx(name,duration,render):
    t=np.arange(int(duration*SR))/SR
    mono=render(t)
    stereo=np.column_stack([mono,mono])
    delay=int(.035*SR)
    if len(mono)>delay:
        stereo[delay:,1]+=mono[:-delay]*.12
    write(name,stereo)

sfx('pulse',.16,lambda t: (np.sin(2*np.pi*(1100*t-2350*t*t))*.48+noise(len(t),3500)*.10)*np.exp(-t*32))
sfx('seeker',.30,lambda t: (noise(len(t),1200)*.34+np.sin(2*np.pi*(135*t+330*t*t))*.24)*np.exp(-t*15))
sfx('explosion',.68,lambda t: (noise(len(t),170)*.38*np.exp(-t*7)+np.sin(2*np.pi*(58*t+60*(1-np.exp(-t*25))/25))*.7*np.exp(-t*9)))
sfx('boss-explosion',1.6,lambda t: noise(len(t),100)*.45*np.exp(-t*3)+np.sin(2*np.pi*(32*t+65*(1-np.exp(-t*12))/12))*.9*np.exp(-t*3.4))
sfx('aegis',.55,lambda t: (tone(330,t)+.4*tone(495,t)+.3*tone(660,t))*.28*(1-np.exp(-t*60))*np.exp(-t*7)+noise(len(t),4500)*.05*np.exp(-t*8))
sfx('nova',1.1,lambda t: (np.sin(2*np.pi*(38*t+190*(1-np.exp(-t*18))/18))*.78+noise(len(t),600)*.38)*np.exp(-t*5))
sfx('hit',.18,lambda t: (noise(len(t),800)*.6+tone(90,t)*.3)*np.exp(-t*35))
sfx('shield-break',.65,lambda t: (noise(len(t),3000)*.5+tone(1370,t)*.13+tone(1997,t)*.1)*np.exp(-t*10))
sfx('warning',.8,lambda t: (np.sin(2*np.pi*(200*t+620*t*t))*.32+noise(len(t),2400)*.08)*np.minimum(1,t*10)*np.minimum(1,(.8-t)*8))
sfx('low-hull',.6,lambda t: (tone(180,t)*.35+tone(360,t)*.15)*(np.exp(-t*22)+np.where(t>.23,np.exp(-np.maximum(0,t-.23)*22),0)))
for name,notes in [('ready-aegis',[76,79]),('ready-nova',[69,76]),('card',[64,67,71,76]),('start',[52,59,64,67]),('victory',[64,67,71,76,79]),('defeat',[52,48,45])]:
    a=np.zeros((int(1.3*SR),2))
    for j,note in enumerate(notes): add(a,synth_note(note,.6),j*.09,.25,j/len(notes)-.5)
    write(name,a)
t=np.arange(2*SR)/SR
hum=(tone(55,t)*.2+tone(110,t)*.08+tone(165,t)*.025)*(1+.06*np.sin(2*np.pi*2*t))
write('engine',np.column_stack([hum,hum]),True)
print('Rendered two original 16-bar scores, engine loop, and 16 effects to',OUT)
