from dataclasses import dataclass, field, replace
from scratch import ScratchSpace 
from typing import Any, Protocol
from lib import MinHeap
from limits import (
        VLEN, EX_LOAD, EX_ALU, EX_VALU
        )

# The instruction understood by this machine
SerializedInstruction = tuple[str, tuple] # Example: ("valu", ("vbroadcast", destaddr, srcaddr))

# Models an inclusive range
@dataclass() # Force key naming
class Range:
    lo: int
    hi: int

    def is_empty(self):
        return self.hi < self.lo

    def intersect(self, that: 'Range') -> 'Range':
        return Range(max(self.lo, that.lo), min(self.hi, that.hi))

    def values(self):
        lo = self.lo
        hi = self.hi
        if hi >= lo:
            return [x for x in range(lo, hi+1)]
        return []

SPECIAL_MEM_REGISTER_NAME = '__mem__'

class LogicalOp:
    pass

@dataclass(kw_only=True, eq=True, frozen=True, order=True)
class ArrayOp(LogicalOp):
    name: str # The variable whose block this Array encompasses
    offset: int # offset within the array
    is_vector: bool # Whether vectored read
    is_read: bool


    @classmethod
    def of(cls, *, ss, name, offset, is_vector, is_read):
        vm = ss.var_meta_of(name)
        assert offset < vm.size()
        if is_vector:
            assert offset + VLEN <= vm.size()

        return cls(name = name, offset = offset, is_vector = is_vector, is_read = is_read)


    def addr_of(self, ss: ScratchSpace):
        return ss.var_meta_of(self.name).addr_of(0) + self.offset


    def range(self, ss: ScratchSpace, slot:int):
        if self.is_mem():
            return Range(-1, -1)

        base = self.addr_of(ss)
        return Range(base, base + (VLEN if self.is_vector else 1) - 1)


    def scalar_at_offset(self, offset:int):
        return replace(self, offset = self.offset + offset, is_vector = False)


    def is_mem(self):
        return False


    def compact_str(self):
        if self.is_vector:
            return f"{self.name:>13}[{self.offset:>2} - {self.offset+VLEN-1:>2}]"
        else:
            return f"{self.name:>18}[{self.offset:>2}]"


# A Logical Register that is converted to address when emitting SerializedInstruction
# It is annotated with whether the usage is a read/write and scalar/vector
# for performing optimizations
@dataclass(kw_only=True, eq=True, frozen=True, order=True) # Force key naming
class LogicalRegister(LogicalOp):
    name: str
    offset: int
    # True iff this read is a vectored read. Implies offset = 0.
    # Scalar read is either a single word read at `offset` of a vectored
    # variable `name` or a read of a scalar variable
    # This says nothing about whether the variable `name` is itself a vector
    is_vector: bool
    is_read: bool


    def __post_init__(self):
        assert self.offset >= 0
        assert self.offset < VLEN
        if self.is_vector:
            assert self.offset == 0


    def range(self, ss: ScratchSpace, slot:int):
        if self.is_mem():
            return Range(-1, -1)

        vm = ss.var_meta_of(self.name)
        if self.is_vector:
            assert vm.is_vector
            return Range(vm.addr_of(slot), vm.addr_of(slot) + VLEN - 1)
        else:
            addr = vm.addr_of(slot) + self.offset
            return Range(addr, addr)


    def is_mem(self):
        return self.name == SPECIAL_MEM_REGISTER_NAME


    def scalar_at_offset(self, offset:int):
        return replace(self, offset = offset, is_vector = False)


    def addr_of(self, ss, slot):
        assert not self.is_mem()
        return ss.var_meta_of(self.name).addr_of(slot) + self.offset
    

    def is_vector_constant(self, ss):
        assert not self.is_mem()
        varmeta = ss.var_meta_of(self.name)
        return varmeta.is_constant and self.is_vector


    def is_scalar_constant(self, ss):
        assert not self.is_mem()
        varmeta = ss.var_meta_of(self.name)
        # Note: use self.is_vector (the actual use type) not varmeta.is_vector (the declared type)
        return varmeta.is_constant and (not self.is_vector)


    def constant_value(self, ss):
        assert not self.is_mem()
        assert self.is_vector_constant(ss) or self.is_scalar_constant(ss)
        varmeta = ss.var_meta_of(self.name)
        return varmeta.constant_value


    def overlaps(self, that, ss: ScratchSpace, slot: int):
        return not self.range(ss, slot).intersect(that.range(ss, slot)).is_empty()


    def compact_str(self):
        if self.is_vector:
            return f"{self.name:>19}[ ]"
        elif self.offset > 0:
            return f"{self.name:>19}[{self.offset}]"
        else:
            return f"{self.name:>22}"

