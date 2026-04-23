# coding=utf-8
# ============================================================================
# Script   : gen_module_snapshot.py
# Function : 批量生成 module_snapshot 风格的接口端口图
#            从FS中的接口信号表生成Verilog模块声明，用PIL绘制端口图
# Usage    : python gen_module_snapshot.py [interfaces.json [output_dir]]
# Output   : wd_intf_*.png
# Deps     : python 3.8+, Pillow (see requirements.txt)
# ============================================================================

import os, re, sys
from PIL import Image, ImageDraw, ImageFont

# Default output: current working directory
SCRIPT_DIR = os.getcwd()

# ============================================================================
# 6组接口的Verilog模块声明（从FS §5.2提取，左侧=输入，右侧=输出）
# ============================================================================

INTERFACES = {
    "data_in_if": {
        "verilog": """module data_in_if (
    input [3:0]  channel_empty_i,
    input [7:0]  bd_num_c0_i,
    input [7:0]  bd_num_c1_i,
    input [7:0]  bd_num_c2_i,
    input [7:0]  bd_num_c3_i,

    input        vld,
    input        sop,
    input        eop,
    input        bdlist,
    input        bd_read_flag,

    input [31:0] pkt_len,
    input [15:0] info,
    input [1:0]  bd_type,
    input [15:0] sqid,
    input [1:0]  ramid,

    input [31:0] buf_len,
    input [63:0] buf_addr,
    input [15:0] buf_id,
    input [511:0] sqe,

</right>
    output       rd,
    output [1:0] rd_channel_idx
);""",
    },
    "ram_if": {
        "verilog": """module ram_if (
</left>
    input [3:0]  bp,

    input        rsp_vld,
    input        rsp_sop,
    input        rsp_eop,
    input [13:0] rsp_sqid,
    input [11:0] rsp_byte_cnt,
    input [1023:0] rsp_data,
    input [1:0]  rsp_resp,
    input [63:0] rsp_info,

</right>
    output       rvld,
    output [13:0] sqid,
    output [63:0] addr,
    output [15:0] length,
    output [63:0] info,
    output [1:0] tid
);""",
    },
    "encry_if": {
        "verilog": """module encry_if (
</left>
    input        cvld,
    input        csop,
    input        ceop,
    input [1023:0] cipher,

</right>
    output       pvld,
    output       psop,
    output       peop,
    output [1023:0] plain
);""",
    },
    "data_out_if": {
        "verilog": """module data_out_if (
</left>
    input        bp,

</right>
    output       vld,
    output       sop,
    output       eop,
    output       type,
    output [13:0] sqid,
    output [7:0] dqid,
    output [11:0] byte_cnt,
    output [1023:0] data,
    output [15:0] pkt_len,
    output [511:0] cqe
);""",
    },
    "apb": {
        "verilog": """module apb (
</left>
    input        apb_sel,
    input        apb_enable,
    input [31:0] apb_addr,
    input        apb_write,
    input [31:0] apb_wdata,

</right>
    output [31:0] apb_rdata,
    output       apb_ready,
    output       apb_slverr
);""",
    },
    "dq_update_if": {
        "verilog": """module dq_update_if (
</left>
    input        vld,
    input [7:0]  dqid,
    input [7:0]  tail,

</right>
    output       rdy
);""",
    },
}


# ============================================================================
# Verilog parser (from module_snapshot.py)
# ============================================================================

def find_len(content):
    h = 1
    l = [10]
    for v in content.keys():
        h = h + 1
        if v[0] == '_':
            lv = 1
        else:
            lv = len(v) + 2
        for m in content[v].keys():
            h = h + 1
            l.append(lv + len(m) + 1)
    return h, max(l)


def read_line(s):
    patt1 = re.compile(r"^\s+")
    ln = re.sub(patt1, "", s)
    t = None
    sig = []
    mname = ""

    divided = re.split(r"[>[\s]", ln, 1)
    start_word = divided[0]

    if start_word == 'input':
        t = "signal"
        sig_io = 'input'
        ln = divided[1]
    elif start_word == 'output':
        t = "signal"
        sig_io = 'output'
        ln = divided[1]
    elif start_word == 'inout':
        t = "signal"
        sig_io = 'inout'
        ln = divided[1]
    elif start_word == 'module':
        t = "module"
        ln = divided[1]
    elif start_word == '</left':
        t = "left"
    elif start_word == '</right':
        t = "right"
    elif start_word == '<a':
        t = "abbr"
        ln = divided[1]

    ln = re.sub(patt1, "", ln)
    if t == 'signal':
        ssss = re.search(r'^\[.*:.*\]?', ln)
        if ssss:
            higher = re.search(r'^\[.*?:', ssss.group()).group()
            lower = re.search(r':.*?\]', ssss.group()).group()
            try:
                sig_wid = int(eval(higher[1:-1] + '-' + lower[1:-1] + '+1'))
            except:
                sig_wid = higher[1:-1]
            divided = re.split(r"[,\s]", ln, 1)
            ln = divided[1]
        else:
            sig_wid = '1'
    elif t == 'module':
        divided = re.split(r"#[\(\s]", ln, 1)
        mname = divided[0]
    elif t == 'abbr':
        divided = re.split(r"\s*</a>", ln, 1)
        mname = divided[0]

    ln = re.sub(patt1, "", ln)
    if t == 'signal':
        divided = re.split(r"[,\s]", ln, 1)
        sig_name = divided[0]
        sig = [sig_name, sig_io, sig_wid]
    return [t, sig, mname]


