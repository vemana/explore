from dataclasses import replace
# from typing import Any, Protocol
from scratch import ScratchSpace 
from lib import MinHeap, MinHeap as ios
from collections import defaultdict, Counter
from display import Display, DataInfo
from util import pretty_print_map
import threading
import time
import functools

from data_model import (
        LogicalRegister as LR
        , SerializedInstruction
        , InstrMeta
        , LogicalInstruction as LI
        , ArrayOp
        , Work
        , INFINITE_SET
        )
from limits import (
        SLOT_LIMITS, EX_VALU, EX_ALU, EX_LOAD, EX_STORE, EX_FLOW
        , VLEN
        )

# The order is important. valu > alu because we should try to assign bulk work first
EX_UNITS = [EX_VALU, EX_ALU, EX_LOAD, EX_STORE, EX_FLOW]


def imeta_priority_fn(self: InstrMeta, all_imetas: list[InstrMeta], conc_threads: int):
    def next_real_instid(imeta):
        if imeta.tid >= 0:
            return imeta.tid, imeta.instid_in_thread, imeta.instid

        if imeta.after.is_empty():
            return -1, -1, -1

        best = None
        for nidx in imeta.after:
            nmeta = all_imetas[nidx]
            cand = next_real_instid(nmeta)
            if best is None or cand < best:
                best = cand
        return best
    
    def block(self):
        if self.tid < 0:
            # Find the nearest thread that this instruction is blocking
            r = next_real_instid(self)
            return 0, *r

        if not hasattr(self, 'checkpoints'):
            self.checkpoints = [289, 100000]
#             self.checkpoints = [1000000]

        for idx, c in enumerate(self.checkpoints):
            if self.instid_in_thread < c:
                return idx, work_slot_of(self.tid, conc_threads), self.instid_in_thread

        assert False

    # Remember that after split, there can be VLEN with the same instid but different register offsets
    return (0
#             , 0 if work_slot_of(self.tid, conc_threads) == 0 else 1
#             , 0 if self.tid <= 0 else 1
            , block(self)
            , self.tid
            , self.instid
            , self.lin
            , self.tid
            , self.instid_in_thread
            , self.after
            )


SET_MINUS_ONE = frozenset([-1])

# Sets the value of the vector constant register whose value is `src_val` to `req_val`
def set_constant(src_val, req_val, ss: ScratchSpace):
    ss.alloc_const(src_val, True)
    ret = []
    ret.append(InstrMeta(instid = -1
                         , lin = LI(EX_LOAD
                                    , ("const"
                                       , LR(name=ss.constant_name(src_val, is_vector=True)
                                            , offset = 0
                                            , is_vector=False
                                            , is_read=False)
                                       , req_val))
                         , tid = -1
                         , instid_in_thread = -1
                         , after = ios()))
    ret.append(InstrMeta(instid = -1
                         , lin = LI(EX_VALU
                                    , ("vbroadcast"
                                       , LR(name=ss.constant_name(src_val, is_vector=True)
                                            , offset = 0
                                            , is_vector=True
                                            , is_read=False)
                                       , LR(name=ss.constant_name(src_val, is_vector = True)
                                            , offset = 0
                                            , is_vector = False
                                            , is_read = True)))
                         , tid = -1
                         , instid_in_thread = -1
                         , after = ios()))
    return ret


