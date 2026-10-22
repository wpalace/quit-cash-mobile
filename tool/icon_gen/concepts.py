from gen import *
from PIL import ImageFont
cs=[(art_stack(),bg_layer('teal'),'A  Stack-to-Gem'),(art_break(),bg_layer('plum'),'B  Level-Up Coin'),(art_gemcoin(),bg_layer('blue'),'C  Gem-Set Coin')]
W=560;out=Image.new('RGB',(W*3+80,W+140),(245,245,248));d=ImageDraw.Draw(out)
f=ImageFont.load_default(size=36)
for i,(a,b,n) in enumerate(cs):
    im=full(a,b,scale=1.35).resize((480,480),Image.LANCZOS)
    m=Image.new('L',(480,480),0);ImageDraw.Draw(m).rounded_rectangle((0,0,479,479),108,fill=255)
    out.paste(im,(40+i*(W+0)+20,40),m); d.text((60+i*W,560),n,fill=(30,30,40),font=f)
out.save('/workspace/quitcash/shots/icon-concepts.png')
