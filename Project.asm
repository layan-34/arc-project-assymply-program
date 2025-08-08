.data
    # Buffers and storage
    filename:    .space 256       # User input filename
    outputfilename: .asciiz "/Users/Dell/Desktop/arc/output.txt"  # Output filename
    filebuffer:  .space 4096      # File content storage
    filehandle:  .word 0          # File descriptor
    floatArray:  .float 0:100     # Array for parsed floats (max 100)
    arraySize:   .word 0          # Count of parsed numbers
    tempBuffer:  .space 32        # Temp space for number parsing
    isLoaded:    .word 0          # 0 = not loaded, 1 = loaded
    binCount:    .word 0          # Store number of bins used
    .align 2                      # Ensure proper alignment for word data

    # UI strings
    promptFilename: .asciiz "Enter filename: "
    errorOpen:      .asciiz "File open failed\n"
    errorRead:      .asciiz "File read failed\n"
    successRead:    .asciiz "File loaded successfully\n"
    printHeader:    .asciiz "\nParsed numbers between 0 and 1:\n"
    printItem:      .asciiz "Item "
    printColon:     .asciiz ": "
    newline:        .asciiz "\n"
    errorInvalidNum:.asciiz "Error: Invalid number found (must be between 0 and 1).\n"
    errorTooManyItems:.asciiz "Error: Exceeded maximum of 100 items.\n"
    errorEmptyFile: .asciiz "Error: Input file is empty.\n"
    menu:           .asciiz "\n==== Bin Packing Problem ====\nSelect Heuristic:\n[F] First Fit\n[B] Best Fit\n[Q] Quit\nYour choice: "
    invalidMsg:     .asciiz "\nInvalid choice! Please enter F, B, or Q.\n"

    # Bin packing strings
    Item:        .asciiz "\nInput items: "
    result:      .asciiz "The output is: "
    outputmsg:   .asciiz "\nNumber of bins used: "
    bin:         .asciiz "Bin "
    sum:         .asciiz "sum of size for each bins: "
    colon:       .asciiz ": "
    comma:       .asciiz ", "
    errormsg:    .asciiz "Error: Exceeded maximum of 20 bins.\n"
    errormsg2:   .asciiz "Error: Bin is full (max 50 items).\n"
    
    # Constants for float conversion and bin packing
    float_zero:     .float 0.0
    float_one_tenth:.float 0.1
    float_ten:      .float 10.0
    float_one:      .float 1.0
    max:            .float 2.0        # Large number for comparison
    floatepsilon:   .float 0.000001   # Small value for floating-point comparison
    bin_str: .space 8000

    # Allocate space for bins (20 bins � 204 bytes each = 4080 bytes)
    # Each bin contains:
    # size (4 byte float)
    # items (50 items � 4 bytes each = 200 bytes)
    bins:   .space 4080

.text
.globl main

main:
    # Initialize stack pointer if not done by simulator
    la $sp, 0x7fffeffc  # Typical MIPS stack pointer initialization

#-------------------------------------------------------------------------------------------------------    
#                           read file and store in the buffer 
#-------------------------------------------------------------------------------------------------------    
     # Get filename from user
    li $v0, 4
    la $a0, promptFilename
    syscall
    
    li $v0, 8  
    la $a0, filename     # Load the address of the buffer 'filename' into $a0 � where the input will be stored
    li $a1, 256          # Load 256 into $a1 � the maximum number of characters to read( common buffer size)
    syscall           

    # Clean newline and carriage return from input
    # When the user types a filename and presses Enter, the input string includes(\n,\r)
    la $a0, filename
    jal remove_newline
    
    # Reset isLoaded flag when loading new file
    li $t0, 0
    sw $t0, isLoaded
    
    # Open file
    li $v0, 13
    la $a0, filename
    li $a1, 0             # $a1 = file open mode (0 = read only)
    li $a2, 0             # $a2 = file permission mode (ignored for reading)
    syscall
    
    move $t0, $v0
    sw $t0, filehandle
    bltz $v0, open_error   # If $v0 < 0, jump to the 'open_error' label
    
    
   # Read file content
    li $v0, 14
    move $a0, $t0
    la $a1, filebuffer   # Set $a1 to the address of the buffer ('filebuffer') where the file contents will be stored
    li $a2, 4096         # Set $a2 to the maximum number of bytes to read (4096 bytes)
    syscall
    
    bltz $v0, read_error   # If $v0 < 0, jump to the 'read_error' label
    move $s1, $v0    # Save bytes read
    
    # Close file
    li $v0, 16
    move $a0, $t0
    syscall

