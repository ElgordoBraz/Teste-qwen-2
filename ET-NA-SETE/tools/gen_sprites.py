#!/usr/bin/env python3
"""
ET NA SETE - Gerador procedural de sprites (arte original, estilo quadrinho BR).
Produz PNGs com contorno forte para:
 - Protagonista "cria de BH": 8 direcoes x estados (idle, run, aim, shoot, melee)
 - Alienigenas comum / corredor / atirador / tanque: 4 direcoes x (walkA, walkB, hit, death)
 - Chefe "O Lorde": idle x2 e morte
 - Itens coletaveis, icones de armas, retrato do jogador.
Substituicao futura por arte final: manter os MESMOS nomes de arquivo em assets/.
Uso: python3 tools/gen_sprites.py
"""
import math, os
from PIL import Image, ImageDraw

BASE = os.path.join(os.path.dirname(__file__), "..", "assets")
PAL = dict(
    skin="#C8875B", skin_d="#9A613A",
    hoodie="#1A1A1A", hoodie_d="#000000", print_purple="#7A2E8F", print_red="#B3261E",
    hair="#F8F9FA", hair_s="#D7DBDD", lens="#FF8C00", frame="#C0C0C0", gold="#FFD700",
    shorts_bw="#EDEDED", ink="#111111", flipflop="#1D4ED8", flipstrap="#111111",
    pack="#6B7280", tube_r="#FF3B30", tube_g="#39FF14", visor="#00E5FF", outline="#0A0A0A",
    ali="#7ED92B", ali_d="#3F7A10", brain="#FF4B8C", eye="#FFEB00", goo="#00E5FF",
    tank="#4FA814", bone="#D9E2C8", metal="#8A8F98", wood="#8B5A2B",
)
def hx(h):
    h=h.lstrip("#"); return tuple(int(h[i:i+2],16) for i in (0,2,4))

def ell(d,c,rx,ry=None,fill="white",ol=4):
    if ry is None: ry=rx
    d.ellipse([c[0]-rx,c[1]-ry,c[0]+rx,c[1]+ry],fill=fill,
              outline=PAL["outline"] if ol else None,width=ol or 1)

def poly(d,pts,fill="white",ol=4):
    d.polygon(pts,fill=fill)
    if ol:
        pl=pts+[pts[0]]
        for i in range(len(pl)-1):
            a,b=pl[i],pl[i+1]
            ang=math.atan2(b[1]-a[1],b[0]-a[0])+math.pi/2; off=ol/2.0
            da=(math.cos(ang)*off,math.sin(ang)*off)
            d.line([(a[0]+da[0],a[1]+da[1]),(b[0]+da[0],b[1]+da[1])],fill=PAL["outline"],width=ol)
            d.line([(a[0]-da[0],a[1]-da[1]),(b[0]-da[0],b[1]-da[1])],fill=PAL["outline"],width=ol)

def limb(_cv,a,b,w,color,ol=4):
    mx,my=(a[0]+b[0])/2,(a[1]+b[1])/2
    ang=math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
    L=int(math.hypot(b[0]-a[0],b[1]-a[1]))+w*4
    part=Image.new("RGBA",(L,int(w)+8),(0,0,0,0))
    pd=ImageDraw.Draw(part)
    pd.rounded_rectangle([2,1,L-2,int(w)+7],radius=w/2,fill=color,outline=PAL["outline"],width=ol)
    part=part.rotate(-ang,expand=True,resample=Image.BICUBIC)
    return part,(mx-part.width/2,my-part.height/2)

def paste_limb(cv,a,b,w,color,ol=4):
    p,pos=limb(cv,a,b,w,color,ol)
    cv.alpha_composite(p,(int(pos[0]),int(pos[1])))

