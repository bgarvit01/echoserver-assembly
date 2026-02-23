; Echo Server in x86_64 Assembly (Linux)
; Assembler: NASM
; 
; Features:
; - TCP socket server
; - HTTP/1.1 request handling
; - JSON response with server_hosting_port and server_unique_id
; - Configurable port via command line
;
; Build: nasm -f elf64 echoserver.asm -o echoserver.o
;        ld echoserver.o -o echoserver
; Run:   ./echoserver [port]  (default: 8080)

section .data
    ; Socket constants
    AF_INET         equ 2
    SOCK_STREAM     equ 1
    SOL_SOCKET      equ 1
    SO_REUSEADDR    equ 2
    
    ; Syscall numbers (x86_64 Linux)
    SYS_READ        equ 0
    SYS_WRITE       equ 1
    SYS_CLOSE       equ 3
    SYS_SOCKET      equ 41
    SYS_ACCEPT      equ 43
    SYS_BIND        equ 49
    SYS_LISTEN      equ 50
    SYS_SETSOCKOPT  equ 54
    SYS_EXIT        equ 60
    SYS_GETPID      equ 39
    SYS_TIME        equ 201
    
    ; HTTP Response template
    http_response_start db 'HTTP/1.1 200 OK', 13, 10
                        db 'Content-Type: application/json', 13, 10
                        db 'Server: echoserver-asm', 13, 10
                        db 'Connection: close', 13, 10
                        db 13, 10
    http_response_start_len equ $ - http_response_start
    
    ; JSON response parts
    json_start      db '{"server_hosting_port":'
    json_start_len  equ $ - json_start
    
    json_mid        db ',"server_unique_id":"asm-'
    json_mid_len    equ $ - json_mid
    
    json_host_start db '","host":{"hostname":"asm-echoserver"},"http":{"method":"'
    json_host_start_len equ $ - json_host_start
    
    json_end        db '"}}'
    json_end_len    equ $ - json_end
    
    ; Default port
    default_port    dw 8080
    
    ; Messages
    msg_listening   db 'Echo Server (Assembly) listening on port '
    msg_listening_len equ $ - msg_listening
    
    msg_newline     db 10
    msg_newline_len equ 1
    
    ; Reuse address option value
    optval          dd 1

section .bss
    ; Socket structures
    sockaddr_in     resb 16         ; struct sockaddr_in
    client_addr     resb 16         ; client address
    client_addr_len resd 1          ; client address length
    
    ; Buffers
    request_buf     resb 4096       ; HTTP request buffer
    response_buf    resb 4096       ; HTTP response buffer
    port_str        resb 8          ; Port string buffer
    uuid_buf        resb 32         ; UUID buffer
    method_buf      resb 16         ; HTTP method buffer
    
    ; File descriptors
    server_fd       resd 1
    client_fd       resd 1
    
    ; Port number
    port_num        resw 1
    
    ; Unique ID components
    pid_value       resq 1
    time_value      resq 1

section .text
    global _start

_start:
    ; Parse command line arguments for port
    ; argc is at [rsp], argv[0] at [rsp+8], argv[1] at [rsp+16]
    mov rax, [rsp]              ; argc
    cmp rax, 2
    jl .use_default_port
    
    ; Parse port from argv[1]
    mov rdi, [rsp + 16]         ; argv[1]
    call parse_port
    mov [port_num], ax
    jmp .port_set
    
.use_default_port:
    mov ax, [default_port]
    mov [port_num], ax
    