#-------------------------------------------------------------------------------------------------------    
#                     move data from buffer to the array
#-------------------------------------------------------------------------------------------------------   
# Parse numbers from buffer
    la $a0, filebuffer
    la $a1, floatArray
    # This tells the parsing function how much data it has to process
      
    move $a2, $s1    # Pass buffer size
    jal parse_numbers
    # The function 'parse_numbers' returns the number of floats successfully parsed in $v0.
   
    # Store that value in memory at 'arraySize'
    sw $v0, arraySize
    
    # Check if array is empty
    lw $t0, arraySize
    bnez $t0, not_empty # If $t0 != 0, jump to 'not_empty' label
    la $a0, errorEmptyFile
    li $v0, 4
    syscall
    j program_exit

#------------------------------------------------------------------------
#                print array content 
#------------------------------------------------------------------------
not_empty:
    # Print success message after validation
    li $v0, 4
    la $a0, successRead
    syscall
    
    # Print results
    li $v0, 4
    la $a0, printHeader
    syscall
    
    jal print_numbers
    
    # Ensure the program terminates properly
    j menu_loop

#------------------------------------------------------------------------
#                  functions for reading data and store it
#------------------------------------------------------------------------

# Remove trailing newline and carriage return from string
remove_newline:
    move $t8, $a0    # Save the original pointer in $t8, so it can be restored later
loop:
    lb $t1, ($a0)
    beq $t1, 10, replace  # Check for newline (ASCII 10)
    beq $t1, 13, replace  # Check for carriage return (ASCII 13)
    beqz $t1, end_remove
    addi $a0, $a0, 1
    j loop
    
replace:
    sb $zero, ($a0)
end_remove:
    move $a0, $t8    # Restore the original pointer
    jr $ra
#-----------------------------------------------------------------------------

# Parse floats from buffer to array with validation
parse_numbers:
    # Save registers that will be modified
    addi $sp, $sp, -12         # stack pointer to make space for saved registers
    sw $ra, 8($sp)             # Save return address 
    sw $s0, 4($sp)             # Save register $s0 (buffer pointer)
    sw $s1, 0($sp)             # Save register $s1 (array pointer)

    move $s0, $a0        # Buffer pointer 
    move $s1, $a1        # Array pointer 
    li $t2, 0            # Initialize item count ($t2 = 0)
    add $t9, $s0, $a2    # end of buffer address: $t9 = $s0 + buffer size

parse_loop:
    # Skip whitespace(spaces, newlines, etc.
skip_ws:
    lb $t3, ($s0)
    beqz $t3, parse_done      # If it's null byte (end of string)
    bge $s0, $t9, parse_done  # If buffer pointer exceeds end of buffer, stop parsing
    ble $t3, 32, skip_char    # If character is whitespace (ASCII <= 32), skip it
    j parse_num               # If not whitespace, start parsing number

skip_char:
    addi $s0, $s0, 1 
    j skip_ws
        
    # Parse number string
parse_num:
    la $t5, tempBuffer
copy_char:
    lb $t3, ($s0)
    beqz $t3, end_num         # End of string
    bge $s0, $t9, end_num     # End of buffer
    ble $t3, 32, end_num      # Stop at whitespace
    sb $t3, ($t5)             # Store the character in tempBuffer
    addi $t5, $t5, 1          # Move to the next position in tempBuffer
    addi $s0, $s0, 1          # Move to the next byte in buffer
    j copy_char
    
end_num:
    sb $zero, ($t5)           # Null-terminate
            
    # Convert to float
    la $a0, tempBuffer
    jal atof
    
    # Validate the float is between 0 and 1
    l.s $f1, float_zero
    c.lt.s $f0, $f1          # Check if < 0
    bc1t invalid_num_error   # If $f0 < 0.0, jump to invalid_num_error
    l.s $f1, float_one
    c.le.s $f0, $f1          # Check if <= 1.0
    bc1f invalid_num_error   # If $f0 > 1.0, jump to invalid_num_error
    
    # Check array size limit
    li $t4, 100              # max size 100 to prevents buffer overflows
    bge $t2, $t4, array_full_error
    
    # Store float in array (guaranteed to be aligned)
    s.s $f0, ($s1)            # Store in array
    addi $s1, $s1, 4          # Move to next array position
    addi $t2, $t2, 1          # Increment item count
    
    j parse_loop