def draw_gun(cv,sh,hand,flash=False,kind="pistol"):
    ang=math.atan2(hand[1]-sh[1],hand[0]-sh[0])
    ln={"pistol":46,"rifle":86,"shotgun":70}[kind]; wd={"pistol":14,"rifle":16,"shotgun":20}[kind]
    part=Image.new("RGBA",(ln+wd*3,wd+14),(0,0,0,0))
    pd=ImageDraw.Draw(part)
    col=PAL["ink"] if kind=="pistol" else PAL["metal"]
    pd.rounded_rectangle([3,4,ln+wd,wd+11],radius=5,fill=col,outline=PAL["outline"],width=4)
    if kind=="pistol":
        pd.polygon([(8,wd+8),(20,wd+8),(16,wd+22),(6,wd+20)],fill=col,outline=PAL["outline"])
    if kind=="rifle":
        pd.rectangle([ln-10,2,ln+wd+4,wd+13],fill=PAL["wood"],outline=PAL["outline"],width=3)
        pd.rectangle([12,0,28,6],fill=PAL["tube_g"],outline=PAL["outline"],width=2)
        pd.polygon([(30,wd+8),(46,wd+8),(42,wd+22),(32,wd+20)],fill=PAL["ink"],outline=PAL["outline"])
    if kind=="shotgun":
        pd.rectangle([8,wd+4,ln,wd+12],fill=PAL["wood"],outline=PAL["outline"],width=3)
    part=part.rotate(-math.degrees(ang),expand=True,resample=Image.BICUBIC)
    cv.alpha_composite(part,(int(hand[0]-part.width/2),int(hand[1]-part.height/2)))
    if flash:
        fd=ImageDraw.Draw(cv)
        fx=hand[0]+math.cos(ang)*(ln+16); fy=hand[1]+math.sin(ang)*(ln+16)
        for r,c in ((26,hx("#FFDC50")),(13,(255,255,255))):
            fd.polygon([(fx+math.cos(a)*r,fy+math.sin(a)*r) for a in [i*math.pi/3 for i in range(6)]],fill=c)

DIRS8=["front","fr","right","br","back","bl","left","fl"]
def dir_offsets(direction):
    t={"front":(0,1,False),"fr":(.7,.7,True),"right":(1,0,True),"br":(.7,-.7,True),
       "back":(0,-1,False),"bl":(-.7,-.7,False),"left":(-1,0,False),"fl":(-.7,.7,False)}
    return t[direction]