.port_set:
    ; Generate unique ID from PID and time
    call generate_unique_id
    
    ; Create socket
    mov rax, SYS_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    
    test rax, rax
    js .exit_error
    mov [server_fd], eax
    
    ; Set SO_REUSEADDR
    mov rax, SYS_SETSOCKOPT
    mov edi, [server_fd]
    mov rsi, SOL_SOCKET
    mov rdx, SO_REUSEADDR
    lea r10, [optval]
    mov r8, 4
    syscall
    
    ; Setup sockaddr_in structure
    mov word [sockaddr_in], AF_INET     ; sin_family
    
    ; Convert port to network byte order (big endian)
    mov ax, [port_num]
    xchg al, ah                         ; swap bytes for network order
    mov word [sockaddr_in + 2], ax      ; sin_port
    
    mov dword [sockaddr_in + 4], 0      ; sin_addr = INADDR_ANY
    
    ; Bind socket
    mov rax, SYS_BIND
    mov edi, [server_fd]
    lea rsi, [sockaddr_in]
    mov rdx, 16
    syscall
    
    test rax, rax
    js .exit_error
    
    ; Listen
    mov rax, SYS_LISTEN
    mov edi, [server_fd]
    mov rsi, 128                        ; backlog
    syscall
    
    test rax, rax
    js .exit_error
    
    ; Print listening message
    mov rax, SYS_WRITE
    mov rdi, 1                          ; stdout
    lea rsi, [msg_listening]
    mov rdx, msg_listening_len
    syscall
    
    ; Print port number
    movzx rdi, word [port_num]
    lea rsi, [port_str]
    call int_to_str
    
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [port_str]
    mov rdx, rax                        ; length returned from int_to_str
    syscall
    
    ; Print newline
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [msg_newline]
    mov rdx, msg_newline_len
    syscall

.accept_loop:
    ; Accept connection
    mov dword [client_addr_len], 16
    mov rax, SYS_ACCEPT
    mov edi, [server_fd]
    lea rsi, [client_addr]
    lea rdx, [client_addr_len]
    syscall
    
    test rax, rax
    js .accept_loop                     ; retry on error
    mov [client_fd], eax
    
    ; Read request
    mov rax, SYS_READ
    mov edi, [client_fd]
    lea rsi, [request_buf]
    mov rdx, 4095
    syscall
    
    test rax, rax
    jle .close_client
    
    ; Extract HTTP method from request
    lea rdi, [request_buf]
    lea rsi, [method_buf]
    call extract_method
    
    ; Build and send response
    call build_response
    
    ; Send response
    mov rax, SYS_WRITE
    mov edi, [client_fd]
    lea rsi, [response_buf]
    ; rdx already has response length from build_response
    syscall
    
.close_client:
    ; Close client socket
    mov rax, SYS_CLOSE
    mov edi, [client_fd]
    syscall
    
    jmp .accept_loop

.exit_error:
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

; Generate unique ID from PID and timestamp
generate_unique_id:
    push rbx
    
    ; Get PID
    mov rax, SYS_GETPID
    syscall
    mov [pid_value], rax
    
    ; Get time
    mov rax, SYS_TIME
    xor rdi, rdi
    syscall
    mov [time_value], rax
    
    ; Convert to hex string in uuid_buf
    lea rdi, [uuid_buf]
    mov rax, [pid_value]
    call qword_to_hex
    mov byte [rdi], '-'
    inc rdi
    mov rax, [time_value]
    call qword_to_hex
    mov byte [rdi], 0
    
    pop rbx
    ret

; Convert qword in RAX to hex string at RDI
; Advances RDI past the string
qword_to_hex:
    push rbx
    push rcx
    
    mov rcx, 16                         ; 16 hex digits
    add rdi, 15                         ; start from end
    
.hex_loop:
    mov rbx, rax
    and rbx, 0xF
    cmp bl, 10
    jl .digit
    add bl, 'a' - 10
    jmp .store
.digit:
    add bl, '0'
.store:
    mov [rdi], bl
    shr rax, 4
    dec rdi
    dec rcx
    jnz .hex_loop
    
    add rdi, 17                         ; move past string
    
    pop rcx
    pop rbx
    ret

; Parse port number from string at RDI
; Returns port in AX
parse_port:
    xor rax, rax
    xor rcx, rcx
    
.parse_loop:
    movzx rcx, byte [rdi]
    test cl, cl
    jz .parse_done
    
    cmp cl, '0'
    jl .parse_done
    cmp cl, '9'
    jg .parse_done
    
    imul rax, 10
    sub cl, '0'
    add rax, rcx
    inc rdi
    jmp .parse_loop
    
