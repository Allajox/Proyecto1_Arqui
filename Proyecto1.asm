section .data
    prompt db "Ingrese la expresion: ", 0
    result_msg db "Resultado: ", 0
    newline db 10, 0
    var_x dq 0
    var_y dq 0
    var_z dq 0

section .bss
    input resb 1024
    buffer resb 32
    expression resb 512
    assignments resb 512

section .text
    global _start

_start:
    ; Mostrar prompt
    mov rsi, prompt
    call print_str

    ; Leer entrada
    mov rax, 0
    mov rdi, 0
    mov rsi, input
    mov rdx, 1024
    syscall

    ; Eliminar newline final
    mov rcx, rax
    dec rcx
    cmp byte [input + rcx], 10
    jne .no_newline
    mov byte [input + rcx], 0
.no_newline:

    ; Separar expresión y asignaciones
    call split_expression_and_assignments

    ; Procesar asignaciones
    mov rdi, assignments
    call parse_assignments

    ; Evaluar expresión
    mov rdi, expression
    call evaluate_expression

    ; Convertir resultado a string
    mov rdi, buffer
    call itoa

    ; Mostrar resultado
    mov rsi, result_msg
    call print_str
    mov rsi, buffer
    call print_str
    mov rsi, newline
    call print_str

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

split_expression_and_assignments:
    mov rdi, input
    mov al, ','
    call find_char
    test rax, rax
    jz .no_assignments

    ; Separar expresión y asignaciones
    mov rbx, rax         ; Guardar dirección de primera coma
    mov byte [rbx], 0    ; Reemplazar coma con terminador nulo

    ; Copiar expresión
    mov rsi, input
    mov rdi, expression
    call copy_string

    ; Copiar asignaciones desde rbx+1
    lea rsi, [rbx + 1]
    call skip_spaces
    mov rdi, assignments
    call copy_string
    ret

.no_assignments:
    mov rsi, input
    mov rdi, expression
    call copy_string
    mov byte [assignments], 0
    ret

copy_string:
.loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .loop
    ret

parse_assignments:
    push rbp
    mov rbp, rsp

    mov rbx, rdi

.next:
    call skip_spaces
    cmp byte [rbx], 0
    je .done

    mov rdi, rbx
    call parse_assignment

    call skip_spaces
    mov rbx, rdi
    cmp byte [rbx], ','
    jne .done
    inc rbx
    jmp .next

.done:
    pop rbp
    ret

parse_assignment:
    push rbp
    mov rbp, rsp
    push rbx

    call skip_spaces
    movzx ebx, byte [rdi]
    inc rdi

    call skip_spaces
    cmp byte [rdi], '='
    jne .error
    inc rdi
    call skip_spaces

    call parse_number

    cmp bl, 'x'
    je .set_x
    cmp bl, 'y'
    je .set_y
    cmp bl, 'z'
    je .set_z

.error:
    jmp .done

.set_x:
    mov [var_x], rax
    jmp .done
.set_y:
    mov [var_y], rax
    jmp .done
.set_z:
    mov [var_z], rax

.done:
    pop rbx
    pop rbp
    ret

evaluate_expression:
    push rbp
    mov rbp, rsp
    sub rsp, 8
    mov qword [rbp-8], 0
    mov rcx, 1

.next_term:
    call skip_spaces
    cmp byte [rdi], 0
    je .end

    call evaluate_term
    imul rax, rcx
    add [rbp-8], rax

    call skip_spaces
    movzx eax, byte [rdi]
    cmp al, '+'
    je .plus
    cmp al, '-'
    je .minus
    jmp .end

.plus:
    mov rcx, 1
    inc rdi
    jmp .next_term

.minus:
    mov rcx, -1
    inc rdi
    jmp .next_term

.end:
    mov rax, [rbp-8]
    add rsp, 8
    pop rbp
    ret

evaluate_term:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    call parse_exponent
    mov [rbp-8], rax

.loop:
    call skip_spaces

    movzx eax, byte [rdi]

    ; Verificar multiplicación implícita
    cmp al, 'x'
    je .implicit_mult
    cmp al, 'y'
    je .implicit_mult
    cmp al, 'z'
    je .implicit_mult
    cmp al, '('
    je .implicit_mult

    cmp al, '*'
    je .multiply
    cmp al, '/'
    je .divide
    cmp al, '%'
    je .modulo       ; <-- NUEVO CASO MODULO

    jmp .end

.implicit_mult:
    call parse_exponent
    mov rbx, [rbp-8]
    imul rax, rbx
    mov [rbp-8], rax
    jmp .loop

.multiply:
    inc rdi
    call parse_exponent
    mov rbx, [rbp-8]
    imul rax, rbx
    mov [rbp-8], rax
    jmp .loop