def player_sprite(state="idle",direction="front",t=0.0,weapon="pistol"):
    W,H=256,384
    cv=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(cv)
    lat,dp,flip=dir_offsets(direction); cx=W/2
    bob={"idle":math.sin(t*2)*2,"run":abs(math.sin(t*9))*-6}.get(state,0)
    base_y=H-34+bob
    lean=6*lat
    stride=math.sin(t*9)*16 if state=="run" else 0
    hip=(cx+lean*0.4,base_y-92)
    kick = state=="melee"
    for sgn,ph in ((-1,stride),(1,-stride)):
        if kick and sgn==1:
            knee=(hip[0]+sgn*26,base_y-78); foot=(knee[0]+34,knee[1]-4)
            paste_limb(cv,hip,knee,20,PAL["skin"]); paste_limb(cv,knee,foot,16,PAL["skin"])
            fd=ImageDraw.Draw(cv)
            fd.rounded_rectangle([foot[0]-4,foot[1]-16,foot[0]+26,foot[1]+8],radius=7,
                                 fill=PAL["flipflop"],outline=PAL["outline"],width=4)
            continue
        knee=(hip[0]+sgn*10*max(0.35,1-abs(lat))+sgn*8*lat+ph*0.3,base_y-46)
        foot=(knee[0]+sgn*4+ph*0.5,base_y-4)
        paste_limb(cv,hip,knee,20,PAL["skin"]); paste_limb(cv,knee,foot,16,PAL["skin"])
        fd=ImageDraw.Draw(cv)
        fd.rounded_rectangle([foot[0]-14,foot[1]-6,foot[0]+14,foot[1]+6],radius=6,
                             fill=PAL["flipflop"],outline=PAL["outline"],width=4)
    sk=Image.new("RGBA",(70,70),(0,0,0,0)); sd=ImageDraw.Draw(sk)
    sd.rounded_rectangle([4,4,66,58],radius=14,fill=PAL["shorts_bw"],outline=PAL["outline"],width=5)
    for i in range(5):
        if i%2==0:
            sd.polygon([(8+i*12,8),(16+i*12,10),(12+i*12,54),(4+i*12,52)],fill=PAL["ink"])
    cv.alpha_composite(sk,(int(cx-35+lean),int(base_y-118)))
    th=118
    torso=Image.new("RGBA",(112,th+12),(0,0,0,0)); td=ImageDraw.Draw(torso)
    td.rounded_rectangle([6,6,106,th+6],radius=26,fill=PAL["hoodie"],outline=PAL["outline"],width=5)
    td.polygon([(30,26),(58,20),(70,60),(44,72)],fill=hx(PAL["print_purple"]))
    td.polygon([(52,40),(84,34),(78,84),(48,80)],fill=hx(PAL["print_red"]))
    td.rounded_rectangle([16,54,94,104],radius=10,outline=PAL["hoodie_d"],width=4)
    cv.alpha_composite(torso,(int(cx-56),int(base_y-92-th+16)))
    d=ImageDraw.Draw(cv)
    chest=(cx+lean*0.5,base_y-92-th+16+58)
    sh_l=(chest[0]-34*max(0.4,1-abs(lat)*0.6),chest[1]-6)
    sh_r=(chest[0]+34*max(0.4,1-abs(lat)*0.6),chest[1]-6)
    aim=state in ("aim","shoot")
    if aim:
        hand_r=(chest[0]+(92 if lat>=-0.2 else 44),chest[1]+6-(14 if dp>=0 else 26))
        hand_l=(hand_r[0]-30*abs(lat)-20,hand_r[1]+14)
    elif kick:
        hand_r=(chest[0]-46*lat,chest[1]+30); hand_l=(chest[0]+40*lat,chest[1]+34)
    else:
        sw=math.sin(t*9)*12 if state=="run" else math.sin(t*3)*3
        hand_r=(sh_r[0]+10+sw*0.4,sh_r[1]+62); hand_l=(sh_l[0]-8-sw*0.4,sh_l[1]+62)
    paste_limb(cv,sh_l,hand_l,17,PAL["hoodie"])
    if dp<=0.35:
        pk=Image.new("RGBA",(96,110),(0,0,0,0)); pd=ImageDraw.Draw(pk)
        pd.rounded_rectangle([4,4,92,104],radius=18,fill=PAL["pack"],outline=PAL["outline"],width=5)
        pd.line([12,30,84,30],fill=PAL["tube_r"],width=6); pd.line([12,44,84,44],fill=PAL["tube_g"],width=6)
        pd.rounded_rectangle([30,60,66,80],radius=6,fill=PAL["visor"],outline=PAL["outline"],width=3)
        pd.line([78,10,88,-2],fill=PAL["outline"],width=4); pd.ellipse([86,-6,94,2],fill=PAL["eye"])
        ox = int(chest[0]-48-lat*24) if dp<-0.3 else int(chest[0]-58-24*(1 if lat>=0 else -1))
        cv.alpha_composite(pk,(ox,int(chest[1]-52)))
    paste_limb(cv,sh_r,hand_r,17,PAL["hoodie"])
    dd=ImageDraw.Draw(cv)
    ell(dd,hand_r,11,fill=PAL["skin"]); ell(dd,hand_l,11,fill=PAL["skin"])
    hc=(cx+lean*0.9+(6*lat if aim else 0),chest[1]-84)
    head_r=30
    ell(dd,hc,head_r,head_r+2,fill=PAL["skin"])
    top=Image.new("RGBA",(120,60),(0,0,0,0)); tp=ImageDraw.Draw(top)
    tp.rounded_rectangle([10,20,110,58],radius=22,fill=PAL["hair"],outline=PAL["outline"],width=5)
    tp.arc([16,22,60,56],90,200,fill=PAL["hair_s"],width=4); tp.arc([60,22,104,56],340,90,fill=PAL["hair_s"],width=4)
    cv.alpha_composite(top,(int(hc[0]-60),int(hc[1]-head_r-30))); dd=ImageDraw.Draw(cv)
    if dp>-0.6:
        gl=Image.new("RGBA",(84,34),(0,0,0,0)); gd=ImageDraw.Draw(gl)
        gd.rounded_rectangle([2,4,38,30],radius=10,fill=hx(PAL["lens"])[:3]+(200,),outline=PAL["outline"],width=4)
        gd.rounded_rectangle([44,4,80,30],radius=10,fill=hx(PAL["lens"])[:3]+(200,),outline=PAL["outline"],width=4)
        gd.line([38,14,44,14],fill=PAL["frame"],width=4)
        cv.alpha_composite(gl,(int(hc[0]-42+lat*8),int(hc[1]-12))); dd=ImageDraw.Draw(cv)
    if dp>0.2:
        dd.line([hc[0]-8+lat*6,hc[1]+18,hc[0]+8+lat*6,hc[1]+18],fill=PAL["skin_d"],width=3)
    dd.arc([hc[0]-20,hc[1]+24,hc[0]+20,hc[1]+52],20,160,fill=PAL["gold"],width=6)
    dd.ellipse([hc[0]-3,hc[1]+46,hc[0]+5,hc[1]+54],fill=PAL["gold"],outline=PAL["outline"],width=2)
    if aim or state=="shoot":
        draw_gun(cv,sh_r,hand_r,flash=(state=="shoot"),kind=weapon)
    else:
        draw_gun(cv,sh_r,(hand_r[0]+4,hand_r[1]+16),kind=weapon)
    return cv

