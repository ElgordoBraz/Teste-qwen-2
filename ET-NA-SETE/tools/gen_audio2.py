#!/usr/bin/env python3
"""Gerador vetorial (numpy) de audio do ET NA SETE. Substitui loops lentos."""
import numpy as np, struct, os
SR=44100
OUT=os.path.normpath(os.path.join(os.path.dirname(__file__),"..","assets","audio"))
os.makedirs(OUT,exist_ok=True)
rng=np.random.default_rng(7)

def write(name,x):
    x=np.asarray(x,dtype=np.float64)
    if x.size==0: return
    k=0.85/max(1e-9,np.max(np.abs(x)))
    data=(np.clip(x*k,-1,1)*32767).astype("<i2").tobytes()
    with open(os.path.join(OUT,name+".wav"),"wb") as f:
        f.write(b"RIFF"+struct.pack("<I",36+len(data))+b"WAVEfmt "+struct.pack("<IHHIIHH",16,1,1,SR,SR*2,2,16))
        f.write(b"data"+struct.pack("<I",len(data))+data)
    print("ok",name)

def t(dur): return np.arange(int(SR*dur))/SR
def adenv(n,a=0.01):
    tt=np.linspace(0,1,n)
    e=np.where(tt<a, tt/max(a,1e-9), 1.0)
    e=np.where(tt>a+(1-a)*0.15, np.maximum(0,1-(tt-a-0.15)/(1-a-0.15)), e)
    return e
def tone(f,dur,wave="sine"):
    ts=t(dur); ph=2*np.pi*f*ts
    v=np.sin(ph) if wave=="sine" else np.sign(np.sin(ph))*0.6 if wave=="square" else (2*((f*ts)%1)-1)
    return v*adenv(len(ts))
def gunshot(ms,lp,boom):
    n=int(SR*ms/1000); ts=t(ms/1000)
    ns=rng.uniform(-1,1,n)
    # filtro simples exponencial vetorizado via lfilter-like accumulate
    y=np.zeros(n); prev=0.0
    # implementacao rapida: usa convolucao com kernel exp
    L=min(n,512); kern=lp**np.arange(L); kern/=kern.sum()
    y=np.convolve(ns,kern,mode="full")[:n]
    bass=np.sin(2*np.pi*70*ts)*boom*(1-ts/(ms/1000))
    e=np.maximum(0,1-(ts/(ms/1000))**0.35)
    return (y*1.4+bass)*e
def explosion():
    n=int(SR*0.9); ts=t(0.9)
    ns=rng.uniform(-1,1,n)
    L=1024; kern=0.92**np.arange(L); kern/=kern.sum()
    y=np.convolve(ns,kern,mode="full")[:n]
    e=np.maximum(0,1-(ts/0.9)**0.5)
    th=np.sin(2*np.pi*(45-25*ts/0.9)*ts)*e
    return (y*1.2+th)*e
def slurp(dur):
    ts=t(dur); f=200+500*np.sin(ts*9)*(1-ts/dur)
    ph=2*np.pi*np.cumsum(f)/SR
    return (np.sin(ph)*0.7+rng.uniform(-0.15,0.15,len(ts)))*(1-ts/dur)
def zap(f0,f1,dur):
    ts=t(dur); f=f0+(f1-f0)*ts/dur
    ph=2*np.pi*np.cumsum(f)/SR
    return np.sin(ph)*(1-ts/dur)
def boss_roar():
    ts=t(1.2); f=60+40*np.sin(ts*5)
    ph=2*np.pi*np.cumsum(f)/SR
    v=np.sin(ph)+0.5*np.sin(2*ph)
    e=np.minimum(1,ts*6)*(1-ts*0.8)
    return v*e*0.9+rng.uniform(-0.08,0.08,len(ts))*e
def ambient(dur=6.0):
    ts=t(dur)
    return 0.25*np.sin(2*np.pi*58*ts)+0.12*np.sin(2*np.pi*87*ts)+0.05*np.sin(2*np.pi*174*ts)
def music(dur=8.0):
    ts=t(dur); beat=60.0/100
    b=(ts/beat).astype(int)
    bass=np.where(b%2==0,110.0,82.4)
    phb=2*np.pi*np.cumsum(bass)/SR
    v=0.35*np.sin(phb)*(1-((ts%beat)/beat)*0.7)
    scale=[220.0,261.6,329.6,392.0,440.0]
    fs=np.array([scale[(int(bb)*3)%5] for bb in b])
    php=2*np.pi*np.cumsum(fs)/SR
    v+=0.12*np.sin(php)*np.maximum(0,1-((ts%beat)/beat)*1.6)
    return v
def beep3():
    return np.concatenate([tone(880,0.05),np.zeros(int(SR*0.08)),tone(880,0.05),np.zeros(int(SR*0.08)),tone(1320,0.1)])

write("shoot_pistol",gunshot(0.15,0.35,1.0))
write("shoot_rifle",gunshot(0.11,0.45,0.8))
write("shoot_shotgun",gunshot(0.26,0.25,1.6))
write("reload",np.concatenate([gunshot(0.06,0.6,0.4)*0.5,np.zeros(int(SR*0.06)),gunshot(0.07,0.5,0.5)*0.6,np.zeros(int(SR*0.1))]))
write("empty",tone(180,0.06,"square"))
write("impact_flesh",slurp(0.18))
write("impact_wall",gunshot(0.05,0.6,0.3)*0.5)
write("explosion",explosion())
write("mine_arm",beep3())
write("acid_shoot",zap(1100,260,0.3))
write("enemy_hit",slurp(0.22))
write("enemy_die",-slurp(0.4)[::-1])
write("player_hurt",tone(140,0.25,"saw"))
write("pickup",np.concatenate([tone(660,0.08),tone(990,0.12)]))
write("coin",np.concatenate([tone(1200,0.05),tone(1600,0.09)]))
write("buy",np.concatenate([tone(520,0.07),tone(780,0.07),tone(1040,0.14)]))
write("deny",np.concatenate([tone(220,0.12,"square"),tone(160,0.18,"square")]))
write("whoosh",np.convolve(rng.uniform(-1,1,int(SR*0.25)),0.2*np.exp(-np.arange(64)),mode="full")[:int(SR*0.25)]*np.sin(np.linspace(0,np.pi,int(SR*0.25))))
write("step",rng.uniform(-1,1,int(SR*0.07))*np.linspace(0.4,0,int(SR*0.07)))
write("wave_start",np.concatenate([tone(440,0.18,"square"),np.zeros(int(SR*0.05)),tone(660,0.18,"square"),np.zeros(int(SR*0.05)),tone(880,0.3,"square")]))
write("gate_open",np.concatenate([explosion()[:int(SR*0.5)]*0.8,tone(330,0.3)]))
write("boss_roar",boss_roar())
write("victory",np.concatenate([tone(523,0.22),tone(659,0.22),tone(784,0.22),tone(1046,0.22),tone(1318,0.5)]))
write("defeat",np.concatenate([tone(392,0.35,"saw"),tone(330,0.35,"saw"),tone(262,0.35,"saw"),tone(196,0.35,"saw")]))
write("ambient",ambient(6.0))
write("music",music(8.0))
write("ui_click",tone(700,0.05))
print("done")
