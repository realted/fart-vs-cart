; LI-optimized copy of test3_8vreg.s: 16 scalar SUB/ORI pairs become LI.
; LI preserves scalar flags; this program does not branch on those flags.
; Eight-vector-register version of test2_ray_tracer_determinant.s.
; Four sphere discriminants, signed 16-bit Q8.8. Reset before running.
; v0: oc component, then hit flags; v1: C/D component, then r squared.
; v2: product scratch, then 4*a*c; v3: zero comparison vector.
; v4: a = D.D; v5: b = 2*oc.D; v6: c = oc.oc-r*r; v7: delta.
; Accumulators remain in registers instead of repeated memory reloads.
; Input data and result addresses match test2; all eight registers are used.
; Results (lanes 0,1,2,3):
; 232..235 a:     0100 0100 0100 0100
; 236..239 b:     F600 F600 F800 FA00
; 240..243 c:     1800 2100 0FB0 0C70
; 244..247 delta: 0400 E000 0140 F240
; 248..251 flags: 0100 0000 0100 0000
; Final mask = 0101; final v7 holds delta and v0 holds flags.
; This tests delta >= 0, not roots or the nearest positive intersection.
; These inputs avoid overflow; multiplication truncates to Q8.8.
    vcmclr
    vsub v3,v3          ; zero vector
    vsub v4,v4          ; accumulate a
    vsub v5,v5          ; accumulate oc.D
    vsub v6,v6          ; accumulate oc.oc

; X contribution
    li k1,192
    vload v0,(k1)
    li k1,204
    vload v1,(k1)
    vsub v0,v1          ; oc component = O-C
    li k1,216
    vload v1,(k1)       ; D component
    vsub v2,v2
    vadd v2,v0
    vmul v2,v0
    vadd v6,v2          ; oc.oc += oc_component squared
    vsub v2,v2
    vadd v2,v1
    vmul v2,v1
    vadd v4,v2          ; a += D_component squared
    vmul v0,v1
    vadd v5,v0          ; oc.D += oc_component * D_component

; Y contribution
    li k1,196
    vload v0,(k1)
    li k1,208
    vload v1,(k1)
    vsub v0,v1          ; oc component = O-C
    li k1,220
    vload v1,(k1)       ; D component
    vsub v2,v2
    vadd v2,v0
    vmul v2,v0
    vadd v6,v2          ; oc.oc += oc_component squared
    vsub v2,v2
    vadd v2,v1
    vmul v2,v1
    vadd v4,v2          ; a += D_component squared
    vmul v0,v1
    vadd v5,v0          ; oc.D += oc_component * D_component

; Z contribution
    li k1,200
    vload v0,(k1)
    li k1,212
    vload v1,(k1)
    vsub v0,v1          ; oc component = O-C
    li k1,224
    vload v1,(k1)       ; D component
    vsub v2,v2
    vadd v2,v0
    vmul v2,v0
    vadd v6,v2          ; oc.oc += oc_component squared
    vsub v2,v2
    vadd v2,v1
    vmul v2,v1
    vadd v4,v2          ; a += D_component squared
    vmul v0,v1
    vadd v5,v0          ; oc.D += oc_component * D_component

; Finish b and c while preserving a, b, c for inspection.
    vadd v5,v5
    li k1,228
    vload v1,(k1)
    vmul v1,v1
    vsub v6,v1          ; c = oc.oc-r*r
    vsub v2,v2
    vadd v2,v4
    vmul v2,v6
    vadd v2,v2
    vadd v2,v2          ; 4*a*c
    vsub v7,v7
    vadd v7,v5
    vmul v7,v5
    vsub v7,v2          ; delta = b*b-4*a*c

; Store results at the same addresses as test2.
    li k1,232
    vstore v4,(k1)
    li k1,236
    vstore v5,(k1)
    li k1,240
    vstore v6,(k1)
    li k1,244
    vstore v7,(k1)

; Ones become zeros only in lanes with negative delta.
    li k1,252
    vload v0,(k1)
    vcmplt v7,v3
    vmul v0,v3
    vcmclr
    li k1,248
    vstore v0,(k1)
    vcmpgt v0,v3        ; final hit mask = 0101
    stop

; ox lanes 0..3
    org 192             
ox0    db $0000
ox1    db $0000
ox2    db $0100
ox3    db $FF00

; oy lanes 0..3
    org 196             
oy0    db $0000
oy1    db $0000
oy2    db $0100
oy3    db $0000

; oz lanes 0..3
    org 200             
oz0    db $FB00
oz1    db $FB00
oz2    db $FC00
oz3    db $FD00

; cx lanes 0..3
    org 204             
cx0    db $0000
cx1    db $0300
cx2    db $0180
cx3    db $0100

; cy lanes 0..3
    org 208             
cy0    db $0000
cy1    db $0000
cy2    db $0100
cy3    db $0100

; cz lanes 0..3
    org 212             
cz0    db $0000
cz1    db $0000
cz2    db $0000
cz3    db $0000

; dx lanes 0..3
    org 216             
dx0    db $0000
dx1    db $0000
dx2    db $0000
dx3    db $0000

; dy lanes 0..3
    org 220             
dy0    db $0000
dy1    db $0000
dy2    db $0000
dy3    db $0000

; dz lanes 0..3
    org 224             
dz0    db $0100
dz1    db $0100
dz2    db $0100
dz3    db $0100

; radius lanes 0..3
    org 228             
radius0    db $0100
radius1    db $0100
radius2    db $00C0
radius3    db $0140

; ones lanes 0..3
    org 252             
ones0    db $0100
ones1    db $0100
ones2    db $0100
ones3    db $0100

