#!/usr/bin/env python3
"""Generate original, deterministic, periodic sleep textures. No sampled recordings.

Requires NumPy. Outputs 30-second mono 22,050 Hz 16-bit WAVs. The FFT
construction and modulation use complete cycles to avoid a hard loop splice.
"""
from pathlib import Path
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'App/Resources/SleepSounds'
RATE=22050
SECONDS=30
COUNT=RATE*SECONDS

def texture(rng,power):
    frequency=np.fft.rfftfreq(COUNT,1/RATE)
    safe=np.maximum(frequency,1)
    # Remove DC and suppress sub-bass; attenuate the very highest frequencies.
    spectrum=(rng.normal(size=len(frequency))+1j*rng.normal(size=len(frequency)))
    spectrum*=safe**(-power/2)*(frequency/(frequency+25))**2/np.sqrt(1+(frequency/8000)**6)
    spectrum[0]=0
    spectrum[-1]=spectrum[-1].real
    samples=np.fft.irfft(spectrum,n=COUNT)
    return samples/np.std(samples)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    rng=np.random.default_rng(20261111)
    t=np.arange(COUNT)/RATE
    white=texture(rng,0);pink=texture(rng,1);brown=texture(rng,2)
    sounds={
        'white':white,
        'pink':pink,
        'brown':brown,
        'rain':(0.65*texture(rng,0.5)+0.35*texture(rng,1.5))*(0.88+0.08*np.cos(2*np.pi*3*t/SECONDS)+0.04*np.cos(2*np.pi*7*t/SECONDS)),
        'ocean':texture(rng,1.35)*(0.50+0.28*np.cos(2*np.pi*3*t/SECONDS)+0.12*np.cos(2*np.pi*2*t/SECONDS)),
        'fan':0.85*texture(rng,1.5)+0.06*np.sin(2*np.pi*90*t)+0.025*np.sin(2*np.pi*180*t)
    }
    for name,samples in sounds.items():
        samples-=samples.mean()
        samples*=min(0.12/np.sqrt(np.mean(samples*samples)),0.62/np.max(np.abs(samples)))
        pcm=np.round(samples*32767).astype('<i2')
        path=OUT/f'{name}.wav'
        with wave.open(str(path),'wb') as f:
            f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
        print(f'{name}: {SECONDS}s, peak={max(abs(samples)):.3f}, RMS={np.sqrt(np.mean(samples*samples)):.3f}, {path.stat().st_size} bytes')

if __name__=='__main__':main()
