/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#include "mcu/mcu.h"
#include "os/os_arch_defs.h"
#include "syscfg/syscfg.h"

#define OS_STACK_ALIGNMENT  (8)

#define CTX_ALIGNED_SIZE ((((CTX_SIZE - 1) / OS_STACK_ALIGNMENT) + 1) * \
    OS_STACK_ALIGNMENT)
#define CTX_OFFS(r) (((r) * 4))

#if (__mips_isa_rev < 6)
    #define CTX_SIZE (36 * 4)
    #define CTX_LO CTX_OFFS(34)
    #define CTX_HI CTX_OFFS(35)
#else
    #define CTX_SIZE (34 * 4)
#endif

# relative to the stack pointer
#define CTX_REG(r) CTX_OFFS((r) - 1)
#define CTX_EPC CTX_OFFS(30)
#define CTX_BADVADDR CTX_OFFS(31)
#define CTX_STATUS CTX_OFFS(32)
#define CTX_CAUSE CTX_OFFS(33)

.macro _gpctx_save
    .set push
    # at already pushed
    sw      v0, CTX_REG(2)(sp)
    sw      v1, CTX_REG(3)(sp)
    sw      a0, CTX_REG(4)(sp)
    sw      a1, CTX_REG(5)(sp)
    sw      a2, CTX_REG(6)(sp)
    sw      a3, CTX_REG(7)(sp)
    sw      t0, CTX_REG(8)(sp)
    sw      t1, CTX_REG(9)(sp)
    sw      t2, CTX_REG(10)(sp)
    sw      t3, CTX_REG(11)(sp)
    sw      t4, CTX_REG(12)(sp)
    sw      t5, CTX_REG(13)(sp)
    sw      t6, CTX_REG(14)(sp)
    sw      t7, CTX_REG(15)(sp)
    sw      s0, CTX_REG(16)(sp)
    sw      s1, CTX_REG(17)(sp)
    sw      s2, CTX_REG(18)(sp)
    sw      s3, CTX_REG(19)(sp)
    sw      s4, CTX_REG(20)(sp)
    sw      s5, CTX_REG(21)(sp)
    sw      s6, CTX_REG(22)(sp)
    sw      s7, CTX_REG(23)(sp)
    sw      t8, CTX_REG(24)(sp)
    sw      t9, CTX_REG(25)(sp)
    # k0 already pushed
    # k1 already pushed
    sw      gp, CTX_REG(28)(sp)
    # save ra in place on sp
    sw      ra, CTX_REG(29)(sp)
    sw      fp, CTX_REG(30)(sp)

#if (__mips_isa_rev < 6)
    mfhi    k0
    sw      k0, CTX_HI(sp)
    mflo    k0
    sw      k0, CTX_LO(sp)
#endif

    # cp0
    mfc0    k0, _CP0_EPC
    sw      k0, CTX_EPC(sp)
    mfc0    k0, _CP0_BADVADDR
    sw      k0, CTX_BADVADDR(sp)
    mfc0    k0, _CP0_CAUSE
    sw      k0, CTX_CAUSE(sp)

    mfc0    k0, _CP0_STATUS
    # disable co-precessor 1 on return from context switch
    ins     k0, $0, _CP0_STATUS_CU1_POSITION, _CP0_STATUS_CU1_LENGTH
    sw      k0, CTX_STATUS(sp)
    # enable interrupts with higher priority
    ins     k0, $0, _CP0_STATUS_EXL_POSITION, _CP0_STATUS_EXL_LENGTH
    ori     k0, k0, 1 << _CP0_STATUS_IPL_POSITION
    mtc0    k0, _CP0_STATUS
    .set pop
.endm