.divide:
    inc rdi
    call parse_exponent
    mov rbx, rax
    mov rax, [rbp-8]
    cqo
    idiv rbx
    mov [rbp-8], rax
    jmp .loop

.modulo:            ; <-- Aquí se implementa la operación módulo
    inc rdi
    call parse_exponent
    mov rbx, rax          ; divisor
    mov rax, [rbp-8]      ; dividendo
    cqo
    idiv rbx
    mov rax, rdx          ; residuo es el resultado del módulo
    mov [rbp-8], rax
    jmp .loop

.end:
    mov rax, [rbp-8]
    add rsp, 16
    pop rbp
    ret

; ********** FUNCIÓN CORREGIDA DE EXPONENTE **********
parse_exponent:
    push rbp
    mov rbp, rsp
    push rbx       ; preservar rbx
    sub rsp, 8

    call parse_factor
    mov [rbp-16], rax  ; guardar base

.check_pow:
    call skip_spaces
    cmp byte [rdi], '*'
    jne .done
    cmp byte [rdi + 1], '*'
    jne .done

    add rdi, 2         ; saltar '**'
    call parse_exponent
    mov rcx, rax       ; exponente
    mov rax, [rbp-16]  ; base

    mov rbx, rax       ; base en rbx
    mov rax, 1         ; resultado inicial

    test rcx, rcx
    jz .done           ; si exponente = 0, resultado = 1

.pow_loop:
    imul rax, rbx
    dec rcx
    jnz .pow_loop

.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret
; ********** FIN FUNCIÓN CORREGIDA **********

parse_factor:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    call skip_spaces
    movzx eax, byte [rdi]

    cmp al, '('
    je .paren_expr

    cmp al, '0'
    jl .check_var
    cmp al, '9'
    jg .check_var

    call parse_number
    mov [rbp-8], rax
    jmp .check_var_after_number

.paren_expr:
    inc rdi
    call evaluate_expression
    call skip_spaces
    cmp byte [rdi], ')'
    jne .done
    inc rdi
    jmp .done

.check_var_after_number:
    call skip_spaces
    movzx eax, byte [rdi]
    cmp al, 'x'
    je .var_mult
    cmp al, 'y'
    je .var_mult
    cmp al, 'z'
    je .var_mult
    jmp .number_done

.var_mult:
    call parse_factor
    imul rax, [rbp-8]
    jmp .done

.number_done:
    mov rax, [rbp-8]
    jmp .done

.check_var:
    cmp al, 'x'
    je .get_var
    cmp al, 'y'
    je .get_var
    cmp al, 'z'
    je .get_var
    xor rax, rax
    jmp .done

.get_var:
    movzx eax, byte [rdi]
    inc rdi
    cmp al, 'x'
    je .x
    cmp al, 'y'
    je .y
    cmp al, 'z'
    je .z

.x: mov rax, [var_x]
    jmp .done
.y: mov rax, [var_y]
    jmp .done
.z: mov rax, [var_z]

.done:
    add rsp, 16
    pop rbp
    ret

parse_number:
    push rbp
    mov rbp, rsp
    xor rax, rax

.next_digit:
    movzx edx, byte [rdi]
    cmp dl, '0'
    jl .end
    cmp dl, '9'
    jg .end
    imul rax, 10
    sub dl, '0'
    add rax, rdx
    inc rdi
    jmp .next_digit
.end:
    pop rbp
    ret

skip_spaces:
.loop:
    cmp byte [rdi], ' '
    jne .done
    inc rdi
    jmp .loop
.done:
    ret

find_char:
    mov rcx, -1
.loop:
    inc rcx
    cmp byte [rdi + rcx], al
    je .found
    cmp byte [rdi + rcx], 0
    jne .loop
    xor rax, rax
    ret
.found:
    lea rax, [rdi + rcx]
    ret

print_str:
    push rbp
    mov rbp, rsp
    mov rdx, 0
.count:
    cmp byte [rsi + rdx], 0
    je .print
    inc rdx
    jmp .count
.print:
    mov rax, 1
    mov rdi, 1
    syscall
    pop rbp
    ret

itoa:
    push rbp
    mov rbp, rsp
    push rbx

    test rax, rax
    jns .positive
    neg rax
    mov byte [rdi], '-'
    inc rdi
.positive:
    mov rbx, rdi
    lea rdi, [rbx + 31]
    mov byte [rdi], 0
    mov rcx, 10

.convert_loop:
    dec rdi
    xor rdx, rdx
    div rcx
    add dl, '0'
    mov [rdi], dl
    test rax, rax
    jnz .convert_loop

    mov rsi, rdi
    mov rdi, rbx
.copy_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .copy_loop

    pop rbx
    pop rbp
    ret