class InstrGraph:
    def __init__(self, ss: ScratchSpace, num_threads:int):
        self.num_threads = num_threads
        self.ss = ss
        self.imetas: list[InstrMeta] = []
        self.num_global = 0
        self.globalimetas: list[InstrMeta] = []


    def add(self, linst: LI, is_global, *, tidrange: set[int]):
        if is_global:
            assert tidrange is None or tidrange == {-1}\
                , f"For global instructions, tidrange should be -1, but was {tidrange}"
            self.globalimetas.append(InstrMeta(instid=-1
                                               , lin=linst
                                               , tid=-1
                                               , instid_in_thread = -1
                                               , after=ios()
                                               , tidrange = SET_MINUS_ONE))
        else:
            self.imetas.append(InstrMeta(instid=-1
                                         , lin=linst
                                         , tid=-2
                                         , instid_in_thread=-1
                                         , after=ios()
                                         , tidrange = INFINITE_SET if tidrange is None else tidrange))

    
    def add_pause(self, pinst: LI, is_global):
        pass
        # Needs real sync between threads, which we don't suppor


    def get_tidmetas(self, conc_threads):
        nthreads = self.num_threads
        cthreads = conc_threads
        assert cthreads <= nthreads

        if not self.ss.has_variable('tidxlen'):
            return [], []


        if cthreads <= 2*VLEN:
            ret = [InstrMeta(instid = -1
                          , lin = LI(EX_LOAD, ("const"
                                               , LR(name="tidxlen"
                                                    , offset=0
                                                    , is_vector=False
                                                    , is_read=False)
                                               , i * VLEN))
                          , tid = i
                          , instid_in_thread = -1
                          , after = ios()) 
                for i in range(0, nthreads)]
            return ret, []

        assert cthreads > 2*VLEN


        def tid_array_op(offset, *, is_vector, is_read):
            return ArrayOp.of(ss = self.ss
                           , name = "tidxlen"
                           , offset = offset
                           , is_vector = is_vector
                           , is_read = is_read)
          
        ret = []

        # Temporarily hijack the '2' constant. Note: we can choose to implement
        # ss.dealloc to return this space back for allocation in case `2` is not
        # really a constant required by this implementation.
        ret.extend(set_constant(2, VLEN*VLEN, self.ss))

        ret.extend([InstrMeta(instid = -1
                          , lin = LI(EX_LOAD, ("const"
                                               , tid_array_op(i, is_vector = False, is_read = False)
                                               , i * VLEN
                                               ))
                          , tid = -1
                          , instid_in_thread = -1
                          , after = ios()) 
               for i in range(0, VLEN)])


        npos = VLEN
        while npos < cthreads:
            start = npos if npos + VLEN - 1 < cthreads else cthreads - VLEN
            ret.append(InstrMeta(instid = -1
                          , lin = LI(EX_VALU, ("+"
                                               , tid_array_op(start, is_vector=True, is_read=False)
                                               , tid_array_op(start - VLEN, is_vector=True, is_read=True)
                                               , LR(name=self.ss.constant_name(2, is_vector=True), offset = 0, is_vector=True, is_read=True)))
                          , tid = -1
                          , instid_in_thread = -1
                          , after = ios()))
            npos = start + VLEN

        ret.extend(set_constant(2, 2, self.ss))

        tidspecific = [
            InstrMeta(instid = -1
                      , lin = LI(EX_LOAD, ("const", LR(name="tidxlen", offset=0, is_vector=False, is_read=False), i * VLEN))
                      , tid = i
                      , instid_in_thread = -1
                      , after = ios()) 
            for i in range(cthreads, nthreads)
            ]

        return tidspecific, ret


    def get_work(self, *, conc_threads:int, optimize=False) -> Work:
        ss = self.ss
        imetas = []
        tidmetas, moreglobal = self.get_tidmetas(conc_threads)
        imetas.extend(moreglobal)
        imetas.extend(self.globalimetas)

        for i in range(0, self.num_threads):
            threadinsts = [x for x in tidmetas if x.tid == i] \
                          + [replace(x, tid=i) for x in self.imetas if i in x.tidrange]
            for idx, x in enumerate(threadinsts):
                x.instid_in_thread = idx
            imetas.extend(threadinsts)
        
        # If not optimizing, assign serial work
        if not optimize:
            for idx, imeta in enumerate(imetas):
                imeta.instid = idx
                # Strict-order instructions within a thread
                imeta.after = ios.initial(idx+1) if idx + 1 < len(imetas) \
                        and imeta.tid >= 0 and imeta.tid == imetas[idx+1].tid else ios()
        else:
            for idx, imeta in enumerate(imetas):
                imeta.instid = idx
                imeta.after = ios()


        def handle_conflict(prev, cur, loop_count):
            if loop_count == 1:
                prev, cur = cur, prev
                cur = len(imetas) - 1 - cur

            imetas[prev].after.add(cur)

      
        ssize = ss.size()
        for loop_count in range(0, 2):
            last_write = [-1] * (ssize + 1)
            for idx, imeta in enumerate(imetas):
                slot = work_slot_of(imeta.tid, conc_threads)
                for register in imeta.registers(ss):
                    if register.is_mem():
                        # This is not safe in general, but works for our problem
                        # We assume no pointer aliasing at all and a few such assumptions
                        continue

                    for loc in register.range(ss, slot).values():
                        # This makes serious assumptions about how memory is accessed. It is NOT general purpose
                        if last_write[loc] >= 0:
                            handle_conflict(last_write[loc], idx, loop_count)

                for register in imeta.registers(ss):
                    if not register.is_read:
                        for loc in register.range(ss, slot).values():
                            last_write[loc] = idx

            imetas.reverse()


        return GreedyWorkPacker(imetas, self.num_threads, conc_threads, ss)