LR = LogicalRegister


# An instruction that is specified in terms of logical registers that can be replaced 
# at optimization time based on thread_idx
@dataclass(eq=True, frozen=True, order=True)
class LogicalInstruction:
    engine: str
    inst: tuple # Same as SerializedInstruction except that registers are Logical

    def compact_str(self):
        ret = f"{self.engine:>10}"
        ret += " ".join([y.compact_str() if isinstance(y, LR) or isinstance(y, ArrayOp) else f"{str(y):>22}" for y in self.inst])
        return ret


LI = LogicalInstruction


class Work(Protocol):
    def have_more(self) -> bool: ...
    def take(self) -> list[SerializedInstruction]: ...

INFINITE_SET = frozenset(range(-1, 100))


@dataclass(kw_only=True, eq=True, unsafe_hash=True)
class InstrMeta:
    instid: int # Instruction id in the program order
    lin: LogicalInstruction
    tid: int # Thread id; = 0 if global
    instid_in_thread: int # The instruction id within this thread
    after: MinHeap  # ids of instructions that this unlocks
    tidrange: frozenset[int] = field(default_factory = lambda: INFINITE_SET)


    def __post_init__(self):
        tid = self.tid
        tidrange = self.tidrange
        assert tid == -2 or (tid in tidrange), f"{tid} was neither -2 nor in {tidrange}"


    def registers(self, ss:ScratchSpace):
        ret = []
        lin = self.lin
        for param in lin.inst:
            if not isinstance(param, LogicalRegister) and not isinstance(param, ArrayOp):
                continue
            ret.append(param)

        # Reads and Writes to memory are treated as happening to a special register
        # since we don't know the actual memory address the read or write is happening
        # at optimization time.
        if lin.inst[0] in ["load", "load_offset", "vload", "vstore", "store"]:
            lr = LogicalRegister(name = SPECIAL_MEM_REGISTER_NAME
                                  , offset = 0
                                  , is_vector = False
                                  , is_read = lin.engine == EX_LOAD)
            ret.append(lr)

        return ret


    def is_vector_imm_add(self, ss):
        lin = self.lin
        if lin.engine != EX_VALU:
            return False
        if lin.inst[0] != '+':
            return False
        regs = self.registers(ss)
        if len(regs) != 3:
            return False
        for reg in regs:
            if not reg.is_vector:
                return False
        if not regs[2].is_vector_constant(ss):
            return False
        return True


    def is_scalar_imm_add(self, ss):
        lin = self.lin
        if lin.engine != EX_ALU:
            return False
        if lin.inst[0] != '+':
            return False
        regs = self.registers(ss)
        if len(regs) != 3:
            return False
        for reg in regs:
            if reg.is_vector:
                return False
        if not regs[2].is_scalar_constant(ss):
            return False
        return True


    def opcode(self):
        return self.lin.inst[0]


    def compact_str(self):
        return f"{self.instid:>10} {self.tid:>5} {self.instid_in_thread:>5} {self.lin.compact_str():150}          {self.after}"


