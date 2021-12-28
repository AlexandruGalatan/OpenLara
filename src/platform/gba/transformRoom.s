#include "common_asm.inc"

vertices    .req r0
count       .req r1
underwater  .req r2
v           .req r3
vx          .req r4
vy          .req r5
vz          .req r6
vg          .req v
mx          .req r7
my          .req r8
mz          .req r9
x           .req r10
y           .req r11
z           .req r12
res         .req lr
t           .req y

spMat       .req x
spMinXY     .req y
spMaxXY     .req z

m           .req underwater
mask        .req x
vp          .req vx
minXY       .req vx
maxXY       .req vy

DIVLUT      .req my
dz          .req mz
fog         .req mz

SP_MAT      = 0
SP_MINXY    = 4
SP_MAXXY    = 8
SP_SIZE     = 12

.global transformRoom_asm
transformRoom_asm:
    stmfd sp!, {r4-r11, lr}

    ldr res, =gVerticesBase
    ldr res, [res]

    ldr spMat, =matrixPtr
    ldr spMat, [spMat]
    add spMat, #(12 * 4)

    ldr vp, =viewportRel
    ldmia vp, {spMinXY, spMaxXY}

    stmfd sp!, {spMat, spMinXY, spMaxXY}

    // preload matrix, mask and z-row
    mov m, spMat
    mov mask, #(0xFF << 10)
    ldmdb m!, {mx, my, mz, z}

.loop:
    // unpack vertex
    ldmia vertices!, {v}

    and vz, mask, v, lsr #6
    and vy, v, #0xFF00
    and vx, mask, v, lsl #10

    // transform z
    mla t, mx, vx, z
    mla t, my, vy, t
    mla t, mz, vz, t
    mov t, t, asr #FIXED_SHIFT

    // skip if vertex is out of z-range
    add t, t, #VIEW_OFF
    cmp t, #(VIEW_OFF + VIEW_OFF + VIEW_MAX)
    movhi vg, #(CLIP_NEAR + CLIP_FAR)
    bhi .skip

    and vg, mask, v, lsr #14
    sub z, t, #VIEW_OFF

    // transform y
    ldmdb m!, {mx, my, mz, y}
    mla y, mx, vx, y
    mla y, my, vy, y
    mla y, mz, vz, y
    mov y, y, asr #(FIXED_SHIFT - PROJ_SHIFT)

    // transform x
    ldmdb m!, {mx, my, mz, x}
    mla x, mx, vx, x
    mla x, my, vy, x
    mla x, mz, vz, x
    mov x, x, asr #FIXED_SHIFT

    // TODO caustics

    // fog
    cmp z, #FOG_MIN
    subgt fog, z, #FOG_MIN
    addgt vg, fog, lsl #6
    mov vg, vg, lsr #13
    cmp vg, #31
    movgt vg, #31

    // z clipping
    cmp z, #VIEW_MIN
    movle z, #VIEW_MIN
    orrle vg, vg, #CLIP_NEAR
    cmp z, #VIEW_MAX
    movge z, #VIEW_MAX
    orrge vg, vg, #CLIP_FAR

    // project
    mov dz, z, lsr #6
    add dz, dz, z, lsr #4
    mov dz, dz, lsl #1
    mov DIVLUT, #DIVLUT_ADDR
    ldrh dz, [DIVLUT, dz]
    mul x, dz, x
    mul y, dz, y
    mov x, x, asr #(16 - PROJ_SHIFT)
    // keep y shifted by 16 for min/max cmp

    // viewport clipping
    ldmia sp, {m, minXY, maxXY} // preload matrix

    cmp x, minXY, asr #16
    orrle vg, vg, #CLIP_LEFT
    cmp y, minXY, lsl #16
    orrle vg, vg, #CLIP_TOP
    cmp x, maxXY, asr #16
    orrge vg, vg, #CLIP_RIGHT
    cmp y, maxXY, lsl #16
    orrge vg, vg, #CLIP_BOTTOM

    mov y, y, asr #16 

    add x, x, #(FRAME_WIDTH >> 1)
    add y, y, #(FRAME_HEIGHT >> 1)

    // store the result
    strh x, [res, #VERTEX_X]
    strh y, [res, #VERTEX_Y]
    strh z, [res, #VERTEX_Z]

    mov mask, #(0xFF << 10)     // preload mask
    ldmdb m!, {mx, my, mz, z}   // preload z-row

.skip:
    strh vg, [res, #VERTEX_G]
    
    add res, #8
    subs count, #1
    bne .loop

    add sp, sp, #SP_SIZE
    ldmfd sp!, {r4-r11, pc}
