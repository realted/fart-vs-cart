; Four independent sphere discriminants, signed 16-bit Q8.8.
; Reset the processor before running. No instruction pipeline: no NOP padding needed.
; oc=O-C, a=D.D, b=2*(oc.D), c=oc.oc-r*r, delta=b*b-4*a*c.
; Data moved to 192..231 so it cannot overlap the program.
; Scratch/results: a 232..235, b 236..239, c 240..243,
; delta 244..247, hit flags 248..251 (Q8.8 1.0 or 0.0).
; Expected a:     0100 0100 0100 0100
; Expected b:     F600 F600 F800 FA00
; Expected c:     1800 2100 0FB0 0C70
; Expected delta: 0400 E000 0140 F240
; Expected flags: 0100 0000 010 0 0000; final mask=0101 (lane0=bit0).
; Final v2 holds delta, v0 holds flags. vcmclr before subsequent unmasked work.
; This tests discriminant >= 0, not roots or nearest positive intersection t.
; For these four inputs a=1 and b<0, so the flagged intersections are forward hits.
; Q8.8 operations truncate and wrap; these inputs avoid overflow.
    vcmclr              
    vsub v2,v2          ; zero accumulator
    sub k1,k1           ; clear address before ORI
    ori 232             
    vstore v2,(k1)      
    sub k1,k1           ; clear address before ORI
    ori 236             
    vstore v2,(k1)      
    sub k1,k1           ; clear address before ORI
    ori 240             
    vstore v2,(k1)      

; X contribution to the three dot products
    sub k1,k1           ; clear address before ORI
    ori 192             
    vload v0,(k1)       
    sub k1,k1           ; clear address before ORI
    ori 204             
    vload v1,(k1)       
    vsub v0,v1          ; oc component
    sub k1,k1           ; clear address before ORI
    ori 216             
    vload v1,(k1)       
    vsub v3,v3          
    vadd v3,v0          
    vmul v3,v0          ; oc component squared
    sub k1,k1           ; clear address before ORI
    ori 240             
    vload v2,(k1)       
    vadd v2,v3          
    sub k1,k1           ; clear address before ORI
    ori 240             
    vstore v2,(k1)      
    vsub v3,v3          
    vadd v3,v1          
    vmul v3,v1          ; D component squared
    sub k1,k1           ; clear address before ORI
    ori 232             
    vload v2,(k1)       
    vadd v2,v3          
    sub k1,k1           ; clear address before ORI
    ori 232             
    vstore v2,(k1)      
    vmul v0,v1          ; oc component * D component
    sub k1,k1           ; clear address before ORI
    ori 236             
    vload v2,(k1)       
    vadd v2,v0          
    sub k1,k1           ; clear address before ORI
    ori 236             
    vstore v2,(k1)      

; Y contribution to the three dot products
    sub k1,k1           ; clear address before ORI
    ori 196             
    vload v0,(k1)       
    sub k1,k1           ; clear address before ORI
    ori 208             
    vload v1,(k1)       
    vsub v0,v1          ; oc component
    sub k1,k1           ; clear address before ORI
    ori 220             
    vload v1,(k1)       
    vsub v3,v3          
    vadd v3,v0          
    vmul v3,v0          ; oc component squared
    sub k1,k1           ; clear address before ORI
    ori 240             
    vload v2,(k1)       
    vadd v2,v3          
    sub k1,k1           ; clear address before ORI
    ori 240             
    vstore v2,(k1)      
    vsub v3,v3          
    vadd v3,v1          
    vmul v3,v1          ; D component squared
    sub k1,k1           ; clear address before ORI
    ori 232             
    vload v2,(k1)       
    vadd v2,v3          
    sub k1,k1           ; clear address before ORI
    ori 232             
    vstore v2,(k1)      
    vmul v0,v1          ; oc component * D component
    sub k1,k1           ; clear address before ORI
    ori 236             
    vload v2,(k1)       
    vadd v2,v0          
    sub k1,k1           ; clear address before ORI
    ori 236             
    vstore v2,(k1)      

; Z contribution to the three dot products
    sub k1,k1           ; clear address before ORI
    ori 200             
    vload v0,(k1)       
    sub k1,k1           ; clear address before ORI
    ori 212             
    vload v1,(k1)       
    vsub v0,v1          ; oc component
    sub k1,k1           ; clear address before ORI
    ori 224             
    vload v1,(k1)       
    vsub v3,v3          
    vadd v3,v0          
    vmul v3,v0          ; oc component squared
    sub k1,k1           ; clear address before ORI
    ori 240             
    vload v2,(k1)       
    vadd v2,v3          
    sub k1,k1           ; clear address before ORI
    ori 240             
    vstore v2,(k1)      
    vsub v3,v3          
    vadd v3,v1          
    vmul v3,v1          ; D component squared
    sub k1,k1           ; clear address before ORI
    ori 232             
    vload v2,(k1)       
    vadd v2,v3          
    sub k1,k1           ; clear address before ORI
    ori 232             
    vstore v2,(k1)      
    vmul v0,v1          ; oc component * D component
    sub k1,k1           ; clear address before ORI
    ori 236             
    vload v2,(k1)       
    vadd v2,v0          
    sub k1,k1           ; clear address before ORI
    ori 236             
    vstore v2,(k1)      

; Finish c and compute 4*a*c
    sub k1,k1           ; clear address before ORI
    ori 228             
    vload v0,(k1)       
    vmul v0,v0          ; r squared
    sub k1,k1           ; clear address before ORI
    ori 240             
    vload v1,(k1)       
    vsub v1,v0          ; c = oc.oc - r*r
    sub k1,k1           ; clear address before ORI
    ori 240             
    vstore v1,(k1)      
    sub k1,k1           ; clear address before ORI
    ori 232             
    vload v0,(k1)       
    vmul v1,v0          ; a*c
    vadd v1,v1          
    vadd v1,v1          ; 4*a*c

; Finish b and compute delta
    sub k1,k1           ; clear address before ORI
    ori 236             
    vload v2,(k1)       
    vadd v2,v2          ; b = 2*oc.D
    sub k1,k1           ; clear address before ORI
    ori 236             
    vstore v2,(k1)      
    vmul v2,v2          ; b squared
    vsub v2,v1          ; delta
    sub k1,k1           ; clear address before ORI
    ori 244             
    vstore v2,(k1)      

; Flags: begin with all ones, then zero just the negative-delta lanes
    sub k1,k1           ; clear address before ORI
    ori 252             
    vload v0,(k1)       
    vsub v3,v3          ; zero comparison vector
    vcmplt v2,v3        ; mask = delta < 0 (miss lanes)
    vmul v0,v3          ; zero flags only where delta is negative
    vcmclr              ; enable all lanes for storing flags
    sub k1,k1           ; clear address before ORI
    ori 248             
    vstore v0,(k1)      
    vcmpgt v0,v3        ; final mask = hit flags > 0
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