def parse_verilog(verilog_code):
    md_lines = re.split(r"[\n]", verilog_code)

    right = 0
    i = 0
    t_last = None
    name = ""
    abbr = ""
    left = {}
    right_dict = {}

    for ln in md_lines:
        [t, sig, mname] = read_line(ln)
        if t == 'module':
            name = mname
        elif t == 'abbr':
            abbr = mname
        elif t == 'signal':
            if t_last != 'signal':
                i = i + 1
            kk = "_" + str(i)
            if right:
                if kk not in right_dict:
                    right_dict[kk] = {}
                right_dict[kk][sig[0]] = [sig[1], sig[2]]
            else:
                if kk not in left:
                    left[kk] = {}
                left[kk][sig[0]] = [sig[1], sig[2]]
        elif t == 'left':
            right = 0
        elif t == 'right':
            right = 1
        t_last = t

    return name, abbr, left, right_dict


# ============================================================================
# PIL-based drawing (replaces tkinter)
# ============================================================================

def get_font(size, bold=False):
    """Get a monospace font, fallback to default if unavailable."""
    candidates = [
        "C:/Windows/Fonts/consola.ttf",      # Consolas
        "C:/Windows/Fonts/consolab.ttf",     # Consolas Bold
        "C:/Windows/Fonts/cour.ttf",         # Courier New
        "C:/Windows/Fonts/courbd.ttf",       # Courier New Bold
        "C:/Windows/Fonts/lucon.ttf",        # Lucida Console
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]
    if bold:
        # Try bold variants first
        bold_first = [c for c in candidates if 'bold' in c.lower() or 'bd' in c.lower()] + \
                     [c for c in candidates if 'bold' not in c.lower() and 'bd' not in c.lower()]
        candidates = bold_first

    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except:
                continue
    return ImageFont.load_default()


def draw_arrow(draw, x, y, direction, color='#999999', size=6):
    """Draw a directional arrow triangle.
    direction: 'right' = input arrow pointing right into box
               'left'  = output arrow pointing left out of box
               'both'  = inout double arrow
    """
    if direction == 'right':
        # Pointing right: tip at (x+size, y), base at (x, y-size/2) and (x, y+size/2)
        pts = [(x, y - size), (x + size, y), (x, y + size)]
        draw.polygon(pts, fill=color)
    elif direction == 'left':
        # Pointing left: tip at (x-size, y), base at (x, y-size/2) and (x, y+size/2)
        pts = [(x, y - size), (x - size, y), (x, y + size)]
        draw.polygon(pts, fill=color)
    elif direction == 'both':
        pts1 = [(x + size + 2, y - size), (x + size * 2 + 2, y), (x + size + 2, y + size)]
        pts2 = [(x - size - 2, y - size), (x - size * 2 - 2, y), (x - size - 2, y + size)]
        draw.polygon(pts1, fill=color)
        draw.polygon(pts2, fill=color)


