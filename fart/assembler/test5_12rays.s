; test5: three groups of four ray/sphere pairs (12 rays), signed Q8.8.
; Same discriminant calculation as test4_8vreg_li.s, with one BNZ group loop.
; Layout: group bases 128,168,208; 40 words per group, four lanes per vector.
; Offsets: 0 Ox, 4 Cx, 8 Dx, 12 Oy, 16 Cy, 20 Dy, 24 Oz, 28 Cz,
;          32 Dz, 36 radius. Each lane is an independent ray/sphere pair.
; All vectors are bank-aligned. A cursor streams inputs in calculation order.
; After all inputs are consumed, overwrite offsets 0,4,8,12,16 with a,b,c,
; delta,hit flags. This saves 60 additional result words in the 256-word image.
; Reload the data image before rerunning: reset alone does not restore inputs.
; Shared Q8.8 ones at 252..255. Code stays below input address 128.
; k0 = group base, k1 = cursor, k2 = stride/temporary, k3 = groups remaining.
; v0 = oc/flags, v1 = center/direction/radius, v2 = scratch, v3 = zero,
; v4 = a, v5 = b, v6 = c, v7 = delta. No accumulator spills.
; Tangency counts as a hit (delta >= 0); roots/positive t are not tested.
; Group 0 reproduces test4. Groups 1/2 use +X and +/-Y directions.
; Expected results, lanes 0..3 (hex):
; Group 0 128..131 a    : 0100 0100 0100 0100
; Group 0 132..135 b    : F600 F600 F800 FA00
; Group 0 136..139 c    : 1800 2100 0FB0 0C70
; Group 0 140..143 delta: 0400 E000 0140 F240
; Group 0 144..147 flags: 0100 0000 0100 0000
; Group 1 168..171 a    : 0100 0100 0100 0100
; Group 1 172..175 b    : FA00 F800 FC00 F600
; Group 1 176..179 c    : 0800 1000 0700 1840
; Group 1 180..183 delta: 0400 0000 F400 0300
; Group 1 184..187 flags: 0100 0100 0000 0100
; Group 2 208..211 a    : 0100 0100 0100 0100
; Group 2 212..215 b    : FC00 FA00 F800 FC00
; Group 2 216..219 c    : 03C0 0A40 1000 0380
; Group 2 220..223 delta: 0100 FB00 0000 0200
; Group 2 224..227 flags: 0100 0000 0100 0100

    vcmclr
    vsub v3,v3
    li k0,128
    li k3,3
group_loop    li k2,4
    li k1,0
    add k1,k0
    vsub v4,v4
    vsub v5,v5
    vsub v6,v6

; X contribution: stream O, C, D vectors.
    vload v0,(k1)
    add k1,k2
    vload v1,(k1)
    add k1,k2
    vsub v0,v1
    vload v1,(k1)
    add k1,k2
    vsub v2,v2
    vadd v2,v0
    vmul v2,v0
    vadd v6,v2
    vsub v2,v2
    vadd v2,v1
    vmul v2,v1
    vadd v4,v2
    vmul v0,v1
    vadd v5,v0

; Y contribution: stream O, C, D vectors.
    vload v0,(k1)
    add k1,k2
    vload v1,(k1)
    add k1,k2
    vsub v0,v1
    vload v1,(k1)
    add k1,k2
    vsub v2,v2
    vadd v2,v0
    vmul v2,v0
    vadd v6,v2
    vsub v2,v2
    vadd v2,v1
    vmul v2,v1
    vadd v4,v2
    vmul v0,v1
    vadd v5,v0

; Z contribution: stream O, C, D vectors.
    vload v0,(k1)
    add k1,k2
    vload v1,(k1)
    add k1,k2
    vsub v0,v1
    vload v1,(k1)
    add k1,k2
    vsub v2,v2
    vadd v2,v0
    vmul v2,v0
    vadd v6,v2
    vsub v2,v2
    vadd v2,v1
    vmul v2,v1
    vadd v4,v2
    vmul v0,v1
    vadd v5,v0

; Cursor now points to radius; every input is read before storing.
    vadd v5,v5
    vload v1,(k1)
    vmul v1,v1
    vsub v6,v1
    vsub v2,v2
    vadd v2,v4
    vmul v2,v6
    vadd v2,v2
    vadd v2,v2
    vsub v7,v7
    vadd v7,v5
    vmul v7,v5
    vsub v7,v2

; Store a,b,c,delta into the consumed group.
    li k1,0
    add k1,k0
    vstore v4,(k1)
    add k1,k2
    vstore v5,(k1)
    add k1,k2
    vstore v6,(k1)
    add k1,k2
    vstore v7,(k1)
    add k1,k2

; k1 points to flags. Clear negative lanes, then restore ALL lanes.
    li k2,252
    vload v0,(k2)
    vcmplt v7,v3
    vmul v0,v3
    vcmclr
    vstore v0,(k1)

; Advance by one packed group. SUB must immediately feed BNZ.
    li k2,40
    add k0,k2
    li k2,1
    sub k3,k2
    bnz group_loop
    vcmpgt v0,v3        ; final group hit mask = 1101
    stop

    org 128
