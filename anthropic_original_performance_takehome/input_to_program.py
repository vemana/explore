from limits import VLEN
from parser import Program, program as parser
import textwrap

def input_to_program(height:int, batch_size:int, rounds:int) -> str: 
    assert batch_size % VLEN == 0
    text = input_to_program_text(height, batch_size, rounds)
    parsed = parser.parse(text)
    if parsed.next_index != len(text):
      print(f"Remaining text: {text[parsed.next_index:]}")
      raise Exception("Failed to parse the whole program")
    return parsed.value

class Template:
    def __init__(self, template):
        self.template = template


    def using(self, special, standard):
      return self.template\
              .replace('$special$', indent(special))\
              .replace('$standard$', indent(standard))


def make_template(size, special_nodes: set[int]):
    assert size > 0, f"Invalid size {size}. Should be > 0"
    for x in special_nodes:
        assert 0<=x and x < size, f"Invalid special node: {x}. Should be in [0, {size})"

    specials = []
    standards = []
    start = -1

    for i in range(0, size):
        special = i in special_nodes
        prev_special = (i-1) in special_nodes

        if i == 0 or prev_special != special:
            if start >= 0:
                (standards if special else specials).append((start, i))
            start = i

    (specials if size - 1 in special_nodes else standards).append((start, size))
#     print(f"Specials = {specials}, standards = {standards}")

    if len(specials) == 0:
        return Template("\n$standard$\n")

    if len(standards) == 0:
        return Template("\n$special$\n")

    template = "\n\n"
    for idx, item in enumerate(specials):
        start, end = item
        template += "eliftid " if idx > 0 else "iftid "
        template += f"range({start}, {end})"
        template += "\n"
        template += "$special$"
        template += "\n"

    for idx, item in enumerate(standards):
        start, end = item
        template += "eliftid " if idx < len(standards) - 1 else "elsetid "
        template += f"range({start}, {end})" if idx < len(standards) - 1 else ""
        template += "\n"
        template += "$standard$"
        template += "\n"

    template += "endiftid\n\n"
    return Template(template)


def indent(s):
    return textwrap.indent(s, '    ')

global_preamble="""
register[] temp1, temp2, temp3, temp4
register[] treevals

treevals = @14
register[] b0 = treevals[0]
register[] b1 = treevals[1]
register[] b2 = treevals[2]
register[] b3 = treevals[3]
register[] b4 = treevals[4]
register[] b5 = treevals[5]
register[] b6 = treevals[6]
register[] b7 = treevals[7]

treevals = @7
register[] t0 = treevals[0]
register[] t1 = treevals[1]
register[] t2 = treevals[2]
register[] t4 = treevals[4]
register[] t5 = treevals[5]
register[] t6 = treevals[6]
treevals = treevals[3] # treevals = t3


register inp_values_ptr = @6
end global
"""


thread_preamble="""
# Compiler fills in implicit registers tidx and tidxlen
# Declare if you want to use them
thread register tidxlen

# Work registers
thread register[] v, idx, p1, p2

tidxlen = tidxlen + inp_values_ptr
v = @tidxlen

"""

level0_header = """
v = v ^ t0
"""

level0_footer = """
idx = v % 2
"""

level1_header = """
p1 = idx ? t2 : t1
v = v ^ p1
"""

level1_valu_header ="""
p2 = t2 - t1
p1 = idx * p2 + t1
v = v ^ p1
"""

level1_footer="""
p1 = v % 2
"""

# This is the only one which requires `t` as a separate variable
# Otherwise, only p1 and p2 as temp variables suffice.
level21_header = """
p2 = p1 ? t6 : t5
temp1 =  p1 ? t4 : treevals
p2 = idx ? p2 : temp1

idx = idx - -5
idx = idx * 2 + p1
v = v ^ p2
"""

level22_header = """
p2 = p1 ? t6 : t5
temp2 =  p1 ? t4 : treevals
p2 = idx ? p2 : temp2

idx = idx - -5
idx = idx * 2 + p1
v = v ^ p2
"""

level2_load_header = """
idx = idx - -5
idx = idx * 2 + p1
p1 = @idx[]
v = v ^ p1
"""

level2_footer="""
p1 = v % 2
p2 = p1 ? -5 : -6
idx = idx * 2 + p2
"""

