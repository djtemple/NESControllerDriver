.section    .init
.globl     _start

_start:
    b       main
    
.section .text

main:
    mov     sp, #0x8000 // Initializing the stack pointer
	bl		EnableJTAG // Enable JTAG
	bl		InitUART

    mov r0, #9      //Moves GPIO Line Number
    mov r1, #1      //Moves Function Number(Output)
    bl Init_GPIO    // Call the routine


    mov r0, #10     //Moves GPIO Line Number
    mov r1, #0      //Moves Function Number(Input)
    bl Init_GPIO    // Call the routine
    
    mov r0, #11     //Moves GPIO Line Number
    mov r1, #1      //Moves Function Number(Output)
    bl Init_GPIO    // Call the routine

	ldr	r0, =creatorName    //Prints Creator Name
	mov	r1, #16
	bl	WriteStringUART



promptLoop:
    ldr r0, =pressButton
    mov r1, #28
    bl  WriteStringUART

    buttonLoop:
        bl  Read_SNES
        mov r4, r0

        ldr r5, =0xffff
        cmp r4, r5
        mov r9, r0
        beq buttonLoop

    // Process r4 (Buttons register)


    bl Print_Message

    ldr r0, =0x493EA    // Wait an arbitrary amount of microseconds before continuing 
    bl  Wait


    b   promptLoop

haltLoop$:
	b	haltLoop$