.macro _gpctx_load
    .set push
    .set noat
    # at restored at the end of contex switch
    lw     v0, CTX_REG(2)(sp)
    lw     v1, CTX_REG(3)(sp)
    lw     a0, CTX_REG(4)(sp)
    lw     a1, CTX_REG(5)(sp)
    lw     a2, CTX_REG(6)(sp)
    lw     a3, CTX_REG(7)(sp)
    lw     t0, CTX_REG(8)(sp)
    lw     t1, CTX_REG(9)(sp)
    lw     t2, CTX_REG(10)(sp)
    lw     t3, CTX_REG(11)(sp)
    lw     t4, CTX_REG(12)(sp)
    lw     t5, CTX_REG(13)(sp)
    lw     t6, CTX_REG(14)(sp)
    lw     t7, CTX_REG(15)(sp)
    lw     s0, CTX_REG(16)(sp)
    lw     s1, CTX_REG(17)(sp)
    lw     s2, CTX_REG(18)(sp)
    lw     s3, CTX_REG(19)(sp)
    lw     s4, CTX_REG(20)(sp)
    lw     s5, CTX_REG(21)(sp)
    lw     s6, CTX_REG(22)(sp)
    lw     s7, CTX_REG(23)(sp)
    lw     t8, CTX_REG(24)(sp)
    lw     t9, CTX_REG(25)(sp)
    # restore k0 later
    # restore k1 later
    lw     gp, CTX_REG(28)(sp)
    # sp already restored ra in place of sp
    lw     ra, CTX_REG(29)(sp)
    lw     fp, CTX_REG(30)(sp)

    di

#if (__mips_isa_rev < 6)
    lw      k0, CTX_HI(sp)
    mthi    k0
    lw      k0, CTX_LO(sp)
    mtlo    k0
#endif

    # cp0
    lw      k0, CTX_EPC(sp)
    mtc0    k0, _CP0_EPC
    # STATUS here will have EXL set and EI cleared
    lw      k0, CTX_STATUS(sp)
    mtc0    k0, _CP0_STATUS
    ehb
    .set pop
.endm

#if MYNEWT_VAL(HARDFLOAT)

#define CTX_FP_SIZE (33 * 4)
#define CTX_FP_ALIGNED_SIZE ((((CTX_FP_SIZE - 1) / OS_STACK_ALIGNMENT) + 1) * \
    OS_STACK_ALIGNMENT)
#define CTX_FP_OFFS(r) (((r) * 4) - CTX_FP_ALIGNED_SIZE)
#define CTX_FP_REG(r) CTX_FP_OFFS(r)
#define CTX_FP64_REG(r) CTX_FP_OFFS(r)
#define CTX_FP_FCSR CTX_FP_OFFS(32)

#define TASK_STACK_BOTTOM   (4)
#define TASK_STACK_SIZE     (8)

.macro _fpctx_save
    sdc1    $f0, CTX_FP_REG(0)(k0)
    sdc1    $f2, CTX_FP_REG(2)(k0)
    sdc1    $f4, CTX_FP_REG(4)(k0)
    sdc1    $f6, CTX_FP_REG(6)(k0)
    sdc1    $f8, CTX_FP_REG(8)(k0)
    sdc1    $f10, CTX_FP_REG(10)(k0)
    sdc1    $f12, CTX_FP_REG(12)(k0)
    sdc1    $f14, CTX_FP_REG(14)(k0)
    sdc1    $f16, CTX_FP_REG(16)(k0)
    sdc1    $f18, CTX_FP_REG(18)(k0)
    sdc1    $f20, CTX_FP_REG(20)(k0)
    sdc1    $f22, CTX_FP_REG(22)(k0)
    sdc1    $f24, CTX_FP_REG(24)(k0)
    sdc1    $f26, CTX_FP_REG(26)(k0)
    sdc1    $f28, CTX_FP_REG(28)(k0)
    sdc1    $f30, CTX_FP_REG(30)(k0)
    cfc1    k1, $31
    sw      k1, CTX_FP_FCSR(k0)
.endm

