import math, colorsys
def atari_rgb(code):
    h=(code>>4)&15; l=(code>>1)&7
    y=0.06+ l/7*0.88
    if h==0:
        v=y; return tuple(int(max(0,min(1,v))*255) for _ in range(3))
    # hue wheel: 1 gold .. 15 light orange (NTSC-ish)
    ang=math.radians(-36 + (h-1)*(360/15.6)) 
    sat=0.33
    i=sat*math.cos(ang); q=sat*math.sin(ang)
    # rotate so hue1 ~ yellow/gold
    r=y+0.956*i+0.621*q; g=y-0.272*i-0.647*q; b=y-1.106*i+1.703*q
    return tuple(int(max(0,min(1,c))*255) for c in (r,g,b))
