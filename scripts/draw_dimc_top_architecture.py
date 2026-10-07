"""Generate the top-level SVG in the same block/wire style as the datapath SVG.
Render PNG with: rsvg-convert <svg> -o <png>.
"""
from html import escape
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'docs/Hardware_Architecture_diagrams'
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="3900" height="2080" viewBox="0 0 3900 2080">',
'''<defs><marker id="end" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 Z" fill="#334155"/></marker><marker id="start" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M10 0 L0 5 L10 10 Z" fill="#334155"/></marker></defs><rect width="3900" height="2080" fill="white"/>''']

def text(x, y, value, size=21, anchor='start'):
    parts.append(f'<text x="{x}" y="{y}" font-family="DejaVu Sans, sans-serif" font-size="{size}" text-anchor="{anchor}" fill="#172033">{escape(value)}</text>')

def rect(x,y,w,h,fill='white',stroke='#64748b'):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')

def wire(points,color='#334155',both=False,arrow=True):
    coords=' '.join(f'{x},{y}' for x,y in points)
    markers=(' marker-end="url(#end)"' if arrow else '')+(' marker-start="url(#start)"' if both else '')
    parts.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="2"{markers}/>')

def dot(x,y,color):
    parts.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{color}"/>')

text(1950,50,'dimc_top — hardware block diagram',32,'middle')
rect(300,110,3350,1790)
text(325,148,'dimc_top',25)
rect(650,355,450,1390,'#f5f0ff','#8b5cf6')
text(875,390,'dimc_ctrl',26,'middle')
text(875,417,'i_ctrl',18,'middle')
text(675,800,'Shared job controller',22)
for n,label in enumerate(['HWPE register contexts / events','Shared computation settings','Two programmable address triplets','Validate both memory ranges','Broadcast configuration and starts','Remember each completion pulse']):
    text(675,840+n*34,label,18)
text(675,1510,'Complete after both modules:',20)
text(675,1545,'all tiles + final output writes',18)
text(675,1610,'Abort: drain both streamers',18)
text(675,1640,'before shared clear',18)
text(675,1700,'21 configuration IO registers',18)

for y,label in [(470,'clk_i'),(535,'rst_ni'),(650,'periph')]:
    wire([(65,y),(650,y)],both=label=='periph')
    text(90,y-13,label)
    if label=='periph':text(330,y-13,'HWPE slave interface',16)

# Outputs use the same long, orthogonal routes as the datapath reference.
for y,label in [(195,'busy_o'),(250,'evt_o')]:
    wire([(850 if label=='busy_o' else 950,355),(850 if label=='busy_o' else 950,y),(3800,y)],'#8b5cf6')
    text(3780,y-13,label,21,'end')
text(675,295,'evt_o: N_CORES × REGFILE_N_EVT',17)

controls=[('config_',430),('dp_start',490),('stream_start',550),('clear',610),('abort_job',670)]
for i,(label,y) in enumerate(controls):
    lane=1230+i*65
    wire([(1100,y),(1900 if i==0 else 1860,y)],'#8b5cf6')
    text(1120,y-12,label,18)
    wire([(lane,y),(lane,y+750),(1900 if i==0 else 1860,y+750)],'#8b5cf6')
    dot(lane,y,'#8b5cf6')