Read_Data:
    push	{lr}
    mov r0, #10 // pin#10 = DATA line
    ldr r2, =0x20200000 // base GPIO reg
    ldr r1, [r2, #52] // GPLEV0
    mov r3, #1
    lsl r3, r0 // align pin10 bit
    and r1, r3 // mask everything else
    teq r1, #0
    moveq r0, #0 // return 0
    movne r0, #1 // return 1

	pop		{lr}
    bx      lr

Wait:
    push	{r4, lr}
    mov     r4, r0

    ldr r0, =0x20003004 // address of CLO
    ldr r1, [r0] // read CLO
    add r1, r4 // add r4 micro seconds to r1
    waitLoop:
        ldr r2, [r0]
        cmp r1, r2 // stop when CLO = r1
        bhi waitLoop

    pop     {r4, lr}
    bx      lr

Write_Latch:
    push	{r4, lr}
    mov r4, r0

    mov r0, #9 // pin#9 = LATCH line
    ldr r2, =0x20200000 // base GPIO reg
    mov r3, #1
    lsl r3, r0 // align bit for pin#9
    teq r4, #0
    streq r3, [r2, #40] // GPCLR0
    strne r3, [r2, #28] // GPSET0

    pop     {r4, lr}
    bx      lr

Write_Clock:
    push	{r4, lr}
    mov r4, r0

    mov r0, #11 // pin#11 = CLOCK line
    ldr r2, =0x20200000 // base GPIO reg
    mov r3, #1
    lsl r3, r0 // align bit for pin#9
    teq r4, #0
    streq r3, [r2, #40] // GPCLR0
    strne r3, [r2, #28] // GPSET0

    pop     {r4, lr}
    bx      lr 

Init_GPIO:
    push     {r4,r5, lr}    // Preserve registers and lr
    
    mov r4, r0
    mov r5, r1
    
    cmp r4, #9
    beq initLatch

    cmp r4, #10
    beq initData
    
    cmp r4, #11
    beq initClock

    initLatch:
        ldr r0, =0x20200000 // address for GPFSEL0
        ldr r1, [r0]        // copy GPFSEL1 into r1
        mov r2, #7          // (b0111)
   
        lsl r2, #27         // index of 1st  bit for pin11   // r2 = 0 111 000
        bic r1, r2          // clear pin11 bits
        mov r3 , r5         // function code passsed in as a parameter
        lsl r3, #27         // r3 = 0 001 000
        orr r1, r3          // set pin function in r1
        str r1, [r0]        // write back to GPFSEL1    
    pop    {r4, r5, lr}
    bx      lr

    initClock:
        ldr r0, =0x20200004 // address for GPFSEL1
        ldr r1, [r0]    // copy GPFSEL1 into r1
        mov r2, #7  // (b0111)
        lsl r2, #3  // index of 1st  bit for pin11   // r2 = 0 111 000
        bic r1, r2  // clear pin11 bits
        mov r3 , r5     // function code passsed in as a parameter
        lsl r3, #3  // r3 = 0 001 000
        orr r1, r3  // set pin function in r1
        str r1, [r0]    // write back to GPFSEL1    
    pop    {r4, r5, lr}
    bx      lr

    initData:
        ldr r0, =0x20200004 // address for GPFSEL1
        ldr r1, [r0]    // copy GPFSEL1 into r1
        mov r2, #7  // (b0111)
        bic r1, r2  // clear pin11 bits
        mov r3 , r5     // function code passsed in as a parameter
        orr r1, r3  // set pin function in r1
        str r1, [r0]    // write back to GPFSEL1    
    pop    {r4, r5, lr}
    bx      lr

Read_SNES:
    push    {r4-r6, lr} // preserve r4-r6 and lr
    mov     r4, #0
      
    mov r0, #1
    bl  Write_Clock
    mov r0, #1
    bl  Write_Latch
    mov r0, #12
    bl  Wait
    mov r0, #0
    bl  Write_Latch

    mov r5, #0
    pulseLoop:      //Loops 16 times, shifts a bit from the SNES controller via clock increment then a read
        mov r0, #6
        bl  Wait
        mov r0, #0
        bl  Write_Clock
        mov r0, #6
        
        bl  Read_Data
        mov r6, r0

        lsl r4, #1
        orr r4, r6

        mov r0, #1
        bl  Write_Clock

        add r5, #1
        cmp r5, #16
        blt   pulseLoop

    mov r0, r4  // return BUTTONS register in r0
    pop    {r4-r6, lr}
    bx     lr

Print_Message: //Processes the register shifted in from controller
            //Only handles one button pressed at once as that is all that is mentioned in assignment
    
    push     {lr}

    ldr r8, =0x7fff
    cmp r9, r8   
    ldreq   r0, =bString
    moveq   r1, #16
	bleq	WriteStringUART      

    ldr r8, =0xbfff
    cmp r9, r8   
    ldreq   r0, =yString
    moveq   r1, #16  
	bleq	WriteStringUART  

    ldr r8, =0xdfff
    cmp r9, r8   
    ldreq   r0, =selectString
    moveq   r1, #21  
	bleq	WriteStringUART  

    ldr r8, =0xefff
    cmp r9, r8   
    ldreq   r0, =startString
    moveq   r1, #39  
	bleq	WriteStringUART 
    beq     haltLoop$

    ldr r8, =0xf7ff
    cmp r9, r8   
    ldreq   r0, =dupString
    moveq   r1, #18
	bleq	WriteStringUART

    ldr r8, =0xfbff
    cmp r9, r8   
    ldreq   r0, =ddownString
    moveq   r1, #20
	bleq	WriteStringUART

    ldr r8, =0xfdff
    cmp r9, r8   
    ldreq   r0, =dleftString
    moveq   r1, #20  
	bleq	WriteStringUART

    ldr r8, =0xfeff
    cmp r9, r8   
    ldreq   r0, =drightString
    moveq   r1, #21  
	bleq	WriteStringUART 

    ldr r8, =0xff7f
    cmp r9, r8   
    ldreq   r0, =aString
    moveq   r1, #16
	bleq	WriteStringUART

    ldr r8, =0xffbf
    cmp r9, r8   
    ldreq   r0, =xString
    moveq   r1, #16
	bleq	WriteStringUART

    ldr r8, =0xffdf
    cmp r9, r8   
    ldreq   r0, =leftString
    moveq   r1, #19
	bleq	WriteStringUART

    ldr r8, =0xffef
    cmp r9, r8   
    ldreq   r0, =rightString
    moveq   r1, #20
	bleq	WriteStringUART



    end:
    pop      {lr}
    bx lr



.section .data 
.align 4

aString:
    .asciz  "\n\rA is pressed\n\r"   //Length 16
bString:
    .asciz  "\n\rB is pressed\n\r"   //Length 16
xString:
    .asciz  "\n\rX is pressed\n\r"   //Length 16
yString:
    .asciz  "\n\rY is pressed\n\r"   //Length 16
leftString:
    .asciz  "\n\rLeft is pressed\n\r"   //Length 19
rightString:
    .asciz  "\n\rRight is pressed\n\r"   //Length 20
startString:
    .asciz  "\n\rStart is pressed, program is ending\n\r"   //Length 39
selectString:
    .asciz  "\n\rSelect is pressed\n\r"   //Length 21
drightString:
    .asciz  "\n\rDRight is pressed\n\r"   //Length 21
dleftString:
    .asciz  "\n\rDLeft is pressed\n\r"   //Length 20
dupString:
    .asciz  "\n\rDUp is pressed\n\r"   //Length 18
ddownString:
    .asciz  "\n\rDDown is pressed\n\r"   //Length 20
creatorName:
	.asciz  "Dylan Temple\n\r" //Length 14

waited:
	.asciz  "\n\rDylan\n\r" //Length 9
pressButton:
    .asciz  "\n\rPlease press a button...\n\r"

ABuff:// here it means preserve a section in to memory of 256 bytes having zero as value
	.rept	256
	.byte	0
	.endr