def work_slot_of(tid, conc_threads):
    return tid % conc_threads


def data_map(imeta:InstrMeta):
    text = imeta.compact_str()
    engine = imeta.lin.engine
    instr = imeta.lin.inst[0]
    if engine == EX_ALU:
        return DataInfo(hover=text, color="magenta", label="A")
    if engine == EX_VALU:
        return DataInfo(hover=text, color="green", label="V")
    if engine == EX_LOAD:
        return DataInfo(hover=text, color="blue", label="L")
    if engine == EX_STORE:
        return DataInfo(hover=text, color="purple", label="S")
    if engine == EX_FLOW:
        if instr == "vselect":
            return DataInfo(hover=text, color="red", label="F")
        else:
            return DataInfo(hover=text, color="orange", label="I")

    raise Exception("haha")


# Packs work by taking any schedulable instructions in the following manner:
# If VALU slots are available, schedule it
# If ALU slots are available, split any VALU work to schedule here
# Otherwise, just pack as many as you can
class GreedyWorkPacker(Work):
    def __init__(self, imetas: list[InstrMeta], num_threads:int, conc_threads: int, ss: ScratchSpace):
        self.imetas = imetas
        self.ss = ss
        self.num_threads = num_threads
        self.conc_threads = conc_threads

        self.incount: list[int] = [0] * len(self.imetas)
        self.frontier: list[InstrMeta] = []  # All issuable instructions
        # All issuable instructions with tids < self.next_batch_tid
        self.free: MinHeap[InstrMeta] = MinHeap(priority_key_fn = functools.partial(imeta_priority_fn
                                                                                    , all_imetas = self.imetas
                                                                                    , conc_threads = self.conc_threads))
        self.next_batch_tid = self.conc_threads # Enable the first batch of conc_threads AND global thread
        self.schedulable_count_by_tid = defaultdict(int)

        self.split_counts = defaultdict(int)
        self.cycle_number = 0
        self.__initialize()


    def __initialize(self):
        imetas = self.imetas
        for imeta in imetas:
            for idx in imeta.after:
                self.incount[idx] = self.incount[idx] + 1

        for idx in range(0, len(imetas)):
            imeta = imetas[idx]
            if self.incount[idx] == 0:
                (self.free if imeta.tid < self.next_batch_tid else self.frontier).append(imeta)
                self.schedulable_count_by_tid[imeta.tid] += 1

        self.__initialize_display()
    

    def __initialize_display(self):
        imetas = self.imetas
        conc_threads = self.conc_threads
        self.display = Display(
            N          = conc_threads + 1, 
            S          = len(imetas),
        )


    def __fall_down_to_free(self):
        # This can be a HashSet and avoid copy
        for imeta in self.frontier[:]:
            if imeta.tid < self.next_batch_tid:
                self.free.append(imeta)
                self.frontier.remove(imeta)


    def __retire(self, imeta):
        newly_scheduled_threads = False

        imetas = self.imetas
        self.free.remove(imeta)
        self.schedulable_count_by_tid[imeta.tid] -= 1
        if self.schedulable_count_by_tid[imeta.tid] == 0 and self.next_batch_tid < self.num_threads:
            self.next_batch_tid += 1
            newly_scheduled_threads = True

        for idx in imeta.after:
            self.incount[idx] = self.incount[idx] - 1
            if self.incount[idx] == 0:
                (self.free if imetas[idx].tid < self.next_batch_tid else self.frontier).append(imetas[idx])
                self.schedulable_count_by_tid[imetas[idx].tid] += 1

        if newly_scheduled_threads:
            self.__fall_down_to_free()



    def __to_serialized(self, linst: LI, slot:int) -> SerializedInstruction:
        engine, inst = linst.engine, linst.inst
