#define tmp         r0
#define face        r1
#define vp          r2
#define flags       r3
#define polys       r4     // arg
#define count       r5     // arg
#define vp0         r6
#define vp1         r7
#define vp2         r8
#define vp3         r9
#define vg0         r10
#define vg1         r11
#define vg2         r12
#define vg3         r13
#define vertices    r14

#define vx0         vg0
#define vy0         vg1
#define vx1         vg2
#define vy1         vg3
#define vx2         tmp
#define vy2         tmp

#define vz0         vg0
#define vz1         vg1
#define vz2         vg2
#define vz3         vg3

#define depth       vg0     // == vz0
#define next        vg1
#define ot          tmp

.align 4
.global _faceAddMeshQuads_asm
_faceAddMeshQuads_asm:
        // push
        mov.l   r8, @-sp
        mov.l   r9, @-sp
        mov.l   r10, @-sp
        mov.l   r11, @-sp
        mov.l   r12, @-sp
        mov.l   r13, @-sp
        mov.l   r14, @-sp

        mov.l   var_gVertices_fam, vertices

        mov.l   var_gVerticesBase_fam, vp
        mov.l   @vp, vp

        mov.l   var_gFacesBase_fam, face
        mov.l   @face, face

.loop_famq:
        // read flags and indices
        mov.w   @polys+, flags
        mov.b   @polys+, vp0
        mov.b   @polys+, vp1
        mov.b   @polys+, vp2
        mov.b   @polys+, vp3

        extu.w  flags, flags
        extu.b  vp0, vp0
        extu.b  vp1, vp1
        extu.b  vp2, vp2
        extu.b  vp3, vp3

        // p = gVerticesBase + index * VERTEX_SIZEOF
        shll2   vp0
        shll2   vp1
        shll2   vp2
        shll2   vp3
        shll    vp0
        shll    vp1
        shll    vp2
        shll    vp3

        // get vertex address
        add     vp, vp0
        add     vp, vp1
        add     vp, vp2
        add     vp, vp3

        // check_backface
        ccw     vp0, vp1, vp2, vx0, vy0, vx1, vy1, vx2, vy2
        bt/s    .skip_famq
        add     #VERTEX_Z, vp3  // [delay slot] ccw shifts p[0..2] address to VERTEX_Z, shift p3 too

        // fetch clip masks
        mov     #(VERTEX_CLIP - 4), tmp
        mov.b   @(tmp, vp0), vg0
        mov.b   @(tmp, vp1), vg1
        mov.b   @(tmp, vp2), vg2
        mov.b   @(tmp, vp3), vg3

        // check clipping
        mov     vg0, tmp
        and     vg1, tmp
        and     vg2, tmp 
        and     vg3, tmp
        tst     #CLIP_DISCARD, tmp
        bf/s    .skip_famq

        // mark if should be clipped by frame
        mov     vg0, tmp        // [delay slot]
        or      vg1, tmp
        or      vg2, tmp
        or      vg3, tmp
        tst     #CLIP_FRAME, tmp
        bt/s    .avg_z4_famq
        mov.l   const_FACE_CLIPPED_fam, tmp     // [delay slot]
        or      tmp, flags

.avg_z4_famq:
        mov.w   @vp0, vz0
        mov.w   @vp1, vz1
        mov.w   @vp2, vz2
        mov.w   @vp3, vz3
        add     vz1, vz0
        add     vz2, vz0
        add     vz3, vz0
        shlr2   vz0             // div by 4

        mov.l   var_gOT_fam, ot

 .face_add_famq:
        // index = (p - vertices) / VERTEX_SIZEOF
        sub     vertices, vp0
        sub     vertices, vp1
        sub     vertices, vp2
        sub     vertices, vp3
        shlr2   vp0
        shlr2   vp1
        shlr2   vp2
        shlr2   vp3
        shlr    vp0
        shlr    vp1
        shlr    vp2
        shlr    vp3

        // depth (vz0) >>= OT_SHIFT (4)
        shlr2   depth
        shlr2   depth

        shll2   depth
        add     ot, depth   // depth = gOT[depth]
        mov.l   @depth, next
        mov.l   face, @depth

        add     #FACE_SIZEOF, face
        mov     face, tmp

        mov.w   vp3, @-tmp
        mov.w   vp2, @-tmp
        mov.w   vp1, @-tmp
        mov.w   vp0, @-tmp
        mov.l   next, @-tmp
        mov.l   flags, @-tmp
.skip_famq:
        dt      count
        bf      .loop_famq

        mov.l   var_gFacesBase_fam, tmp
        mov.l   face, @tmp

        // pop
        mov.l   @sp+, r14
        mov.l   @sp+, r13
        mov.l   @sp+, r12
        mov.l   @sp+, r11
        mov.l   @sp+, r10
        mov.l   @sp+, r9
        rts
        mov.l   @sp+, r8

#undef tmp
#undef face
#undef vp
#undef flags
#undef polys
#undef count
#undef vp0
#undef vp1
#undef vp2
#undef vp3
#undef vg0
#undef vg1
#undef vg2
#undef vg3
#undef vertices
#undef vx0
#undef vy0
#undef vx1
#undef vy1
#undef vx2
#undef vy2
#undef vz0
#undef vz1
#undef vz2
#undef vz3
#undef depth
#undef next
#undef ot