def alien_head(d,c,r,mood="normal",brain_cover=False):
    ell(d,c,r,r*1.05,fill=PAL["ali"])
    d.arc([c[0]-r,c[1]-r*0.2,c[0]+r,c[1]+r],200,340,fill=PAL["ali_d"],width=3)
    if not brain_cover:
        ell(d,(c[0],c[1]-r*0.75),r*0.62,r*0.5,fill=PAL["brain"])
        for k in (-1,0,1):
            d.arc([c[0]-r*0.5+k*6,c[1]-r*1.25,c[0]+r*0.5+k*6,c[1]-r*0.5],0,180,fill="#C2185B",width=2)
    else:
        d.arc([c[0]-r*0.8,c[1]-r*1.35,c[0]+r*0.8,c[1]-r*0.2],180,360,fill=PAL["bone"],width=9)
    rr=r*0.20 if mood!="shoot" else r*0.26
    for e in (-0.5,0.5):
        ox=c[0]+e*r*0.9; oy=c[1]-r*0.05
        ell(d,(ox,oy),rr,rr,fill=PAL["eye"]); d.rectangle([ox-1.5,oy-rr*0.7,ox+1.5,oy+rr*0.7],fill=PAL["ink"])
    ox=c[0]; oy=c[1]-r*0.35
    ell(d,(ox,oy),rr*0.9,rr*0.9,fill=PAL["eye"]); d.rectangle([ox-1.5,oy-rr*0.6,ox+1.5,oy+rr*0.6],fill=PAL["ink"])
    mw=r*1.15
    d.polygon([(c[0]-mw/2,c[1]+r*0.55),(c[0]+mw/2,c[1]+r*0.55),(c[0],c[1]+r*0.85)],
              fill=(74,14,23),outline=PAL["outline"],width=3)
    for k in range(5):
        tx=c[0]-mw/2+(k+0.5)*mw/5
        d.polygon([(tx-3,c[1]+r*0.56),(tx+3,c[1]+r*0.56),(tx,c[1]+r*0.70)],fill="#FFFFFF")
    if mood=="hit":
        ell(d,(c[0]+r*0.8,c[1]+r*0.2),5,fill=PAL["goo"])