parse_done:
    move $v0, $t2             # Return item count
    # Restore registers
   # Restore registers
    lw $s1, 0($sp)            # Restore the array pointer from stack
    lw $s0, 4($sp)            # Restore the buffer pointer from stack
    lw $ra, 8($sp)            # Restore return address from stack
    addi $sp, $sp, 12         # Reset stack pointer 
 jr $ra

invalid_num_error:
    la $a0, errorInvalidNum
    li $v0, 4
    syscall
    j program_exit

array_full_error:
    la $a0, errorTooManyItems
    li $v0, 4
    syscall
    j program_exit
#--------------------------------------------------------------

# ASCII-to-float conversion (simplified)
atof:
#save return address and input string pointer
    addi $sp, $sp, -8 
    sw $ra, 4($sp)
    sw $a0, 0($sp)
    
    l.s $f0, float_zero          # Initialize result
    
     # Load constants: 10.0 into $f8 (used for multiplication) and 0.1 into $f4 (used for decimal place adjustments)
    l.s $f8, float_ten           # 10.0
    l.s $f4, float_one_tenth     # 0.1
    
    li $t1, 0                    # Decimal flag=0
    move $t0, $a0                # copy String pointer
    
atof_loop:
    lb $t3, ($t0)            
    beqz $t3, atof_done   #if null
    beq $t3, '.', set_decimal 
    
    sub $t3, $t3, '0'         # Convert ASCII character to integer     
    bltz $t3, atof_done       # If result is negative, stop
    bgt $t3, 9, atof_done     # if more than highest valid digit 
   
    mtc1 $t3, $f6             # Move int into a floating-point register $f6    
    cvt.s.w $f6, $f6          # convert int-->float
      
    beqz $t1, process_int     # If decimal flag is 0, we're processing the integer part
    mul.s $f6, $f6, $f4       # If decimal flag is set, scale the digit by 0.1
    add.s $f0, $f0, $f6       # Add the scaled value to the result
    div.s $f4, $f4, $f8       # Reduce $f4 (0.1) for the next decimal place
    j next_char
  
process_int:
    mul.s $f0, $f0, $f8       # Multiply the result by 10 to shift the place value
    add.s $f0, $f0, $f6       # Add the current digit (float) to the result
    j next_char               # Jump to next character
    
set_decimal:
    li $t1, 1                
    j next_char
    
next_char:
    addi $t0, $t0, 1         
    j atof_loop
        
atof_done:
    # Restore registers
    lw $a0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

print_numbers:
    # Save registers
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    
    lw $s0, arraySize
    la $s1, floatArray
    li $t1, 0                # Counter (0-based)
    beqz $s0, exit_print     
    
print_loop:
    bge $t1, $s0, exit_print   # If counter exceeds array size, exit the loop
    # Print index (1-based)
    li $v0, 4
    la $a0, printItem
    syscall
    li $v0, 1
    addi $a0, $t1, 1         # Convert to 1-based index
    syscall
    li $v0, 4
    la $a0, printColon
    syscall
    # Print float
    li $v0, 2
    l.s $f12, ($s1)
    syscall
    li $v0, 4
    la $a0, newline
    syscall
    addi $s1, $s1, 4
    addi $t1, $t1, 1
    j print_loop
    
exit_print:
    # Restore registers
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# Error handlers
open_error:
    la $a0, errorOpen
    j display_error
    j program_exit
    
read_error:
    la $a0, errorRead
    lw $t0, filehandle
    li $v0, 16       # Close file
    move $a0, $t0
    syscall
    la $a0, errorRead
display_error:
    li $v0, 4
    syscall
    j program_exit
    
# Function to clear bins
clear_bins:
    la $t0, bins         # Start address of bins array
    li $t1, 4080         # Size of bins array (20 bins � 204 bytes)
    add $t1, $t0, $t1    # End address
    
clear_loop:
    sw $zero, ($t0)      # Clear 4 bytes at a time
    addi $t0, $t0, 4     # Next word
    blt $t0, $t1, clear_loop  # Continue until end
    jr $ra               # Return