for module_id,offset in [(1,0),(2,750)]:
    def t(x,y,label,size=18,anchor='start'):text(x,y+offset,label,size,anchor)
    def w(points,color='#334155',both=False):wire([(x,y+offset) for x,y in points],color,both)
    rect(1750,355+offset,1600,630,'#f8fbff','#3b82f6')
    t(2550,390,f'dimc_module — module {module_id}',26,'middle')
    t(2550,417,f'i_module_{module_id}  ·  MODULE_ID={module_id}',18,'middle')
    for label,y in controls:
        if label!='config_':t(1765,y-12,label,17)
    rect(1900,405+offset,350,135,'#f5f0ff','#8b5cf6')
    t(2075,439,'Local configuration mapping',19,'middle')
    t(2075,471,'Shared computation settings',17,'middle')
    t(2075,503,'Select this module’s 3 addresses',17,'middle')
    t(1765,454,'config_i',17)
    # Two real child instances, with independent state and data handshakes.
    rect(2000,570+offset,450,320,'#dbeafe','#3b82f6')
    rect(2780,570+offset,440,320,'#f0fdf4','#22c55e')
    t(2225,605,'dimc_datapath',24,'middle')
    t(2225,632,'i_datapath',17,'middle')
    t(3000,605,'dimc_streamer',24,'middle')
    t(3000,632,'i_streamer',17,'middle')
    for n,label in enumerate([f'Macros {2*module_id-1} + {2*module_id}', '256 accumulators / 3 FIFOs','Own FSMs and counters']):
        t(2020,800+n*29,label,18)
    for n,label in enumerate(['Own FSMs / tile buffer','Input transpose / weight reads','Result writes / local backpressure']):
        t(2800,800+n*29,label,17)
    # Mapped config goes to both children; start/clear nets use repeated labels.
    w([(2250,470),(2310,470),(2310,550),(3000,550),(3000,570)],'#8b5cf6')
    w([(2310,550),(2225,550),(2225,570)],'#8b5cf6')
    dot(2310,550+offset,'#8b5cf6')
    t(2560,538,'config_',17,'middle')
    t(2020,920,'clk_i · rst_ni · clear · dp_start',17)
    t(2800,920,'clk_i · rst_ni · clear · abort_job',17)
    t(2800,946,'stream_start',17)
    t(2020,950,'Local m0 / m1 map to the macros above.',17)
    for y,label in [(675,'input_stream'),(720,'kernel_stream')]:
        w([(2780,y),(2450,y)],'#3b82f6',True)
        t(2615,y-12,label,18,'middle')
    w([(2450,765),(2780,765)],'#16a34a',True)
    t(2615,753,'result / valid / ready',17,'middle')
    # Memory interfaces carry requests, grants and read responses.
    suffix='' if module_id==1 else '_2'
    for y,label,width in [(675,'input_tcdm',64),(720,'kernel_tcdm',256),(765,'output_tcdm',256)]:
        w([(3220,y),(3800,y)],both=True)
        t(3780,y-12,label+suffix,21,'end')
        t(3375,y+22,f'HCI initiator · {width} bits',16)
    for y,label in [(820,'datapath ready / done'),(880,'streamer busy / done')]:
        t(1765,y-12,label,17)
        w([(1920,y),(1750,y)],'#16a34a')

# Four independent status paths return to the shared controller.
for module_id,source_y,dest_y,lane,label in [
    (1,820,1060,1580,'dp_ready[0] / dp_done[0]'),
    (1,880,1120,1640,'streamer_flags[0]'),
    (2,1570,1390,1580,'dp_ready[1] / dp_done[1]'),
    (2,1630,1450,1640,'streamer_flags[1]')]:
    wire([(1750,source_y),(lane,source_y),(lane,dest_y),(1100,dest_y)],'#16a34a')
    text(1120,dest_y-12,label,18)

text(325,1795,'Each dimc_module expands into i_datapath and i_streamer. Cleopatra remains inside each datapath.',18)
text(325,1828,'Purple: shared control/configuration. Blue: operand streams. Green: results/status. Gray: external interfaces.',18)
text(325,1861,'Dots mark branches; crossings without dots are not connections. Repeated net labels denote connected wires.',18)
text(320,1940,'Shared starts launch both modules; all FIFO and stream handshakes advance independently after launch.',19)
text(320,1976,'Each module has its own input, weight and output base addresses. Both modules receive the same configuration bundle.',19)
text(320,2012,'Memory ports: input = 64 bits, weights/results = 256 bits per module. Overall completion includes both modules’ final writes.',19)
text(320,2048,'Source: rtl/dimc_top.sv and rtl/dimc_module.sv. Child parameters: MODULE_ID, INPUT_SIZE, KERNEL_SIZE, OUTPUT_SIZE.',19)
parts.append('</svg>')
(OUT/'dimc_top_architecture.svg').write_text('\n'.join(parts)+'\n')