def claw(d,c,o=0.2):
    for k in range(3):
        a=(-0.5+k*0.5)+o*(-0.4+k*0.4)
        d.line([c,(c[0]+math.cos(a-1.2)*16,c[1]+math.sin(a-1.2)*16)],fill=PAL["ink"],width=4)

def alien_sprite(kind="common",direction="front",state="walkA",t=0.3):
    facing={"front":1,"right":2,"back":3,"left":4}[direction]
    W,H=(256,320) if kind!="tank" else (320,360)
    cv=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(cv)
    cx=W/2; ground=H-16
    swing=14 if state=="walkA" else -14
    if state=="death":
        d.ellipse([cx-70,ground-26,cx+70,ground+8],fill=PAL["ali"],outline=PAL["outline"],width=5)
        d.ellipse([cx-70,ground-26,cx-30,ground-2],fill=PAL["brain"],outline=PAL["outline"],width=4)
        d.line([cx-20,ground-10,cx+40,ground-4],fill=PAL["ali_d"],width=5)
        for s in (-1,1): d.line([cx+s*50,ground,cx+s*84,ground-6],fill=PAL["ink"],width=4)
        ell(d,(cx+58,ground-14),6,fill=PAL["goo"]); return cv
    if kind=="common":
        hip=(cx,ground-92)
        for sgn in (-1,1):
            knee=(hip[0]+sgn*16+swing*0.3*sgn,ground-46); foot=(knee[0]+sgn*6,ground-2)
            paste_limb(cv,hip,knee,16,PAL["ali"]); paste_limb(cv,knee,foot,12,PAL["ali"])
        body=Image.new("RGBA",(86,112),(0,0,0,0)); bd=ImageDraw.Draw(body)
        bd.rounded_rectangle([8,6,78,106],radius=26,fill=PAL["ali"],outline=PAL["outline"],width=5)
        bd.arc([20,30,66,70],0,180,fill=PAL["ali_d"],width=4)
        cv.alpha_composite(body,(int(cx-43),int(ground-188))); d=ImageDraw.Draw(cv)
        lean=10 if facing!=3 else -4
        sh=(cx+lean,ground-174)
        for arm_s in (1,-1):
            hd=(sh[0]+arm_s*(34 if facing in(1,2) else 26)+swing*0.3*arm_s,sh[1]+52)
            paste_limb(cv,(sh[0]+arm_s*20,sh[1]-4),hd,11,PAL["ali"])
            cd=ImageDraw.Draw(cv); claw(cd,hd,0.6 if state=="hit" else 0.2)
        alien_head(d,(sh[0]+lean*0.6,sh[1]-40),30,mood="hit" if state=="hit" else "normal")
    elif kind=="runner":
        paste_limb(cv,(cx-46,ground-64),(cx+52,ground-58),30,PAL["ali"])
        for sgn in (-1,1):
            hip=(cx+sgn*40-10,ground-60); foot=(hip[0]+swing*0.5*sgn,ground-2)
            knee=((hip[0]+foot[0])/2+14,ground-34)
            paste_limb(cv,hip,knee,11,PAL["ali_d"]); paste_limb(cv,knee,foot,9,PAL["ali"])
        for k in range(3):
            pts=[(cx-58-s*9,ground-64+math.sin(s*0.9+k*2)*10-k*4) for s in range(8)]
            d.line(pts,fill=PAL["ali_d"],width=5)
        alien_head(d,(cx+64,ground-84),24)
    elif kind=="shooter":
        hip=(cx,ground-96)
        for sgn in (-1,1):
            knee=(hip[0]+sgn*16,ground-48); foot=(knee[0]+sgn*6,ground-2)
            paste_limb(cv,hip,knee,15,PAL["ali"]); paste_limb(cv,knee,foot,11,PAL["ali"])
        body=Image.new("RGBA",(84,112),(0,0,0,0)); bd=ImageDraw.Draw(body)
        bd.rounded_rectangle([8,8,76,104],radius=24,fill=PAL["ali"],outline=PAL["outline"],width=5)
        cv.alpha_composite(body,(int(cx-42),int(ground-190))); d=ImageDraw.Draw(cv)
        alien_head(d,(cx,ground-224),30,mood="shoot" if state=="hit" else "normal")
        gun_c=(cx+52,ground-168)
        for k in range(5):
            r=16-k*2.4
            ell(d,(gun_c[0]-k*7,gun_c[1]+math.sin(k)*3),r,r*0.8,fill=PAL["ali"] if k%2 else PAL["ali_d"])
        ell(d,(gun_c[0]+12,gun_c[1]),12,10,fill=PAL["goo"])
        if state=="hit": ell(d,(gun_c[0]+40,gun_c[1]-4),10,fill=PAL["goo"])
        paste_limb(cv,(cx-24,ground-176),(cx-40,ground-140),10,PAL["ali"])
    elif kind=="tank":
        hip=(cx,ground-110)
        for sgn in (-1,1):
            knee=(hip[0]+sgn*30+swing*0.2*sgn,ground-56); foot=(knee[0]+sgn*10,ground-2)
            paste_limb(cv,hip,knee,26,PAL["tank"]); paste_limb(cv,knee,foot,20,PAL["tank"])
        body=Image.new("RGBA",(190,150),(0,0,0,0)); bd=ImageDraw.Draw(body)
        bd.ellipse([6,10,184,140],fill=PAL["tank"],outline=PAL["outline"],width=6)
        bd.arc([40,50,150,110],0,180,fill=PAL["ali_d"],width=6)
        cv.alpha_composite(body,(int(cx-95),int(ground-196))); d=ImageDraw.Draw(cv)
        alien_head(d,(cx,ground-236),36,brain_cover=True)
        for sgn in (-1,1):
            hd=(cx+sgn*92,ground-120)
            paste_limb(cv,(cx+sgn*70,ground-170),hd,18,PAL["tank"])
            cd=ImageDraw.Draw(cv); claw(cd,hd)
    if state=="hit":
        for k in range(6):
            ang=k*1.05; r0=40
            d.line([(cx+math.cos(ang)*r0,H*0.45+math.sin(ang)*r0),
                    (cx+math.cos(ang)*(r0+18),H*0.45+math.sin(ang)*(r0+18))],fill=PAL["goo"],width=5)
    if facing==4:
        cv=cv.transpose(Image.FLIP_LEFT_RIGHT)
    return cv