#------------------------------------------------------------------------
#                                          menu
#------------------------------------------------------------------------

menu_loop:
    li $v0, 4                  # syscall: print string
    la $a0, menu               # load address of menu text
    syscall

    li $v0, 12                 # syscall: read character
    syscall
    move $t0, $v0              # store user input in $t0

    # Convert to uppercase if lowercase
    blt $t0, 97, check_choice  # if less than 'a' skip conversion
    bgt $t0, 122, check_choice # if greater than 'z' skip conversion
    sub $t0, $t0, 32           # convert lowercase to uppercase

check_choice:
    li $t1, 'F'                # ASCII value for 'F'
    beq $t0, $t1, handle_FF

    li $t1, 'B'                # ASCII value for 'B'
    beq $t0, $t1, handle_BF

    li $t1, 'Q'                # ASCII value for 'Q'
    beq $t0, $t1, program_exit

    # Invalid input
    li $v0, 4
    la $a0, invalidMsg
    syscall
    j menu_loop                # return to menu

#------------------------------------------------------------------------
#                         FF
#------------------------------------------------------------------------
handle_FF:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Clear bins before processing
    jal clear_bins
    
    # Initialize registers
    la $s0, floatArray     # Array address
    lw $s1, arraySize      # Array size
    la $s2, bins           # Bins array
    li $s3, 0              # Bin count

    li $t0, 0              # Item index (0-based)

loop_FF:
    bge $t0, $s1, finished_FF
    
    # Load current item
    mul $t1, $t0, 4
    add $t2, $s0, $t1
    l.s $f1, ($t2)         # $f1 = item size
    
    # Find first bin that fits
    li $t3, -1             # Best bin index (-1 = none)
    li $t4, 0              # Bin counter

find_bin_FF:
    bge $t4, $s3, found_FF
    
    # Get bin info
    mul $t5, $t4, 408      # Bin offset
    add $t6, $s2, $t5      # Bin address
    l.s $f3, ($t6)         # Bin size
    l.s $f4, float_one    
    sub.s $f5, $f4, $f3    # Remaining capacity
    
    # Check if item fits
    l.s $f6, floatepsilon
    add.s $f7, $f5, $f6
    c.le.s $f1, $f7
    bc1t select_bin_FF
    j next_bin_search_FF

select_bin_FF:
    move $t3, $t4          # Select this bin
    j found_FF

next_bin_search_FF:
    addi $t4, $t4, 1
    j find_bin_FF

found_FF:
    # Place item in bin or create new
    bgez $t3, add_bin_FF
    
    # Create new bin if allowed
    li $t7, 20             
    bge $s3, $t7, error_FF 
    move $t3, $s3          # New bin index
    addi $s3, $s3, 1       # bin_count++

add_bin_FF:
    # Check bin item limit
    mul $t5, $t3, 408
    add $t6, $s2, $t5      # Current bin address
    lw $t7, 4($t6)         # Item count
    
    # Calculate position for new item
    mul $t8, $t7, 4        # 4 bytes per item index
    add $t9, $t6, 8        # Start of items array
    add $t9, $t9, $t8      # Position for new item
    
    # Store 1-based item index
    addi $t8, $t0, 1       # Convert to 1-based
    sw $t8, ($t9)          # Store item index
    
    # Update bin size and count
    l.s $f3, ($t6)
    add.s $f3, $f3, $f1    
    s.s $f3, ($t6)         
    lw $t7, 4($t6)
    addi $t7, $t7, 1
    sw $t7, 4($t6)

    addi $t0, $t0, 1
    j loop_FF

finished_FF:
    # Print results
    li $v0, 4
    la $a0, outputmsg
    syscall
    
    li $v0, 1
    move $a0, $s3
    syscall
    
    li $v0, 4
    la $a0, newline
    syscall
    la $a0, result
    syscall
    la $a0, newline
    syscall

    # Print bins
    li $t0, 0              # Bin index
print_bins_FF:
    bge $t0, $s3, write_to_file_FF
    
    # Print bin header
    la $a0, bin
    li $v0, 4
    syscall
    
    addi $a0, $t0, 1       # 1-based bin number
    li $v0, 1
    syscall
    
    la $a0, colon
    li $v0, 4
    syscall

    # Get bin items
    mul $t1, $t0, 408
    add $t2, $s2, $t1
    lw $t3, 4($t2)         # Item count
    addi $t4, $t2, 8       # Items array
    
    li $t5, 0              # Item counter
