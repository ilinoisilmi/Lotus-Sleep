#!/usr/bin/env python3
"""Original vector companion artwork; regenerate with Python 3 + CairoSVG.
Five quiet stages for each of four animals. No downloaded art or runtime dependency.
"""
from pathlib import Path
import json
import cairosvg

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'App/Resources/Assets.xcassets/CompanionSheet.imageset'
DESIGN=ROOT/'Design'
DEST.mkdir(parents=True,exist_ok=True)
DESIGN.mkdir(exist_ok=True)

def animal(kind,stage):
    fur,light,ink={
        'bunny':('#CAB9A1','#E9DFCF','#51483E'),
        'fox':('#B8764E','#ECDCC6','#583B2C'),
        'otter':('#8C7662','#D9C9AF','#453C34'),
        'kitten':('#8A9790','#D4DBD0','#394E48'),
    }[kind]
    p=[]
    def path(d,fill,stroke='none',w=2): p.append(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')
    def ellipse(x,y,rx,ry,fill,stroke='none',w=2): p.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{w}"/>')
    ellipse(128,218,72,8,'#819389',w=0)
    # A linen cushion appears with the fourth stage; earned details remain available.
    if stage>=3:
        path('M47 205 Q52 192 78 194 L180 194 Q207 194 209 211 Q180 231 71 226 Q50 224 47 205Z','#D4CBB8')
        path('M62 215 Q128 229 194 215','none','#B6AA92',1.4)
    # Natural tails, silhouette and feet.
    if kind=='fox':
        path('M164 202 C225 206 224 154 206 139 C219 181 182 163 169 177Z',fur,ink,1.4)
        path('M207 141 Q226 168 209 185 Q211 170 197 165Z',light)
    elif kind=='otter':
        path('M166 197 Q204 205 220 184 Q213 219 166 215Z',fur,ink,1.4)
    elif kind=='kitten':
        path('M168 202 C207 221 220 180 204 172 C193 167 191 181 201 182','none',fur,17)
    else:
        ellipse(176,192,15,14,light,ink,1.2)
    path('M88 146 Q64 168 77 204 Q94 220 151 216 Q181 211 180 190 Q176 157 155 145Z',fur,ink,1.5)
    ellipse(125,185,32,30,light)
    ellipse(97,212,23,8,fur,ink,1.2);ellipse(155,212,23,8,fur,ink,1.2)
    # Ear geometry is specific to each animal.
    if kind=='bunny':
        path('M96 111 C61 34 72 19 86 31 Q102 47 112 107Z',fur,ink,1.5)
        path('M132 106 Q128 30 144 29 C165 30 163 71 148 117Z',fur,ink,1.5)
        path('M94 93 Q73 43 81 40 Q91 43 104 99Z','#B29484')
        path('M141 95 Q139 43 146 42 Q153 52 146 98Z','#B29484')
    elif kind in ('fox','kitten'):
        path('M79 113 L77 63 Q100 69 114 97Z',fur,ink,1.5)
        path('M140 97 Q157 69 179 63 L175 121Z',fur,ink,1.5)
        path('M85 99 L85 78 L105 100Z',light)
        path('M151 101 L170 79 L169 108Z',light)
    else:
        ellipse(83,109,16,17,fur,ink,1.5);ellipse(173,109,16,17,fur,ink,1.5)
        ellipse(84,108,8,9,light);ellipse(172,108,8,9,light)
    path('M77 124 Q76 91 126 91 Q173 90 180 127 Q182 159 151 168 Q126 179 101 165 Q75 157 77 124Z',fur,ink,1.5)
    if kind=='fox':
        path('M78 126 Q103 125 128 147 Q154 126 179 126 Q173 160 130 173 Q86 163 78 126Z',light)
    else:
        ellipse(128,151,27 if kind!='otter' else 34,19,light)
    # A subtle shift from alert to resting, with no floating decorations.
    if stage==0:
        ellipse(103,128,3,4,ink);ellipse(153,128,3,4,ink)
    else:
        path('M96 128 Q103 135 110 128 M146 128 Q153 135 160 128','none',ink,2.1)
    path('M123 144 Q128 140 133 144 Q130 150 128 150 Q125 149 123 144Z',ink)
    path('M128 151 L128 156 M120 157 Q128 163 136 157','none',ink,1.4)
    if kind in ('otter','kitten'):
        path('M99 150 L77 146 M99 157 L77 159 M157 150 L179 146 M157 157 L179 159','none',ink,1.1)
    if kind=='kitten':
        path('M114 96 L119 108 M128 94 L128 107 M142 96 L137 108','none',ink,2.5)
    # A folded scarf is the third-stage detail, kept in muted natural colours.
    if stage>=2:
        path('M96 166 Q127 177 158 166 L159 178 Q131 188 95 178Z','#617C72')
        path('M146 176 L159 178 L164 197 L149 195Z','#617C72')
        path('M101 173 Q124 181 143 175','none','#A4B8AC',1.4)
    # Small curled paws feel more relaxed at later stages.
    if stage>=1:
        path('M102 182 Q108 197 124 189 M153 182 Q147 197 132 189','none',ink,1.5)
    if stage>=4:
        path('M58 220 Q48 201 65 197 Q79 199 77 219 Q71 227 58 220Z','#617C72')
        path('M63 217 Q56 201 67 193 Q79 201 73 218Z','#C3C6B1')
        path('M65 220 Q76 200 85 208 Q85 223 65 220Z','#9FAF9D')
    return ''.join(p)

parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="1024" viewBox="0 0 1280 1024">']
for row,kind in enumerate(['bunny','fox','otter','kitten']):
    for stage in range(5): parts.append(f'<g transform="translate({stage*256} {row*256})">'+animal(kind,stage)+'</g>')
parts.append('</svg>')
svg=''.join(parts)
(DESIGN/'Companions.svg').write_text(svg)
cairosvg.svg2pdf(bytestring=svg.encode(),write_to=str(DEST/'CompanionSheet.pdf'))
(DEST/'Contents.json').write_text(json.dumps({'images':[{'filename':'CompanionSheet.pdf','idiom':'universal'}],'info':{'author':'xcode','version':1},'properties':{'preserves-vector-representation':True}},indent=2)+'\n')
cairosvg.svg2png(bytestring=svg.encode(),write_to='/tmp/lotus-companions.png',background_color='#F7F5EF')
print('Generated four original companions, five stages each; PDF vector asset and editable SVG.')