def boss_sprite(state="idle",t=0.0):
    W,H=512,560
    cv=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(cv)
    cx=W/2; ground=H-20
    pulse=1+0.04*math.sin(t*3)
    if state=="death":
        d.ellipse([cx-180,ground-90,cx+180,ground+16],fill=PAL["ali_d"],outline=PAL["outline"],width=7)
        d.ellipse([cx-120,ground-120,cx+40,ground-40],fill=PAL["brain"],outline=PAL["outline"],width=6)
        for k in range(8):
            a=math.pi*k/8
            d.line([(cx,ground-40),(cx+math.cos(a)*200,ground-40+math.sin(a)*40)],fill=PAL["ink"],width=6)
        for k in range(10):
            ell(d,(cx-160+k*36,ground-60+(k%3)*14),8,fill=PAL["eye"] if k%2 else "#B8B800")
        return cv
    massa=[(cx+math.cos(a)*(150+20*math.sin(a*3+t*2)),ground-140+math.sin(a)*(95*pulse))
           for a in [i*math.pi/24 for i in range(48)]]
    poly(d,massa,fill=PAL["ali"],ol=7)
    for k in range(7):
        bx=cx-150+k*50
        pts=[(bx+math.sin(s*0.8+k)*24,ground-96+s*11) for s in range(8)]
        d.line(pts,fill=PAL["ali_d"],width=18); d.line(pts,fill=PAL["ali"],width=10)
    for k in range(9):
        a=math.pi*(0.15+0.7*k/8)
        ox=cx-math.cos(a)*120; oy=ground-250+math.sin(a)*40
        ell(d,(ox,oy),13,fill=PAL["eye"]); d.rectangle([ox-2,oy-9,ox+2,oy+9],fill=PAL["ink"])
    ell(d,(cx,ground-300*pulse),86,64*pulse,fill=PAL["brain"])
    for k in range(6):
        d.arc([cx-70+k*8,ground-352,cx+70+k*8,ground-250],0,180,fill="#C2185B",width=4)
    d.polygon([(cx-90,ground-210),(cx+90,ground-210),(cx,ground-150)],
              fill=(74,14,23),outline=PAL["outline"],width=6)
    for k in range(9):
        tx=cx-84+k*21
        d.polygon([(tx-6,ground-208),(tx+6,ground-208),(tx,ground-186)],fill="#FFFFFF")
    ell(d,(cx+120,ground-160),10,fill=PAL["goo"])
    return cv

