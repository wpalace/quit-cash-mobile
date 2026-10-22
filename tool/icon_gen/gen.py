from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math
S=2048
def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(len(a)))
def radial(size,c0,c1,cx,cy,r):
    im=Image.new('RGBA',(size,size))
    g=Image.radial_gradient('L').resize((int(r*2),int(r*2)))
    a=Image.new('RGBA',(size,size),c1+(255,)); b=Image.new('RGBA',(size,size),c0+(255,))
    m=Image.new('L',(size,size),255); m.paste(g,(int(cx-r),int(cy-r)))
    return Image.composite(a,b,m)
def lin(size,c0,c1):
    g=Image.linear_gradient('L').resize((size,size))
    return Image.composite(Image.new('RGBA',(size,size),c1+(255,)),Image.new('RGBA',(size,size),c0+(255,)),g)
def circmask(size,cx,cy,r):
    m=Image.new('L',(size,size),0); ImageDraw.Draw(m).ellipse((cx-r,cy-r,cx+r,cy+r),fill=255); return m
def polymask(size,pts):
    m=Image.new('L',(size,size),0); ImageDraw.Draw(m).polygon(pts,fill=255); return m
def put(base,layer,mask): base.alpha_composite(Image.composite(layer,Image.new('RGBA',base.size,(0,0,0,0)),mask))
def sparkle(d,cx,cy,r,col=(255,255,255,255)):
    w=r*0.22
    d.polygon([(cx,cy-r),(cx+w,cy-w),(cx+r,cy),(cx+w,cy+w),(cx,cy+r),(cx-w,cy+w),(cx-r,cy),(cx-w,cy-w)],fill=col)
def coin(im,cx,cy,r,face=((255,236,120),(214,140,10)),rim=(150,90,0),gloss=True):
    s=im.size[0]
    sh=Image.new('RGBA',im.size,(0,0,0,0)); ImageDraw.Draw(sh).ellipse((cx-r,cy-r+r*0.08,cx+r,cy+r+r*0.08),fill=(0,0,0,90))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(r*0.05)))
    put(im,Image.new('RGBA',im.size,rim+(255,)),circmask(s,cx,cy,r))
    put(im,radial(s,face[0],face[1],cx-r*0.3,cy-r*0.35,r*1.5),circmask(s,cx,cy,r*0.9))
    put(im,radial(s,face[1],face[0],cx+r*0.2,cy+r*0.25,r*1.2),circmask(s,cx,cy,r*0.74))
    if gloss:
        g=Image.new('RGBA',im.size,(0,0,0,0)); ImageDraw.Draw(g).ellipse((cx-r*0.62,cy-r*0.82,cx+r*0.1,cy-r*0.42),fill=(255,255,255,120))
        im.alpha_composite(g.rotate(25,center=(cx,cy)).filter(ImageFilter.GaussianBlur(r*0.04)))
def gem(im,cx,cy,w,base=(30,110,240),dark=(10,40,140),light=(140,210,255)):
    s=im.size[0]; h=w*0.95
    top=cy-h*0.42; mid=cy-h*0.12; bot=cy+h*0.58
    L,R=cx-w/2,cx+w/2; tl,tr=cx-w*0.28,cx+w*0.28
    d=ImageDraw.Draw(im)
    sh=Image.new('RGBA',im.size,(0,0,0,0)); ImageDraw.Draw(sh).polygon([(L,mid+w*.04),(R,mid+w*.04),(cx,bot+w*.06)],fill=(0,0,0,110)); im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(w*0.04)))
    f=[ [(tl,top),(tr,top),(cx+w*0.12,mid),(cx-w*0.12,mid)],
        [(L,mid),(tl,top),(cx-w*0.12,mid)],[(R,mid),(tr,top),(cx+w*0.12,mid)],
        [(L,mid),(cx-w*0.12,mid),(cx,bot)],[(cx-w*0.12,mid),(cx+w*0.12,mid),(cx,bot)],[(cx+w*0.12,mid),(R,mid),(cx,bot)]]
    cols=[light,lerp(light,base,.5),base,lerp(base,light,.25),base,dark]
    for p,c in zip(f,cols): d.polygon(p,fill=c+(255,))
    ol=max(2,int(w*0.018)); d.line([(L,mid),(tl,top),(tr,top),(R,mid),(cx,bot),(L,mid),(R,mid)],fill=lerp(dark,(0,0,0),.3)+(255,),width=ol,joint='curve')
    d.polygon([(tl+w*.04,top+h*.04),(cx-w*.02,top+h*.04),(cx-w*.12,mid-h*.03)],fill=(255,255,255,170))