; Group 0: ox lanes 0..3
g0_ox0    db $0000
g0_ox1    db $0000
g0_ox2    db $0100
g0_ox3    db $FF00
; Group 0: cx lanes 0..3
g0_cx0    db $0000
g0_cx1    db $0300
g0_cx2    db $0180
g0_cx3    db $0100
; Group 0: dx lanes 0..3
g0_dx0    db $0000
g0_dx1    db $0000
g0_dx2    db $0000
g0_dx3    db $0000
; Group 0: oy lanes 0..3
g0_oy0    db $0000
g0_oy1    db $0000
g0_oy2    db $0100
g0_oy3    db $0000
; Group 0: cy lanes 0..3
g0_cy0    db $0000
g0_cy1    db $0000
g0_cy2    db $0100
g0_cy3    db $0100
; Group 0: dy lanes 0..3
g0_dy0    db $0000
g0_dy1    db $0000
g0_dy2    db $0000
g0_dy3    db $0000
; Group 0: oz lanes 0..3
g0_oz0    db $FB00
g0_oz1    db $FB00
g0_oz2    db $FC00
g0_oz3    db $FD00
; Group 0: cz lanes 0..3
g0_cz0    db $0000
g0_cz1    db $0000
g0_cz2    db $0000
g0_cz3    db $0000
; Group 0: dz lanes 0..3
g0_dz0    db $0100
g0_dz1    db $0100
g0_dz2    db $0100
g0_dz3    db $0100
; Group 0: radius lanes 0..3
g0_radius0    db $0100
g0_radius1    db $0100
g0_radius2    db $00C0
g0_radius3    db $0140

    org 168
; Group 1: ox lanes 0..3
g1_ox0    db $FD00
g1_ox1    db $FC00
g1_ox2    db $FE00
g1_ox3    db $FB00
; Group 1: cx lanes 0..3
g1_cx0    db $0000
g1_cx1    db $0000
g1_cx2    db $0000
g1_cx3    db $0000
; Group 1: dx lanes 0..3
g1_dx0    db $0100
g1_dx1    db $0100
g1_dx2    db $0100
g1_dx3    db $0100
; Group 1: oy lanes 0..3
g1_oy0    db $0000
g1_oy1    db $0100
g1_oy2    db $0200
g1_oy3    db $0080
; Group 1: cy lanes 0..3
g1_cy0    db $0000
g1_cy1    db $0000
g1_cy2    db $0000
g1_cy3    db $0000
; Group 1: dy lanes 0..3
g1_dy0    db $0000
g1_dy1    db $0000
g1_dy2    db $0000
g1_dy3    db $0000
; Group 1: oz lanes 0..3
g1_oz0    db $0000
g1_oz1    db $0000
g1_oz2    db $0000
g1_oz3    db $0000
; Group 1: cz lanes 0..3
g1_cz0    db $0000
g1_cz1    db $0000
g1_cz2    db $0000
g1_cz3    db $0000
; Group 1: dz lanes 0..3
g1_dz0    db $0000
g1_dz1    db $0000
g1_dz2    db $0000
g1_dz3    db $0000
; Group 1: radius lanes 0..3
g1_radius0    db $0100
g1_radius1    db $0100
g1_radius2    db $0100
g1_radius3    db $0100

    org 208
; Group 2: ox lanes 0..3
g2_ox0    db $0000
g2_ox1    db $0180
g2_ox2    db $0100
g2_ox3    db $0080
; Group 2: cx lanes 0..3
g2_cx0    db $0000
g2_cx1    db $0000
g2_cx2    db $0000
g2_cx3    db $0000
; Group 2: dx lanes 0..3
g2_dx0    db $0000
g2_dx1    db $0000
g2_dx2    db $0000
g2_dx3    db $0000
; Group 2: oy lanes 0..3
g2_oy0    db $FE00
g2_oy1    db $FD00
g2_oy2    db $FC00
g2_oy3    db $0200
; Group 2: cy lanes 0..3
g2_cy0    db $0000
g2_cy1    db $0000
g2_cy2    db $0000
g2_cy3    db $0000
; Group 2: dy lanes 0..3
g2_dy0    db $0100
g2_dy1    db $0100
g2_dy2    db $0100
g2_dy3    db $FF00
; Group 2: oz lanes 0..3
g2_oz0    db $0000
g2_oz1    db $0000
g2_oz2    db $0000
g2_oz3    db $0080
; Group 2: cz lanes 0..3
g2_cz0    db $0000
g2_cz1    db $0000
g2_cz2    db $0000
g2_cz3    db $0000
; Group 2: dz lanes 0..3
g2_dz0    db $0000
g2_dz1    db $0000
g2_dz2    db $0000
g2_dz3    db $0000
; Group 2: radius lanes 0..3
g2_radius0    db $0080
g2_radius1    db $0100
g2_radius2    db $0100
g2_radius3    db $0100

    org 252
ones0    db $0100
ones1    db $0100
ones2    db $0100
ones3    db $0100