print_items_FF:
    bge $t5, $t3, next_bin_print_FF
    
    # Print item
    la $a0, printItem
    li $v0, 4
    syscall
    
    lw $a0, ($t4)          # Item number (1-based)
    li $v0, 1
    syscall
    
    addi $t5, $t5, 1
    addi $t4, $t4, 4
    
    # Print comma if more items
    blt $t5, $t3, print_comma_FF
    j print_items_FF
    
print_comma_FF:
    la $a0, comma
    li $v0, 4
    syscall
    j print_items_FF
    
next_bin_print_FF:
    la $a0, newline
    li $v0, 4
    syscall
    addi $t0, $t0, 1
    j print_bins_FF



write_to_file_FF:
    # Open file for writing
    li $v0, 13
    la $a0, outputfilename
    li $a1, 1              # Write mode
    li $a2, 0
    syscall
    bltz $v0, exit_FF      # If failed to open, exit
    move $s4, $v0          # Save file descriptor

    # Write header
    li $v0, 15
    move $a0, $s4
    la $a1, result
    li $a2, 14             # Length of "The output is:"
    syscall
    
    # Write newline after header
    li $v0, 15
    move $a0, $s4
    la $a1, newline
    li $a2, 1
    syscall

    # Write each bin's contents
    li $t0, 0              # Bin counter
write_bins_loop_FF:
    bge $t0, $s3, close_file_FF
    
    # Write "Bin X: "
    li $v0, 15
    move $a0, $s4
    la $a1, bin
    li $a2, 4              # "Bin "
    syscall

    # Write bin number (1-based)
    addi $t1, $t0, 1
    move $a0, $s4
    la $a1, tempBuffer
    move $a2, $t1
    jal int_to_string
    move $a2, $v0          # Length of number string
    li $v0, 15
    syscall

    # Write ": "
    li $v0, 15
    move $a0, $s4
    la $a1, colon
    li $a2, 2
    syscall

    # Get bin info
    mul $t2, $t0, 408
    add $t3, $s2, $t2
    lw $t4, 4($t3)         # Item count
    addi $t5, $t3, 8       # Items array

    # Write each item
    li $t6, 0              # Item counter
write_items_loop_FF:
    bge $t6, $t4, next_bin_write_FF

    # Write "Item "
    li $v0, 15
    move $a0, $s4
    la $a1, printItem
    li $a2, 5              # "Item "
    syscall

    # Write item number (1-based)
    lw $t7, ($t5)          # Item index
    move $a0, $s4
    la $a1, tempBuffer
    move $a2, $t7
    jal int_to_string
    move $a2, $v0          # Length of number string
    li $v0, 15
    syscall

    # Write comma if not last item
    addi $t8, $t4, -1
    blt $t6, $t8, write_comma_FF

    j next_item_write_FF

write_comma_FF:
    la $a0, comma
    li $v0, 15
    move $a0, $s4
    la $a1, comma
    li $a2, 2              # ", "
    syscall

next_item_write_FF:
    addi $t6, $t6, 1
    addi $t5, $t5, 4
    j write_items_loop_FF

next_bin_write_FF:
    # Write newline
    li $v0, 15
    move $a0, $s4
    la $a1, newline
    li $a2, 1
    syscall

    addi $t0, $t0, 1
    j write_bins_loop_FF


    # Print bin sizes
    li $v0, 4
    la $a0, sum
    syscall
    
    li $t0, 0
print_sizes_loop_FF:
    bge $t0, $s3, exit_FF
    
    mul $t1, $t0, 408
    add $t2, $s2, $t1
    l.s $f12, ($t2)
    li $v0, 2
    syscall
    
    addi $t0, $t0, 1
    addi $t3, $s3, -1
    blt $t0, $t3, print_size_comma_FF
    j print_sizes_loop_FF
    
print_size_comma_FF:
    la $a0, comma
    li $v0, 4
    syscall
    j print_sizes_loop_FF

error_FF:
    la $a0, errormsg
    li $v0, 4
    syscall

close_file_FF:
    # Close the file
    li $v0, 16
    move $a0, $s4
    syscall
    