def item_sprite(kind):
    W,H=96,96; cv=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(cv); c=(W/2,H/2)
    if kind=="coin":
        poly(d,[(c[0]+math.cos(i*math.pi/3)*30,c[1]+math.sin(i*math.pi/3)*30) for i in range(6)],fill="#8E24AA",ol=5)
        poly(d,[(c[0]+math.cos(i*math.pi/3)*20,c[1]+math.sin(i*math.pi/3)*20) for i in range(6)],fill="#E1BEE7",ol=3)
        d.text((c[0]-7,c[1]-11),"B$",fill=(74,20,140))
    elif kind=="ammo":
        d.rounded_rectangle([18,30,78,70],radius=8,fill=PAL["metal"],outline=PAL["outline"],width=4)
        for k in range(4): d.rectangle([24+k*13,18,32+k*13,40],fill=PAL["gold"],outline=PAL["outline"],width=2)
    elif kind=="medkit":
        d.rounded_rectangle([16,26,80,74],radius=10,fill=(242,242,242),outline=PAL["outline"],width=4)
        d.rectangle([42,34,54,66],fill=(211,47,47)); d.rectangle([30,45,66,55],fill=(211,47,47))
    elif kind=="energy":
        d.rounded_rectangle([32,18,64,78],radius=10,fill=(46,125,50),outline=PAL["outline"],width=4)
        d.polygon([(52,26),(40,50),(50,50),(42,72),(60,44),(48,44)],fill=PAL["eye"])
    elif kind=="vest":
        poly(d,[(28,20),(68,20),(74,74),(22,74)],fill=(27,94,32),ol=4)
        d.line([30,30,66,30],fill=PAL["goo"],width=5)
    elif kind=="mine":
        d.ellipse([24,44,72,72],fill=(55,71,79),outline=PAL["outline"],width=4)
        d.rectangle([40,30,56,48],fill=(183,28,28),outline=PAL["outline"],width=3)
        d.ellipse([44,20,52,28],fill=(255,82,82))
    elif kind=="tower":
        d.rounded_rectangle([36,30,60,80],radius=6,fill=PAL["metal"],outline=PAL["outline"],width=4)
        d.rectangle([30,16,66,34],fill=PAL["ink"],outline=PAL["outline"],width=3)
        d.ellipse([44,20,54,30],fill=PAL["eye"])
    return cv

