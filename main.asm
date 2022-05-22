
	.data
.include	"data.asm"
input:		.asciz "Halo alo"
	.align 2
dummy:		.space  2
header:		.space  14
infoHeader:	.space  40
data:		.space  200000
line:		.space	5000
ofname:		.asciz 	"result.bmp"
.eqv height		64
.eqv width		4
.eqv silence_width	30
	.text
main:
	jal str_size
	jal calculate_size
	jal create_header
	jal create_line
	jal create_data
	jal open_file
	jal save_file
	jal close_file

main_failure:
	li a7, 10
	ecall

## str size and control sum
# t2 - control sum
# returns str size in t3
# t3 - current size of string (needed for mul)
# t0 - address of char
# t1 - char val
# t3, t2 - TAKEN (str size & control sum)

str_size:
	xor t2, t2, t2
	addi t2, t2, 104 # code B
	la t0, input
str_loop:
	lb t1, (t0)
	beqz t1, str_end_loop
	addi t0, t0, 1
	addi t3, t3, 1
	addi t1, t1, -32 # ascii -> code128 val
	mul t1, t1, t3
	add t2, t2, t1
	j str_loop
str_end_loop:
	la t1, input
	li t0, 103
	rem t2, t2, t0
str_clear:
	xor t0, t0, t0
	jr ra

# Open File
open_file:
	li a7, 1024
	li a1, 1
	la a0, ofname
	ecall
	blt a0, zero, wb_error
	mv t1, a0
	jr ra

# Save File
save_file:
	li a7, 64
	la a1, header
	li s0, height
	mul s0, t6, s0  # Data SIZE = size of line * height
	addi a2, s0, 54 # File SIZE = Data SIZE + 54
	ecall
	jr ra

# Close File
close_file:
	li a7, 57
	mv a0, t1
  	ecall
  	jr ra

# ERROR
wb_error:
	li a0, 2 # error writing file
	jr ra


# Calculate size of file
# t4 - chars in row * 11 + 35 (bits in line)
# t5 - pixels in row multiplied by width of pixel
# t6 - size of line (in bytes)
calculate_size:
	li s0, 11
	mul t4, t3, s0
	addi t4, t4, 35 # Added Start code size and STOP size and Control size
	li s0, width
	mul t5, t4, s0
	li s0, silence_width
	add t4, t4, s0 # Added Silence Zone size (start)
	add t4, t4, s0 # Added Silence Zone size (end)
	add t5, t5, s0
	add t5, t5, s0
	
	add t6, t5, t5
	add t6, t6, t5 # pixels in row * 3 (RGB)
	addi t6, t6, 3
	srai t6, t6, 2
	slli t6, t6, 2
	jr ra
	

# Create Header
# t0 - processor
# t1 - address
# s0 - size of data
create_header:
	la t1, header
	li t0, 0x4d42 # BMP Format
	sh t0, (t1)
	li s0, height
	mul s0, t6, s0  # Data SIZE = size of line * height
	addi t0, s0, 54 # File SIZE = Data SIZE + 54
	sw t0, 2(t1)
	li t0, 0x00000036
	sw t0, 10(t1)
	
	la t1, infoHeader
	li t0, 0x00000028
	sw t0, (t1)
	sw t5, 4(t1) # pixels in row
	li t0, height
	sw t0, 8(t1) # height
	li t0, 0x00180001
	sw t0, 12(t1) # colors and bits per pixel
	sw s0, 20(t1) # size of data
	jr ra
# Create line
# t0 - address in line
# t1 - address in string
create_line:
	la t0, line
    # silence zone (Start)
	li s0, silence_width
    silence_loop:
	li s1, 0xFF
    	sb s1, (t0)
    	sb s1, 1(t0)
   	sb s1, 2(t0)
    	addi t0, t0, 3
    	addi s0, s0, -1
    	bnez s0, silence_loop
    
    # start code B
	li s0, 0x400 # mask
    start_loop:
    	li s4, width # s4 - width counter
      start_width_loop:
    	li s1, 136
    	jal s10, write_pixel
    	addi t0, t0, 3
    	addi s4, s4, -1
    	bnez s4, start_width_loop
    	
    	srli s0, s0, 1
    	bnez s0, start_loop
    
    # String
    	la t1, input
    	mv s3, t3 # str size left
  string_loop:
	li s0, 0x400 # mask
    char_loop:
    	li s4, width
      char_width_loop:
    	lb s1, (t1)
    	jal s10, write_pixel
    	addi t0, t0, 3
    	addi s4, s4, -1
    	bnez s4, char_width_loop
    		
    	srli s0, s0, 1
    	bnez s0, char_loop
    	
    	addi s3, s3 -1
    	addi t1, t1, 1
    	bnez s3, string_loop
    
    # Control code
	li s0, 0x400 # mask
    control_loop:
    	li s4, width
      control_width_loop:
    	addi s1, t2, 32
    	jal s10, write_pixel
    	addi t0, t0, 3
    	addi s4, s4, -1
    	bnez s4, control_width_loop
	
    	srli s0, s0, 1
    	bnez s0, control_loop
    
    # Stop code
	li s0, 0x1000 # mask
    stop_loop:
    	li s4, width
      stop_width_loop:
    	li s1, 138 # STOP
    	jal s10, write_pixel
    	addi t0, t0, 3
    	addi s4, s4, -1
    	bnez s4, stop_width_loop
    	
    	srli s0, s0, 1
    	bnez s0, stop_loop

    # silence zone (End)
	li s0, silence_width
    silence2_loop:
	li s1, 0xFF
    	sb s1, (t0)
    	sb s1, 1(t0)
   	sb s1, 2(t0)
    	addi t0, t0, 3
    	addi s0, s0, -1
    	bnez s0, silence2_loop
    	
	jr ra
# Create Data
# t0 - address in line
# t1 - address in data
create_data:
	la t1, data
	li s1, height
  height_loop:
	la t0, line
	mv s0, t6
    line_loop:
    	lb s2, (t0) # get byte from line
    	sb s2, (t1) # save byte to data
    	addi t0, t0, 1
    	addi t1, t1, 1
    	addi s0, s0, -1
    	bnez s0, line_loop
    	
    	addi s1, s1, -1
    	bnez s1, height_loop

    	jr ra

# writes pixel checking on s1 char and s0 mask
write_pixel:
    	addi s1, s1, -32
	la s2, array_of_codes
	slli s1, s1, 2
	add s1, s2, s1
	lw s1, (s1) # load value from array of codes
    	and s1, s1, s0
	beqz s1, write_white
	li s1, 0x00
    	sb s1, (t0)
    	sb s1, 1(t0)
   	sb s1, 2(t0)
	jr s10
    write_white:
	li s1, 0xFF
    	sb s1, (t0)
    	sb s1, 1(t0)
   	sb s1, 2(t0)
	jr s10
	
	
	
	