def draw_image(name, abbr, left, right_dict, output_path):
    """Draw the module snapshot directly to a PNG file using PIL."""
    BORDER_X = 110
    BORDER_Y = 30
    LINE_X = 13
    LINE_Y = 30
    EXTRA_RIGHT = 50  # extra space for bus width annotations on right

    font_sig = get_font(15, bold=False)
    font_sig_b = get_font(15, bold=True)
    font_wid = get_font(12, bold=False)
    font_title = get_font(17, bold=True)

    hl, ll = find_len(left)
    hr, lr = find_len(right_dict)

    # Title — single line
    title = name

    # Calculate dimensions
    # max_sig_name_len: max signal name length on either side (for width calculation)
    max_left_name = 0
    for d in left:
        for s in left[d]:
            max_left_name = max(max_left_name, len(s))
    max_right_name = 0
    for d in right_dict:
        for s in right_dict[d]:
            max_right_name = max(max_right_name, len(s))

    # Text width estimation: 15px font, ~9px per char for monospace
    char_w = 10
    left_text_w = max_left_name * char_w + 20  # 20px margin from box edge
    right_text_w = max_right_name * char_w + 20

    # Measure title width
    title_bbox = font_title.getbbox(title)
    title_w = title_bbox[2] - title_bbox[0]
    title_h = title_bbox[3] - title_bbox[1]

    # Box dimensions
    # Box must be wide enough for: left_text + right_text + title + some padding
    min_box_w = left_text_w + right_text_w + title_w + 60
    # Also respect find_len-based width
    calc_w = LINE_X * (2 * max(ll, lr) + 3)
    box_w = max(min_box_w, calc_w)
    box_h = LINE_Y * max(hl, hr)

    # Total image size
    img_w = box_w + BORDER_X * 2 + EXTRA_RIGHT
    img_h = box_h + BORDER_Y * 2

    # Create image
    img = Image.new('RGB', (img_w, img_h), 'white')
    draw = ImageDraw.Draw(img)

    # Draw box rectangle
    draw.rectangle([BORDER_X, BORDER_Y, BORDER_X + box_w, BORDER_Y + box_h],
                   outline='#2C3E50', width=2, fill='white')

    # Draw title centered in box
    title_x = BORDER_X + box_w // 2
    title_y = BORDER_Y + box_h // 2 - title_h // 2
    draw.text((title_x, title_y), title, fill='#333333', font=font_title, anchor='mm')

    # Draw left signals
    idx = 1
    start_y = (box_h + BORDER_Y * 2 - (hl - 1) * LINE_Y) / 2
    for d in left:
        for s in left[d]:
            sig_io = left[d][s][0]
            sig_wid = left[d][s][1]
            y = int(start_y + idx * LINE_Y)

            # Connection line from image edge to box
            line_start = 5
            if str(sig_wid) == '1':
                draw.line([(line_start, y), (BORDER_X, y)], fill='#c0c0c0', width=2)
            else:
                draw.line([(line_start, y), (BORDER_X, y)], fill='#c0c0c0', width=4)
                draw.line([(15, y - 6), (25, y + 6)], fill='#c0c0c0', width=2)
                draw.text((28, y - 12), str(sig_wid), fill='#666666', font=font_wid, anchor='lm')

            # Arrow: input → at box edge pointing right; output → at line edge pointing left
            if sig_io == 'input':
                draw_arrow(draw, BORDER_X, y, 'right')
            elif sig_io == 'output':
                draw_arrow(draw, line_start, y, 'left')
            else:
                draw_arrow(draw, BORDER_X, y, 'both')

            # Signal name
            draw.text((BORDER_X + 20, y), s, fill='#000000', font=font_sig, anchor='lm')

            idx += 1
        idx += 1

    # Draw right signals
    idx = 1
    start_y = (box_h + BORDER_Y * 2 - (hr - 1) * LINE_Y) / 2
    box_right = BORDER_X + box_w
    for d in right_dict:
        for s in right_dict[d]:
            sig_io = right_dict[d][s][0]
            sig_wid = right_dict[d][s][1]
            y = int(start_y + idx * LINE_Y)

            # Connection line from box to image edge
            line_end = img_w - 10
            if str(sig_wid) == '1':
                draw.line([(box_right, y), (line_end, y)], fill='#c0c0c0', width=2)
            else:
                draw.line([(box_right, y), (line_end, y)], fill='#c0c0c0', width=4)
                draw.line([(box_right + 15, y - 6), (box_right + 25, y + 6)], fill='#c0c0c0', width=2)
                draw.text((box_right + 30, y - 12), str(sig_wid), fill='#666666', font=font_wid, anchor='lm')

            # Arrow: output → at line end pointing right; input → at box edge pointing left
            if sig_io == 'output':
                draw_arrow(draw, line_end, y, 'right')
            elif sig_io == 'input':
                draw_arrow(draw, box_right, y, 'left')
            else:
                draw_arrow(draw, box_right, y, 'both')

            # Signal name
            draw.text((box_right - 20, y), s, fill='#000000', font=font_sig, anchor='rm')

            idx += 1
        idx += 1

    # Save
    img.save(output_path, 'PNG')
    print(f"  OK -> {os.path.basename(output_path)} ({img_w}x{img_h})")


# ============================================================================
# Main
# ============================================================================

if __name__ == '__main__':
    import json

    # Support loading from external JSON config:
    #   python gen_module_snapshot.py interfaces.json [output_dir]
    # JSON format: {"if_name": {"verilog": "module ..."}, ...}
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        with open(sys.argv[1], encoding='utf-8') as f:
            interfaces = json.load(f)
        output_dir = sys.argv[2] if len(sys.argv) > 2 else SCRIPT_DIR
    else:
        interfaces = INTERFACES
        output_dir = SCRIPT_DIR

    print("Generating module_snapshot interface diagrams...")

    for intf_name, intf_data in interfaces.items():
        output_path = os.path.join(output_dir, f"wd_intf_{intf_name}.png")
        print(f"[module_snapshot] {intf_name}")
        try:
            module_name, abbr, left, right_dict = parse_verilog(intf_data['verilog'])
            draw_image(module_name, abbr, left, right_dict, output_path)
        except Exception as e:
            import traceback
            print(f"  FAIL: {e}")
            traceback.print_exc()

    print("Done.")