.macro _fpctx_load
    ldc1    $f0, CTX_FP_REG(0)(k0)
    ldc1    $f2, CTX_FP_REG(2)(k0)
    ldc1    $f4, CTX_FP_REG(4)(k0)
    ldc1    $f6, CTX_FP_REG(6)(k0)
    ldc1    $f8, CTX_FP_REG(8)(k0)
    ldc1    $f10, CTX_FP_REG(10)(k0)
    ldc1    $f12, CTX_FP_REG(12)(k0)
    ldc1    $f14, CTX_FP_REG(14)(k0)
    ldc1    $f16, CTX_FP_REG(16)(k0)
    ldc1    $f18, CTX_FP_REG(18)(k0)
    ldc1    $f20, CTX_FP_REG(20)(k0)
    ldc1    $f22, CTX_FP_REG(22)(k0)
    ldc1    $f24, CTX_FP_REG(24)(k0)
    ldc1    $f26, CTX_FP_REG(26)(k0)
    ldc1    $f28, CTX_FP_REG(28)(k0)
    ldc1    $f30, CTX_FP_REG(30)(k0)
    lw      k0, CTX_FP_FCSR(k0)
    ctc1    k0, $31
.endm
#endif

.text
.global get_global_pointer
.ent get_global_pointer
get_global_pointer:
    move   v0, gp
    jr     ra
.end get_global_pointer

.text
.set noat
.set nomips16
.globl _general_exception_context
.ent _general_exception_context
_general_exception_context:
#if MYNEWT_VAL(HARDFLOAT)
    mfc0    k0, _CP0_CAUSE
    ext     k0, k0, 2, 5                # set k0 to the ExcCode field of cause
    li      k1, 0x0b
    bne     k0, k1, loop

    # enable co-precessor 1
    mfc0    k0, _CP0_STATUS
    li      k1, _CP0_STATUS_CU1_MASK
    or      k0, k0, k1
    mtc0    k0, _CP0_STATUS

    lw      k1, g_current_task          # get current task
    lw      k0, g_fpu_user              # get current FPU user
    beq     k0, k1, return              # if current task owns FPU context then just return

    # Save FPU context to FPU user
    beqz    k0, load                    # if there is an FPU user
    lhu     k1, TASK_STACK_SIZE(k0)     # k1 = stack size in words
    sll     k1, k1, 2                   # k1 = stack size in bytes
    lw      k0, TASK_STACK_BOTTOM(k0)   # k0 = stack bottom
    add     k0, k1, k0                  # k0 = FPU user stack top
    _fpctx_save
    lw      k1, g_current_task          # get current task

load:
    # Load FPU context from current task
    beqz    k1, return                  # if there is a current task
    la      k0, g_fpu_user
    sw      k1, 0(k0)                   # set FPU user to current task
    lhu     k0, TASK_STACK_SIZE(k1)     # k0 = stack size in words
    sll     k0, k0, 2                   # k0 = stack size in bytes
    lw      k1, TASK_STACK_BOTTOM(k1)   # k1 = stack bottom
    add     k0, k1, k0                  # k0 = current task stack top
    _fpctx_load

return :
    eret
#endif

loop:
    b       loop                        # loop (default for general exception handler)
.end _general_exception_context

.text
.global isr_sw0
.ent isr_sw0
isr_sw0:
    .set noat

    addiu   sp, sp, -(CTX_SIZE)
    # context switch
    sw      k0, CTX_REG(26)(sp)
    sw      k1, CTX_REG(27)(sp)
    sw      $1, CTX_REG(1)(sp)
    .set at

    li      k0, _IFS0_CS0IF_MASK        # clear sw interrupt
    sw      k0, IFS0CLR

    lw      k0, g_current_task          # get current task
    lw      k1, g_os_run_list           # get high prio task to k1
    beq     k0, k1, same_task_no_switch
    beqz    k0, no_save_needed          # no current task so far
    sw      sp, 0(k0)                   # update stored sp
    _gpctx_save

    .set at
no_save_needed:

    sw      k1, g_current_task          # g_current_task = g_os_run_list

    lw      sp, 0(k1)                   # restore sp
    .set noat
    _gpctx_load                         # load the context
same_task_no_switch:
    lw      $1, CTX_REG(1)(sp)
    lw      k0, CTX_REG(26)(sp)
    lw      k1, CTX_REG(27)(sp)
    addiu   sp, sp, CTX_SIZE

    eret
.end isr_sw0