.parse_done:
    ret

; Convert integer in RDI to string at RSI
; Returns string length in RAX
int_to_str:
    push rbx
    push rcx
    push rdx
    
    mov rax, rdi
    lea rbx, [rsi + 7]                  ; end of buffer
    mov rcx, rbx
    mov byte [rbx], 0
    
.convert_loop:
    dec rbx
    xor rdx, rdx
    mov rdi, 10
    div rdi
    add dl, '0'
    mov [rbx], dl
    test rax, rax
    jnz .convert_loop
    
    ; Move string to start of buffer
    mov rdi, rsi
.copy_loop:
    mov al, [rbx]
    mov [rdi], al
    inc rbx
    inc rdi
    cmp rbx, rcx
    jle .copy_loop
    
    ; Calculate length
    mov rax, rdi
    sub rax, rsi
    dec rax
    
    pop rdx
    pop rcx
    pop rbx
    ret

; Extract HTTP method from request at RDI into buffer at RSI
extract_method:
    push rcx
    mov rcx, 0
    
.method_loop:
    mov al, [rdi + rcx]
    cmp al, ' '
    je .method_done
    cmp al, 0
    je .method_done
    cmp rcx, 15
    jge .method_done
    mov [rsi + rcx], al
    inc rcx
    jmp .method_loop
    
.method_done:
    mov byte [rsi + rcx], 0
    pop rcx
    ret

; Build HTTP response in response_buf
; Returns length in RDX
build_response:
    push rbx
    push rcx
    
    lea rdi, [response_buf]
    
    ; Copy HTTP headers
    lea rsi, [http_response_start]
    mov rcx, http_response_start_len
    rep movsb
    
    ; JSON start
    lea rsi, [json_start]
    mov rcx, json_start_len
    rep movsb
    
    ; Port number
    push rdi
    movzx rdi, word [port_num]
    mov rsi, rsp
    sub rsp, 16
    mov rbx, rsp
    call int_to_str_inline
    mov rcx, rax
    add rsp, 16
    pop rdi
    
    ; Copy port string
    lea rsi, [port_str]
    movzx rax, word [port_num]
    push rdi
    mov rdi, rax
    lea rsi, [port_str]
    call int_to_str
    mov rcx, rax
    pop rdi
    lea rsi, [port_str]
    rep movsb
    
    ; JSON middle
    lea rsi, [json_mid]
    mov rcx, json_mid_len
    rep movsb
    
    ; UUID
    lea rsi, [uuid_buf]
.copy_uuid:
    lodsb
    test al, al
    jz .uuid_done
    stosb
    jmp .copy_uuid
.uuid_done:
    
    ; Host/method start
    lea rsi, [json_host_start]
    mov rcx, json_host_start_len
    rep movsb
    
    ; Method
    lea rsi, [method_buf]
.copy_method:
    lodsb
    test al, al
    jz .method_done2
    stosb
    jmp .copy_method
.method_done2:
    
    ; JSON end
    lea rsi, [json_end]
    mov rcx, json_end_len
    rep movsb
    
    ; Calculate length
    lea rdx, [response_buf]
    sub rdi, rdx
    mov rdx, rdi
    
    pop rcx
    pop rbx
    ret

; Inline int to string (helper)
int_to_str_inline:
    push rbx
    mov rax, rdi
    lea rbx, [port_str + 7]
    mov byte [rbx], 0
    
.conv_loop:
    dec rbx
    xor rdx, rdx
    mov rcx, 10
    div rcx
    add dl, '0'
    mov [rbx], dl
    test rax, rax
    jnz .conv_loop
    
    ; Calculate length
    lea rax, [port_str + 7]
    sub rax, rbx
    
    ; Move to start
    lea rdi, [port_str]
.move_loop:
    mov cl, [rbx]
    mov [rdi], cl
    inc rbx
    inc rdi
    test cl, cl
    jnz .move_loop
    
    lea rax, [port_str + 7]
    lea rbx, [port_str]
    sub rax, rbx
    dec rax
    
    pop rbx
    ret