#         print(f"Serializing {inst} in engine {engine}")
        ilist = list(inst)
        for idx in range(0, len(ilist)):
            cur = ilist[idx]
            match cur:
                case LR(name=name, offset=offset) as reg:
                    ilist[idx] = reg.addr_of(self.ss, slot)
                case ArrayOp() as aop:
                    ilist[idx] = aop.addr_of(self.ss)
        return (engine, tuple(ilist))


    def __obtain_for_engine(self, engine, slots) -> list[SerializedInstruction]:
        to_retire = []
        ret = []
        rem_slots = slots
        for imeta in self.free:
            if rem_slots > 0 and imeta.lin.engine == engine:
                rem_slots = rem_slots - 1
                ret.append(self.__to_serialized(imeta.lin, work_slot_of(imeta.tid, self.conc_threads)))
                to_retire.append(imeta)

        return (ret, to_retire)


    def __split_one_free_valu_to_alu(self, imeta):
        regs = imeta.registers(self.ss)
        assert len(regs) == 3, f"Length of valu instruction expected to be 3. Was {len(regs)} from {imeta}"
        for i in range(0, 3):
            assert (isinstance(regs[i], ArrayOp) or regs[i].offset == 0), f"{type(regs[i])} {regs[i].compact_str()}\n{regs[i].offset}\n{imeta.compact_str()}"

        nmetas = [InstrMeta(
                    instid = imeta.instid
                    , lin = LI(EX_ALU , (imeta.lin.inst[0]
                                   , regs[0].scalar_at_offset(i)
                                   , regs[1].scalar_at_offset(i)
                                   , regs[2].scalar_at_offset(i)))
                    , tid = imeta.tid
                    , instid_in_thread = imeta.instid_in_thread
                    , after = imeta.after) for i in range(0, VLEN)]

        for idx in imeta.after:
            self.incount[idx] += (VLEN - 1)
        self.free.remove(imeta)
        self.free.extend(nmetas)
        self.schedulable_count_by_tid[imeta.tid] += VLEN - 1

        self.split_counts[imeta.opcode()] += 1
        return True


    def __split_one_free_multiply_add(self, imeta):
        regs = imeta.registers(self.ss)
        assert imeta.lin.inst[0] == "multiply_add"
        assert len(regs) == 4
        for i in range(0, 4):
            assert regs[i].offset == 0

        dest,a,b,c = regs[0], regs[1], regs[2], regs[3]
        # dest = a*b + c

        if dest.overlaps(c, self.ss, work_slot_of(imeta.tid, self.conc_threads)):
            return False

        clen = len(self.imetas)

        # dest = a * b
        first =  [InstrMeta(
                    instid = imeta.instid
                    , lin = LI(EX_ALU , ('*'
                                   , dest.scalar_at_offset(i)
                                   , a.scalar_at_offset(i)
                                   , b.scalar_at_offset(i)))
                    , tid = imeta.tid
                    , instid_in_thread = imeta.instid_in_thread
                    , after = MinHeap([clen + i])) for i in range(0, VLEN)]

        # dest = dest + c
        second =  [InstrMeta(
                    instid = clen + i
                    , lin = LI(EX_ALU , ('+'
                                   , dest.scalar_at_offset(i)
                                   , dest.scalar_at_offset(i)
                                   , c.scalar_at_offset(i)))
                    , tid = imeta.tid
                    , instid_in_thread = imeta.instid_in_thread
                    , after = imeta.after) for i in range(0, VLEN)]

        assert len(second) == VLEN

        self.imetas.extend(second)
        self.incount.extend([0] * VLEN)
        for idx in range(clen, len(self.imetas)):
            self.incount[idx] = 1

        for idx in imeta.after:
            self.incount[idx] += (VLEN - 1)
        self.free.remove(imeta)
        self.free.extend(first)
        self.schedulable_count_by_tid[imeta.tid] += VLEN - 1

        self.split_counts[imeta.opcode()] += 1
        return True


    def __split_one_free_broadcast(self, imeta):
        regs = imeta.registers(self.ss)
        assert imeta.lin.inst[0] == "vbroadcast"
        assert len(regs) == 2

        dest,src = regs[0], regs[1]

        if dest.overlaps(src, self.ss, work_slot_of(imeta.tid, self.conc_threads)):
            return False

        nmetas =  [InstrMeta(
                    instid = imeta.instid
                    , lin = LI(EX_ALU , ('|'
                                   , dest.scalar_at_offset(i)
                                   , src
                                   , src))
                    , tid = imeta.tid
                    , instid_in_thread = imeta.instid_in_thread
                    , after = imeta.after) for i in range(0, VLEN)]

        for idx in imeta.after:
            self.incount[idx] += (VLEN - 1)
        self.free.remove(imeta)
        self.free.extend(nmetas)
        self.schedulable_count_by_tid[imeta.tid] += VLEN - 1

        self.split_counts[imeta.opcode()] += 1
        return True


    def __split_valu_into_alu(self, alu_slots, already_taken_imetas):
        to_split = (alu_slots + VLEN - 1) // VLEN

        so_far = 0
        mul_adds = []
        broadcasts = []
        for imeta in self.free:
            if so_far >= to_split:
                break

            if not (imeta.lin.engine == EX_VALU):
                continue

            if imeta in already_taken_imetas:
                continue

            # Split non multiply-adds preferentially
            opcode = imeta.opcode()
            if opcode == "multiply_add":
                mul_adds.append(imeta)
                continue
            elif opcode == "vbroadcast":
                broadcasts.append(imeta)
                continue
            elif len(imeta.lin.inst[0]) > 5:
                # Only support +, -, ... arithmetic operators for splitting
                # Can't split vbroadcast
                continue
            else:
                if self.__split_one_free_valu_to_alu(imeta):
                    so_far += 1

        for imeta in broadcasts:
            if so_far >= to_split:
                break
            if self.__split_one_free_broadcast(imeta):
                so_far += 1

        for imeta in mul_adds:
            if so_far >= to_split:
                break
            if self.__split_one_free_multiply_add(imeta):
                so_far += 1


    def __split_one_vector_imm_add(self, imeta):
        regs = imeta.registers(self.ss)
        assert len(regs) == 3, f"Length of valu instruction expected to be 3. Was {len(regs)} from {imeta}"
        for i in range(0, 3):
            assert regs[i].is_vector
            # TODO
            if isinstance(regs[i], ArrayOp):
                return
        assert regs[2].is_vector_constant(self.ss), f"Expected imeta to be <vector register+ constant>.\nimeta = {imeta}"
        

        nmetas = [InstrMeta(
                    instid = imeta.instid
                    , lin = LI(EX_FLOW 
                               , ("add_imm"
                                   , regs[0].scalar_at_offset(i)
                                   , regs[1].scalar_at_offset(i)
                                   , regs[2].constant_value(self.ss)))
                    , tid = imeta.tid
                    , instid_in_thread = imeta.instid_in_thread
                    , after = imeta.after) for i in range(0, VLEN)]

