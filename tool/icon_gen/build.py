from gen import *
import json,os
R='/workspace/quitcash/quit-cash-mobile/'
art=art_break(); bg=bg_layer('plum')
sq=full(art,bg,scale=1.35)  # full-bleed square
def rr(im,n,rad=0.18):
    t=im.resize((n,n),Image.LANCZOS); m=Image.new('L',(n*4,n*4),0)
    ImageDraw.Draw(m).rounded_rectangle((0,0,n*4-1,n*4-1),int(n*4*rad),fill=255); m=m.resize((n,n),Image.LANCZOS)
    o=Image.new('RGBA',(n,n),(0,0,0,0)); o.paste(t,(0,0),m); return o
def circ(im,n):
    t=im.resize((n,n),Image.LANCZOS); m=circmask(n*4,n*2,n*2,n*2).resize((n,n),Image.LANCZOS)
    o=Image.new('RGBA',(n,n),(0,0,0,0)); o.paste(t,(0,0),m); return o
res=R+'android/app/src/main/res/'
for k,n in {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}.items():
    d=res+f'mipmap-{k}/'; os.makedirs(d,exist_ok=True)
    rr(sq,n,0.16).save(d+'ic_launcher.png'); circ(sq,n).save(d+'ic_launcher_round.png')
    a=n*108//48
    art.resize((a,a),Image.LANCZOS).save(d+'ic_launcher_foreground.png')
    bg.resize((a,a),Image.LANCZOS).convert('RGB').save(d+'ic_launcher_background.png')
    # monochrome: silhouette of coin + gem cutout
    c=S/2; r=S*0.27
    a2=[(c,c-r*0.55),(c+r*0.42,c-r*0.05),(c+r*0.16,c-r*0.05),(c+r*0.16,c+r*0.5),(c-r*0.16,c+r*0.5),(c-r*0.16,c-r*0.05),(c-r*0.42,c-r*0.05)]
    ring=ImageChops.subtract(circmask(S,c,c,r),circmask(S,c,c,r*0.84))
    mono=ImageChops.lighter(ring,polymask(S,a2))
    mi=Image.new('RGBA',(S,S),(255,255,255,0)); mi.putalpha(mono)
    mi.resize((a,a),Image.LANCZOS).save(d+'ic_launcher_monochrome.png')
os.makedirs(res+'mipmap-anydpi-v26',exist_ok=True)
x='''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
'''
for f in ['ic_launcher.xml','ic_launcher_round.xml']: open(res+'mipmap-anydpi-v26/'+f,'w').write(x)
os.makedirs(R+'assets/icon',exist_ok=True)
sq.resize((512,512),Image.LANCZOS).convert('RGB').save(R+'assets/icon/play_store_512.png')
sq.resize((1024,1024),Image.LANCZOS).convert('RGB').save(R+'assets/icon/icon_master_1024.png')
ios=R+'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
for f in os.listdir(ios):
    if f.endswith('.png'): os.remove(ios+f)
spec=[('iphone',20,[2,3]),('iphone',29,[1,2,3]),('iphone',40,[2,3]),('iphone',60,[2,3]),('ipad',20,[1,2]),('ipad',29,[1,2]),('ipad',40,[1,2]),('ipad',76,[1,2]),('ipad',83.5,[2]),('ios-marketing',1024,[1])]
imgs=[]
for idiom,p,scs in spec:
    for s in scs:
        ps=('%g'%p); fn=f'Icon-App-{ps}x{ps}@{s}x.png'; n=int(round(p*s))
        sq.resize((n,n),Image.LANCZOS).convert('RGB').save(ios+fn)
        imgs.append({'size':f'{ps}x{ps}','idiom':idiom,'filename':fn,'scale':f'{s}x'})
json.dump({'images':imgs,'info':{'version':1,'author':'xcode'}},open(ios+'Contents.json','w'),indent=2)
w=R+'web/'
rr(sq,192,0.18).save(w+'icons/Icon-192.png'); rr(sq,512,0.18).save(w+'icons/Icon-512.png')
for n in (192,512): full(art,bg,scale=1.0).resize((n,n),Image.LANCZOS).convert('RGB').save(w+f'icons/Icon-maskable-{n}.png')
circ(sq,32).save(w+'favicon.png')
# previews
P=Image.new('RGB',(1700,760),(255,255,255)); d=ImageDraw.Draw(P); d.rectangle((0,380,1700,760),fill=(18,18,22))
for row,y in [(0,40),(1,420)]:
    x=40
    for n in (256,180,120,76,48,29):
        P.paste(rr(sq,n,0.2),(x,y+(256-n)//2),rr(sq,n,0.2)); x+=n+30
    x+=20
    for shp in ('circle','squircle'):
        n=200; fl=full(art,bg).resize((n,n),Image.LANCZOS)
        m=Image.new('L',(n,n),0); dm=ImageDraw.Draw(m)
        dm.ellipse((0,0,n-1,n-1),fill=255) if shp=='circle' else dm.rounded_rectangle((0,0,n-1,n-1),70,fill=255)
        P.paste(fl,(x,y+28),m); x+=n+30
    mm=Image.open(res+'mipmap-xxxhdpi/ic_launcher_monochrome.png').resize((200,200))
    tint=Image.new('RGBA',(200,200),(60,70,90,255) if row==0 else (200,210,230,255)); m=circmask(200,100,100,100)
    cb=Image.new('RGBA',(200,200),(225,230,245,255) if row==0 else (40,45,60,255)); cb.paste(tint,(0,0),mm.getchannel('A'))
    P.paste(cb,(x,y+28),m)
P.save('/workspace/quitcash/shots/icon-final.png')