def sz(): return Image.new('RGBA',(S,S),(0,0,0,0))
# --- concept art: foreground layers drawn in a 2048 canvas, content inside central ~62%
def art_gemcoin(mono=False):
    im=sz(); c=S/2; r=S*0.30
    coin(im,c,c+S*0.01,r)
    gem(im,c,c+S*0.005,r*1.0)
    d=ImageDraw.Draw(im); sparkle(d,c+r*0.78,c-r*0.72,r*0.26); sparkle(d,c-r*0.85,c+r*0.55,r*0.12)
    return im
def art_stack():
    im=sz(); c=S/2; r=S*0.2
    for i,(f,rm) in enumerate([(((240,170,120),(160,80,40)),(110,50,20)),(((245,245,250),(150,155,170)),(90,95,110)),(((255,236,120),(214,140,10)),(150,90,0))]):
        coin(im,c+(i-1)*S*0.05,c+S*0.2-i*S*0.13,r,face=f,rim=rm,gloss=(i==2))
    gem(im,c+S*0.05,c-S*0.2,r*0.9,base=(220,30,60),dark=(120,0,25),light=(255,150,170))
    sparkle(ImageDraw.Draw(im),c+S*0.23,c-S*0.27,S*0.05); return im
def art_break():
    im=sz(); c=S/2; r=S*0.27
    coin(im,c,c,r,face=((140,240,160),(20,140,70)),rim=(10,80,40))
    d=ImageDraw.Draw(im)
    # embossed upward arrow
    a=[(c,c-r*0.55),(c+r*0.42,c-r*0.05),(c+r*0.16,c-r*0.05),(c+r*0.16,c+r*0.5),(c-r*0.16,c+r*0.5),(c-r*0.16,c-r*0.05),(c-r*0.42,c-r*0.05)]
    sh=Image.new('RGBA',im.size,(0,0,0,0)); ImageDraw.Draw(sh).polygon([(x+r*.04,y+r*.06) for x,y in a],fill=(0,50,20,200)); im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(r*0.03)))
    put(im,lin(S,(255,255,240),(190,240,200)),polymask(S,a))
    hl=[(c,c-r*0.55),(c-r*0.42,c-r*0.05),(c-r*0.16,c-r*0.05),(c-r*0.16,c+r*0.5),(c-r*0.06,c+r*0.5),(c-r*0.06,c-r*0.15),(c,c-r*0.42)]
    d.polygon(hl,fill=(255,255,255,255))
    d.line(a+[a[0]],fill=(10,90,45,255),width=max(2,int(r*0.025)),joint='curve')
    for k in range(5):
        ang=-math.pi/2+(k-2)*0.5; sparkle(d,c+math.cos(ang)*r*1.25,c+math.sin(ang)*r*1.25,S*0.035)
    return im
def bg_layer(kind='blue'):
    cols={'blue':((60,50,170),(20,10,60)),'teal':((20,120,140),(5,30,50)),'plum':((150,40,120),(40,10,50))}[kind]
    b=radial(S,cols[0],cols[1],S*0.38,S*0.3,S*1.0)
    d=ImageDraw.Draw(b)
    for x,y,rr in [(0.18,0.2,0.02),(0.82,0.78,0.015),(0.15,0.8,0.012),(0.86,0.16,0.012)]: sparkle(d,S*x,S*y,S*rr,(255,255,255,110))
    return b
def full(art,bg,shape='sq',scale=1.0):
    a=art if scale==1 else Image.new('RGBA',(S,S),(0,0,0,0))
    if scale!=1:
        t=art.resize((int(S*scale),)*2,Image.LANCZOS); a.alpha_composite(t,((S-t.size[0])//2,)*2)
    im=bg.copy(); im.alpha_composite(a)
    if shape=='circle':
        o=Image.new('RGBA',(S,S),(0,0,0,0)); o.paste(im,(0,0),circmask(S,S/2,S/2,S/2)); im=o
    return im