#         print("Converting vector imm add", f"imeta = {imeta}", f"nmetas = {len(nmetas)}")
#         print(*["Converted" + nmeta.compact_str() for nmeta in nmetas], sep='\n')

        for idx in imeta.after:
            self.incount[idx] += (VLEN - 1)
        self.free.remove(imeta)
        self.free.extend(nmetas)
        self.schedulable_count_by_tid[imeta.tid] += VLEN - 1


    def __convert_one_scalar_imm_add(self, imeta):
        regs = imeta.registers(self.ss)
        assert len(regs) == 3, f"Length of valu instruction expected to be 3. Was {len(regs)} from {imeta}"
        for i in range(0, 3):
            assert not regs[i].is_vector
        assert regs[2].is_scalar_constant(self.ss), f"Expected imeta to be <scalar register + constant>.\nimeta = {imeta}"


        nmeta = InstrMeta(
                    instid = imeta.instid
                    , lin = LI(EX_FLOW 
                               , ("add_imm"
                                   , regs[0]
                                   , regs[1]
                                   , regs[2].constant_value(self.ss)))
                    , tid = imeta.tid
                    , instid_in_thread = imeta.instid_in_thread
                    , after = imeta.after)

#         print("Converting scalar imm add", f"imeta = {imeta}", f"nmeta = {nmeta}", sep='\n')
        # Note: since nmeta.after == imeta.after and there's only one nmeta, self.incount is unchanged
        self.free.remove(imeta)
        self.free.append(nmeta)



    def __split_add_into_imm(self, flow_slots, already_taken_imetas):
        to_split = (flow_slots + VLEN - 1) // VLEN

        so_far = 0
        for imeta in self.free:
            if so_far >= to_split:
                break

            if imeta in already_taken_imetas:
                continue

            if imeta.is_vector_imm_add(self.ss):
                self.__split_one_vector_imm_add(imeta)
                so_far += 1
                continue

            if imeta.is_scalar_imm_add(self.ss):
                self.__convert_one_scalar_imm_add(imeta)
                so_far += 1
                continue


    def __update_status(self, retired, to_print):
        graphic_update = defaultdict(list)
        summary = defaultdict(int)
        summary[EX_LOAD] = 0
        for dmeta in retired:
            graphic_update[-1 if dmeta.tid == -1 else work_slot_of(dmeta.tid, self.conc_threads)].append(dmeta)
            summary[dmeta.lin.engine] += 1
        self.display.update(graphic_update
                            , summary = str({k:v for k, v in sorted(summary.items())}) + "\n" + ("FINE" if summary.get('valu', 0) == 6 else "UNSATURATED")
                            , datainfos = {k : data_map(k) for k in retired})
        if not to_print:
            return

        def of_engine(engine, R):
            return len([x for x in R if x.lin.engine == engine])

        print(f"------------------------ CYCLE NUMBER {self.cycle_number} -----------------")
        print(*[x.compact_str() for x in retired], sep='\n')
        print()
        print(f"Retired {len(retired)}, Free {len(self.free)}")
        print()
        for engine in EX_UNITS:
            print(f"{engine:>10}: {of_engine(engine, retired):>10} {of_engine(engine, self.free):>10}")
        print()
        print("-" * 200)


    def print(self):
        print('-'*200)
        print(f'ALL INSTRUCTIONS BELOW, {len([x for x in self.imetas if x.tid < 1])}')
        print(*[x.compact_str() for x in self.imetas if x.tid < 1], sep='\n')
        print("\n")
        print(*[x.compact_str() for x in self.imetas if x.tid == self.num_threads - 1], sep='\n')
        pretty_print_map(self.split_counts, message = "VALU SPLIT COUNTS")


    def have_more(self):
        if len(self.free) > 0:
            return True

        if len(self.frontier) > 0:
            self.__fall_down_to_free()
            return len(self.free) > 0

        self.display.render()
        return False


    def take(self) -> dict[str, list[SerializedInstruction]]:
        self.cycle_number += 1
        to_retire = []
        insts = {k:[] for k in EX_UNITS}
        for engine in EX_UNITS:
            full_slots = SLOT_LIMITS[engine]
            cur, done = self.__obtain_for_engine(engine, full_slots)
            rem_slots = full_slots - len(cur)

            if engine == EX_ALU and rem_slots > 0:
                self.__split_valu_into_alu(rem_slots, to_retire)
                cur, done = self.__obtain_for_engine(engine, SLOT_LIMITS[engine])

            if engine == EX_FLOW and rem_slots > 0:
                self.__split_add_into_imm(rem_slots, to_retire)
                cur, done = self.__obtain_for_engine(engine, SLOT_LIMITS[engine])

            insts[engine].extend([x[1] for x in cur])
            to_retire.extend(done)

        for dmeta in to_retire:
            self.__retire(dmeta)

        self.__update_status(to_retire, to_print=False)

        return insts
        