exit_FF:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j menu_loop
    
  
#------------------------------------------------------------------------
#                     BF 
#------------------------------------------------------------------------
handle_BF:
    # Initialize registers with important addresses/values
    la $s0, floatArray     # $s0 = address of Array (now using floatArray from file)
    lw $s1, arraySize      # $s1 = size (now using arraySize from file)
    la $s2, bins           # $s2 = address of bins
    li $s3, 0              # $s3 = bin count initial 0
    la $s5, bin_str  # $s5 = address of bin items strings
    
    # Clear bins before processing
    jal clear_bins


    # print item
    #li $v0, 4
    #la $a0, Item
    #syscall
    
    # Print the array contents
    #jal print_numbers

    # Best Fit Bin set 
    li $t0, 0              # $t0 = index for current item 

loop_BF:
    bge $t0, $s1, done     # If t0 >= Size, exit loop
    
    # Load current item from Array
    mul $t1, $t0, 4        # Calculate byte offset (t0 × 4)
    add $t2, $s0, $t1      # $t2 = address of Array[t0] after adding the offset
    l.s $f1, ($t2)         # $f1 = Array[t0] 
    
    # Find the best bin for the current item
    li $t3, -1             # $t3 = best bin index and -1 mean no bins found (first item)
    l.s $f2, max           # $f2 = smallest remaining capacity (initially large = 2)
    
    li $t4, 0              # $t4 = bin counter 
find_bin:
    bge $t4, $s3, found    # If t4 >= bin_count, exit find loop
    
    # Get current bins info
    mul $t5, $t4, 408      # Calculate byte offset for bin[j] 
    add $t6, $s2, $t5      # $t6 = address of bin[j]
    l.s $f3, ($t6)         # $f3 = bin[j].size
    l.s $f4, float_one    
    sub.s $f5, $f4, $f3    # $f5 = remaining capacity (1.0 - bin[j].size)
    
    # Check if item fits in bin[j] 
    l.s $f6, floatepsilon
    add.s $f7, $f5, $f6    # $f7 = remaining capacity + epsilon
    c.le.s $f1, $f7        # Compare item size <= remaining capacity + epsilon
    bc1f next_bin          # If doesn't fit, skip to next bin
    
    # Check if this bin is a better fit than current best
    c.lt.s $f5, $f2        # Compare remaining capacity < current best remaining
    bc1t update_best       # If true, update best bin
    j next_bin             # Else, skip to next bin

update_best:
    mov.s $f2, $f5         # Update smallest remaining capacity
    move $t3, $t4          # Update best bin index
    
next_bin:
    addi $t4, $t4, 1       # j++
    j find_bin             # Continue searching
    
found:
    # After searching all bins, decide where to place item
    bgez $t3, add_bin      # If best bin index >= 0, add to existing bin
    
    # Else, create new bin (if we haven't exceeded 20 bins)
    li $t7, 20             
    bge $s3, $t7, error    # If bin_count >= 20, error
    move $t3, $s3          # New bin index = current bin_count
    addi $s3, $s3, 1       # bin_count++

add_bin:
    # Check if bin is full (50 items max)
    mul $t5, $t3, 408       # Calculate byte offset for bin[$t3]
    add $t6, $s2, $t5       # $t6 = address of bin[$t3]
    lw $t7, 4($t6)          # Load item count
    li $t8, 50
    bge $t7, $t8, full      # If item_count >= 50, error

    # Update bin size 
    l.s $f3, ($t6)          # Load current bin size
    add.s $f3, $f3, $f1     # Add item size to bin size
    s.s $f3, ($t6)          # Store updated bin size

    # Add item index to bin's item list
    mul $t8, $t7, 4         # Calculate byte offset for new item (4 bytes per index)
    add $t9, $t6, 8         # $t9 = start of items array (offset 8)
    add $t9, $t9, $t8       # $t9 = address for new item
    sw $t0, ($t9)           # Store item index in bin

    # Create string "item X" in bin_items_str array
    # Calculate position in bin_items_str: (bin_index * 50 + item_index) * 8
    mul $t8, $t3, 50        # bin_index * 50 items per bin
    add $t8, $t8, $t7       # + item_index
    mul $t8, $t8, 8         # * 8 bytes per string
    add $t9, $s5, $t8       # $t9 = address for string
    