level3_header = """
p1 = @idx[]
v = v ^ p1
"""

level3_flow_based_header = """

p2 = idx - 19
p1 = p2 ? b0 : b5

p2 = p2 + 2
p1 = p2 ? p1 : b3

p2 = p2 + 2
p1 = p2 ? p1 : b1

p2 = p2 + -6
p1 = p2 ? p1 : b7

p2 = p2 - -5
p1 = p2 ? p1 : b2

p2 = p2 - 2
p1 = p2 ? p1 : b4

p2 = p2 - 2
p1 = p2 ? p1 : b6

v = v ^ p1
"""

level3_flow_based_footer = """
p1 = v % 2
p2 = p1 ? -5 : -6
idx = idx * 2 + p2
"""

computation="""

# Stage 1
v = v * 4097 + 0x7ED55D16

# Stage 2
p1 = v ^ 0xC761C23C
p2 = v >> 19
v = p1 ^ p2

# Fuse stages 3 and 4
p1 = v * 33 + 3925396509
p2 = v * 16896 + 2899272192 
v = p1 ^ p2

# Stage 5
v = v * 9 + 0xFD7046C5 

# Stage 6
p1 = v ^ 0xB55A4F09
p2 = v >> 16
v = p1 ^ p2
"""

level_footer="""
p1 = v % 2
p2 = p1 ? -5 : -6
# p2 = p1 + -6
idx = idx * 2 + p2
"""

footer="""
@tidxlen = v
"""


def conditional_l1(size, special_nodes: set[int]):
    template = make_template(size, special_nodes)
    header = template.using(level1_valu_header, level1_header)
    footer = level1_footer
    return header, footer


def conditional_l21(size, special_nodes: set[int]):
    template = make_template(size, special_nodes)
    header = template.using(level21_header, level22_header)
    footer = level2_footer
    return header, footer


def conditional_l22(size, special_nodes: set[int]):
    template = make_template(size, special_nodes)
    header = template.using(level21_header.replace('temp1', 'temp3'), level22_header.replace('temp2', 'temp4'))
    footer = level2_footer
    return header, footer


def conditional_l3(size, special_nodes: set[int]):
    template = make_template(size, special_nodes)
    header = template.using(level3_flow_based_header, level3_header)
    footer = template.using(level3_flow_based_footer, level_footer)
    return header, footer


def conditional_footer(size, special_nodes: set[int]):
    template = make_template(size, special_nodes)
    return template.using(footer, footer)


def input_to_program_text(height, batch_size, rounds) -> str:
    ret = ""
    ret += global_preamble
    ret += thread_preamble

    use_custom = lambda: True and level == 3 #and r == rounds - 2
    nthreads = batch_size // VLEN

    for r in range(0, rounds):
        ret += f"\n######### Round {r} #########\n"
        level = r % (height+1)
        custom = use_custom()

        usecustom = True
        l3round1 = usecustom and level == 3 and r == 3
        l3round2 = usecustom and level == 3 and r > 3
        l2round1 = usecustom and level == 2 and r == 2
        l2round2 = usecustom and level == 2 and r > 2
        l1round1 = usecustom and level == 1 and r == 1
        l1round2 = usecustom and level == 1 and r > 1

        # l1 special = valu instead of 1?
        # l2 special = load instead of 3?
        # l3 special = 7? instead of load
        if level == 0:
            h, f = level0_header, level0_footer
        elif l1round1:
            h, f = conditional_l1(nthreads, set(range(0, 32)))
        elif l1round2:
            h, f = conditional_l1(nthreads, set(range(0, 0)))
        elif l2round1:
            h, f = conditional_l21(nthreads, set(range(0, 32, 2)))
        elif l2round2:
            h, f = conditional_l22(nthreads, set(range(0, 32, 2)))
        elif l3round1:
            h, f =  conditional_l3(nthreads, set(range(2, nthreads, 1)))
        elif l3round2:
            h, f =  conditional_l3(nthreads, set(range(0, nthreads, 1)))
        else:
            h, f = level3_header, level_footer
        
        ret += h
        ret += computation
        if level == height or r == rounds - 1:
            f = ""
        ret += f

    ret += conditional_footer(nthreads, set())

    with open('/tmp/program.txt', "w", encoding="utf-8") as file:
        file.write(ret) 
    return ret