def portrait():
    W,H=160,160; cv=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(cv)
    d.rounded_rectangle([4,4,W-4,H-4],radius=18,fill=(43,47,54),outline=PAL["outline"],width=5)
    c=(W/2,H/2+18)
    ell(d,c,52,54,fill=PAL["skin"])
    top=Image.new("RGBA",(120,50),(0,0,0,0)); tp=ImageDraw.Draw(top)
    tp.rounded_rectangle([8,14,112,48],radius=20,fill=PAL["hair"],outline=PAL["outline"],width=5)
    cv.alpha_composite(top,(int(c[0]-60),int(c[1]-84))); d=ImageDraw.Draw(cv)
    gl=Image.new("RGBA",(104,36),(0,0,0,0)); gd=ImageDraw.Draw(gl)
    gd.rounded_rectangle([2,4,46,32],radius=12,fill=hx(PAL["lens"])[:3]+(220,),outline=PAL["outline"],width=4)
    gd.rounded_rectangle([56,4,100,32],radius=12,fill=hx(PAL["lens"])[:3]+(220,),outline=PAL["outline"],width=4)
    gd.line([46,16,58,16],fill=PAL["frame"],width=4)
    cv.alpha_composite(gl,(int(c[0]-52),int(c[1]-26))); d=ImageDraw.Draw(cv)
    d.arc([c[0]-30,c[1]+26,c[0]+30,c[1]+70],20,160,fill=PAL["gold"],width=7)
    d.line([c[0]-12,c[1]+34,c[0]+12,c[1]+34],fill=PAL["skin_d"],width=4)
    return cv

def weapon_icon(kind):
    W,H=180,90; cv=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(cv)
    if kind=="pistol":
        poly(d,[(30,30),(120,26),(120,44),(66,44),(60,66),(34,66)],fill=PAL["ink"],ol=4)
        d.rectangle([118,28,138,40],fill=(51,51,51),outline=PAL["outline"],width=3)
    elif kind=="rifle":
        poly(d,[(14,38),(150,32),(150,52),(40,56),(30,70),(16,64)],fill=PAL["metal"],ol=4)
        d.rectangle([60,52,84,74],fill=PAL["ink"],outline=PAL["outline"],width=3)
        d.rectangle([120,30,150,44],fill=PAL["wood"],outline=PAL["outline"],width=3)
        d.line([40,30,70,28],fill=PAL["tube_g"],width=5)
    else:
        poly(d,[(16,40),(140,34),(140,50),(30,58)],fill=(78,52,46),ol=4)
        d.rectangle([130,32,166,52],fill=PAL["metal"],outline=PAL["outline"],width=4)
        d.rectangle([40,52,80,66],fill=PAL["wood"],outline=PAL["outline"],width=3)
    return cv

def save(img,rel):
    p=os.path.normpath(os.path.join(BASE,rel)); os.makedirs(os.path.dirname(p),exist_ok=True)
    img.save(p); return p

def main():
    n=0
    states={"idle":[0.0],"run":[0.0,0.055,0.11,0.165],"aim":[0.0],"shoot":[0.0],"melee":[0.0]}
    for st,ts in states.items():
        for i,t in enumerate(ts):
            for dr in DIRS8:
                fn=f"{st}_{dr}_{i}.png" if len(ts)>1 else f"{st}_{dr}.png"
                save(player_sprite(state=st,direction=dr,t=t),f"characters/player/{fn}"); n+=1
    for kind in ("common","runner","shooter","tank"):
        for dr in ("front","right","back","left"):
            for st in ("walkA","walkB","hit","death"):
                save(alien_sprite(kind,dr,st),f"enemies/{kind}/{st}_{dr}.png"); n+=1
    for i in range(2):
        save(boss_sprite("idle",t=i*1.0),f"enemies/boss/idle{i}.png"); n+=1
    save(boss_sprite("death"),"enemies/boss/death.png"); n+=1
    for it in ("coin","ammo","medkit","energy","vest","mine","tower"):
        save(item_sprite(it),f"effects/items/{it}.png"); n+=1
    save(portrait(),"interface/portrait.png"); n+=1
    for w in ("pistol","rifle","shotgun"):
        save(weapon_icon(w),f"weapons/{w}_icon.png"); n+=1
    print(f"gerados {n} arquivos -> {os.path.abspath(BASE)}")

if __name__=="__main__":
    main()