# Store "item " - modified to handle alignment
    la $t1, printItem            # Load address of "item " string
    lb $t2, 0($t1)          # Load byte 0 ('i')
    sb $t2, 0($t9)          # Store in string array
    lb $t2, 1($t1)          # Load byte 1 ('t')
    sb $t2, 1($t9)          # Store in string array
    lb $t2, 2($t1)          # Load byte 2 ('e')
    sb $t2, 2($t9)          # Store in string array
    lb $t2, 3($t1)          # Load byte 3 ('m')
    sb $t2, 3($t9)          # Store in string array
    lb $t2, 4($t1)          # Load byte 4 (' ')
    sb $t2, 4($t9)          # Store in string array
    lb $t2, 5($t1)          # Load byte 5 (null terminator)
    sb $t2, 5($t9)          # Store in string array
    
    # Convert item index (t0) to ASCII and append
    addi $t1, $t0, 1        # Convert to 1-based index
    li $t2, 10
    div $t1, $t2
    mflo $t3                # Tens digit
    mfhi $t4                # Ones digit
    
    beqz $t3, single_digit  # Skip if single digit
    
    # Add tens digit
    addi $t3, $t3, 48       # Convert to ASCII
    sb $t3, 6($t9)          # Store after "item "
    
single_digit:
    # Add ones digit
    addi $t4, $t4, 48       # Convert to ASCII
    sb $t4, 7($t9)          # Store after tens digit (or after "item ")
    
    # Null terminate
    sb $zero, 8($t9)        # Ensure null terminator (now at position 8)

    # Update item count 
    addi $t7, $t7, 1        # item_count++
    sw $t7, 4($t6)          # Store updated item count

    addi $t0, $t0, 1        # i++ (go to the next item)
    j loop_BF               # Continue setting

full:
    # Handle full bin error
    la $a0, errormsg2
    li $v0, 4
    syscall
    j exit

error:
    # Print error message if too many bins needed
    la $a0, errormsg
    li $v0, 4
    syscall
    j exit
         
done:
    # Print newline before "Number of bins used"
    li $v0, 4
    la $a0, newline
    syscall
    
    # Print number of bins used
    li $v0, 4
    la $a0, outputmsg
    syscall
    
    li $v0, 1
    move $a0, $s3          # $s3 contains bin count
    syscall
    
    li $v0, 4
    la $a0, newline
    syscall
    
    # Print results header
    li $v0, 4
    la $a0, result
    syscall
    
    # Print newline after "The output of the best fit is:"
    li $v0, 4
    la $a0, newline
    syscall

    # Print detailed bin contents
    li $t0, 0              # $t0 = bin index
print_bins:
    bge $t0, $s3, print_bin_sizes  # If bin index >= bin count, print sizes
    
    # Print bin header (e.g., "Bin 1: ")
    la $a0, bin
    li $v0, 4
    syscall
    
    addi $a0, $t0, 1       # Bin number (starting from 1)
    li $v0, 1
    syscall
    
    la $a0, colon
    li $v0, 4
    syscall

    # Get bin info
    mul $t1, $t0, 408      # Calculate byte offset for bin
    add $t2, $s2, $t1      # $t2 = address of bin
    lw $t3, 4($t2)         # $t3 = item count
    addi $t4, $t2, 8       # $t4 = pointer to items array
    
    li $t5, 0              # $t5 = item index
print_items:
    bge $t5, $t3, next_bin_print  # If item index >= item count, next bin
    
    # Print "Item "
    la $a0, printItem
    li $v0, 4
    syscall
    
    # Print item number (original index + 1)
    lw $a0, 0($t4)         # Load original index
    addi $a0, $a0, 1       # Convert to 1-based
    li $v0, 1
    syscall
    
    addi $t5, $t5, 1       # item index++
    addi $t4, $t4, 4       # move to next item
    blt $t5, $t3, print_comma  # If not last item, print comma
    j print_items
    
print_comma:
    la $a0, comma
    li $v0, 4
    syscall
    j print_items
    
next_bin_print:
    la $a0, newline
    li $v0, 4
    syscall
    addi $t0, $t0, 1       # Move to next bin
    j print_bins

print_bin_sizes:
    # Print bin sizes header
    la $a0, sum
    li $v0, 4
    syscall
    
    li $t0, 0              # $t0 = bin index
