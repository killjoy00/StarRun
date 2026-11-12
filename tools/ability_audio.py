#!/usr/bin/env python3
"""Reproducible, original activation and ready cues for the additional abilities."""
from pathlib import Path
import wave
import numpy as np

RATE = 32000
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'

def write(name, sound):
    sound *= np.minimum(1, np.arange(len(sound)) / 120)
    sound *= np.minimum(1, np.arange(len(sound))[::-1] / 200)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes((np.tanh(sound) * 28000).astype('<i2').tobytes())

for index, name in enumerate(['barrage', 'overdrive', 'chrono', 'mend']):
    t = np.arange(int(RATE * 0.8)) / RATE
    base = [115, 185, 440, 550][index]
    sweep = [260, 500, -200, 160][index]
    signal = np.sin(2 * np.pi * (base * t + sweep * t * t))
    signal += 0.35 * np.sin(2 * np.pi * (base * 1.5 * t + sweep * t * t))
    envelope = np.exp(-t * [5, 4, 3, 4][index])
    if name == 'barrage':
        envelope *= (0.5 + 0.5 * np.cos(2 * np.pi * 12 * t)) ** 2
    write(name, signal * envelope * 0.48)
    ready = np.zeros_like(t)
    for offset, frequency in [(0, 660 + index * 70), (0.11, 880 + index * 70)]:
        age = np.maximum(0, t - offset)
        ready += np.where(t >= offset, np.sin(2 * np.pi * frequency * age) * np.exp(-age * 16), 0)
    write('ready-' + name, ready * 0.30)
print('Rendered eight ability cues')