print_sizes:
    bge $t0, $s3, write_to_file  # If done with sizes, write to file
    
    # Get bin size
    mul $t1, $t0, 408      # Calculate byte offset for bin
    add $t2, $s2, $t1      # $t2 = address of bin
    l.s $f12, ($t2)        # Load bin size
    
    # Print float
    li $v0, 2
    syscall
    
    # Print comma if not last bin
    addi $t3, $s3, -1
    blt $t0, $t3, print_comma_size
    
    j next_size
    
print_comma_size:
    la $a0, comma
    li $v0, 4
    syscall
    
next_size:
    addi $t0, $t0, 1
    j print_sizes

write_to_file:
    # Open file for writing
    li $v0, 13
    la $a0, outputfilename
    li $a1, 1        # Write mode
    li $a2, 0
    syscall
    bltz $v0, exit   # If failed to open, exit
    move $s4, $v0     # Save file descriptor

    # Write header
    li $v0, 15
    move $a0, $s4
    la $a1, result
    li $a2, 14       # Length of "The output is:"
    syscall
    
    # Write newline after header
    li $v0, 15
    move $a0, $s4
    la $a1, newline
    li $a2, 1
    syscall

    # Write each bin's contents
    li $t0, 0        # Bin counter
write_bins_loop:
    bge $t0, $s3, close_file  # Done all bins

    # Write "Bin X: "
    li $v0, 15
    move $a0, $s4
    la $a1, bin
    li $a2, 4        # "Bin "
    syscall

    # Write bin number (1-based)
    addi $t1, $t0, 1
    move $a0, $s4
    la $a1, tempBuffer
    move $a2, $t1
    jal int_to_string
    move $a2, $v0    # Length of number string
    li $v0, 15
    syscall

    # Write ": "
    li $v0, 15
    move $a0, $s4
    la $a1, colon
    li $a2, 2
    syscall

    # Get bin info
    mul $t2, $t0, 408
    add $t3, $s2, $t2
    lw $t4, 4($t3)    # Item count
    addi $t5, $t3, 8  # Items array

    # Write each item
    li $t6, 0        # Item counter
write_items_loop:
    bge $t6, $t4, next_bin_write

    # Write "Item "
    li $v0, 15
    move $a0, $s4
    la $a1, printItem
    li $a2, 5        # "Item "
    syscall

    # Write item number (1-based)
    lw $t7, 0($t5)   # Original index
    addi $t7, $t7, 1 # 1-based
    move $a0, $s4
    la $a1, tempBuffer
    move $a2, $t7
    jal int_to_string
    move $a2, $v0    # Length of number string
    li $v0, 15
    syscall

    # Write comma if not last item
    addi $t8, $t4, -1
    blt $t6, $t8, write_comma

    j next_item_write

write_comma:
    li $v0, 15
    move $a0, $s4
    la $a1, comma
    li $a2, 2        # ", "
    syscall

next_item_write:
    addi $t6, $t6, 1
    addi $t5, $t5, 4
    j write_items_loop

next_bin_write:
    # Write newline
    li $v0, 15
    move $a0, $s4
    la $a1, newline
    li $a2, 1
    syscall

    addi $t0, $t0, 1
    j write_bins_loop

#------------------------------------------------------------------------

# Helper function to convert int to string
# Input: $a2 = number to convert
#        $a1 = buffer address
# Output: $v0 = string length
int_to_string:
    li $t9, 10
    div $a2, $t9
    mflo $t8        # Tens digit
    mfhi $t7        # Ones digit

    beqz $t8, single_digit1

    # Two-digit number
    addi $t8, $t8, 48
    sb $t8, 0($a1)
    addi $t7, $t7, 48
    sb $t7, 1($a1)
    sb $zero, 2($a1) # Null terminator
    li $v0, 2        # Length 2
    jr $ra

single_digit1:
    # Single-digit number
    addi $t7, $t7, 48
    sb $t7, 0($a1)
    sb $zero, 1($a1) # Null terminator
    li $v0, 1        # Length 1
    jr $ra
    
    
close_file:
    # Close the file
    li $v0, 16
    move $a0, $s4
    syscall

exit:
    j menu_loop

#------------------------------------------------------------------------
# Exit program
program_exit:
    li $v0, 10
    syscall
