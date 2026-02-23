// Echo Server in ARM64 Assembly (Linux/macOS)
// Assembler: GNU as (gas)
// 
// Features:
// - TCP socket server
// - HTTP/1.1 request handling
// - JSON response with server_hosting_port and server_unique_id
// - Configurable port via command line
//
// Build (Linux): as -o echoserver_arm64.o echoserver_arm64.asm && ld -o echoserver_arm64 echoserver_arm64.o
// Build (macOS): as -o echoserver_arm64.o echoserver_arm64.asm && ld -o echoserver_arm64 echoserver_arm64.o -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _start -arch arm64

.global _start

// System call numbers (Linux ARM64)
.equ SYS_READ,      63
.equ SYS_WRITE,     64
.equ SYS_CLOSE,     57
.equ SYS_SOCKET,    198
.equ SYS_BIND,      200
.equ SYS_LISTEN,    201
.equ SYS_ACCEPT,    202
.equ SYS_SETSOCKOPT, 208
.equ SYS_EXIT,      93
.equ SYS_GETPID,    172

// Socket constants
.equ AF_INET,       2
.equ SOCK_STREAM,   1
.equ SOL_SOCKET,    1
.equ SO_REUSEADDR,  2

.data
// HTTP Response
http_response:
    .ascii "HTTP/1.1 200 OK\r\n"
    .ascii "Content-Type: application/json\r\n"
    .ascii "Server: echoserver-arm64\r\n"
    .ascii "Connection: close\r\n"
    .ascii "\r\n"
http_response_len = . - http_response

// JSON parts
json_start:
    .ascii "{\"server_hosting_port\":"
json_start_len = . - json_start

json_mid:
    .ascii ",\"server_unique_id\":\"arm64-"
json_mid_len = . - json_mid

json_host:
    .ascii "\",\"host\":{\"hostname\":\"arm64-echoserver\"},\"http\":{\"method\":\""
json_host_len = . - json_host

json_end:
    .ascii "\"}}"
json_end_len = . - json_end

// Messages
msg_listening:
    .ascii "Echo Server (ARM64) listening on port "
msg_listening_len = . - msg_listening

newline:
    .ascii "\n"

// Default port (8080)
default_port:
    .hword 8080

// Option value for setsockopt
optval:
    .word 1

.bss
    .lcomm sockaddr_in, 16
    .lcomm client_addr, 16
    .lcomm client_addr_len, 4
    .lcomm request_buf, 4096
    .lcomm response_buf, 4096
    .lcomm port_str, 16
    .lcomm uuid_buf, 32
    .lcomm method_buf, 16
    .lcomm server_fd, 4
    .lcomm client_fd, 4
    .lcomm port_num, 2
    .lcomm pid_value, 8

.text

_start:
    // Get argc from stack
    ldr x0, [sp]
    cmp x0, #2
    b.lt use_default_port
    
    // Parse port from argv[1]
    ldr x0, [sp, #16]       // argv[1]
    bl parse_port
    adrp x1, port_num
    add x1, x1, :lo12:port_num
    strh w0, [x1]
    b port_set

use_default_port:
    adrp x0, default_port
    add x0, x0, :lo12:default_port
    ldrh w0, [x0]
    adrp x1, port_num
    add x1, x1, :lo12:port_num
    strh w0, [x1]

port_set:
    // Generate unique ID from PID
    bl generate_unique_id
    
    // Create socket: socket(AF_INET, SOCK_STREAM, 0)
    mov x0, #AF_INET
    mov x1, #SOCK_STREAM
    mov x2, #0
    mov x8, #SYS_SOCKET
    svc #0
    
    cmp x0, #0
    b.lt exit_error
    
    adrp x1, server_fd
    add x1, x1, :lo12:server_fd
    str w0, [x1]
    
    // Set SO_REUSEADDR
    ldr w0, [x1]            // server_fd
    mov x1, #SOL_SOCKET
    mov x2, #SO_REUSEADDR
    adrp x3, optval
    add x3, x3, :lo12:optval
    mov x4, #4
    mov x8, #SYS_SETSOCKOPT
    svc #0
    
    // Setup sockaddr_in
    adrp x0, sockaddr_in
    add x0, x0, :lo12:sockaddr_in
    mov w1, #AF_INET
    strh w1, [x0]           // sin_family
    
    // Convert port to network byte order
    adrp x1, port_num
    add x1, x1, :lo12:port_num
    ldrh w2, [x1]
    rev16 w2, w2            // swap bytes for big endian
    strh w2, [x0, #2]       // sin_port
    
    str wzr, [x0, #4]       // sin_addr = INADDR_ANY
    
    // Bind
    adrp x1, server_fd
    add x1, x1, :lo12:server_fd
    ldr w0, [x1]
    adrp x1, sockaddr_in
    add x1, x1, :lo12:sockaddr_in
    mov x2, #16
    mov x8, #SYS_BIND
    svc #0
    
    cmp x0, #0
    b.lt exit_error
    
    // Listen
    adrp x1, server_fd
    add x1, x1, :lo12:server_fd
    ldr w0, [x1]
    mov x1, #128
    mov x8, #SYS_LISTEN
    svc #0
    
    cmp x0, #0
    b.lt exit_error
    
    // Print listening message
    mov x0, #1              // stdout
    adrp x1, msg_listening
    add x1, x1, :lo12:msg_listening
    mov x2, #msg_listening_len
    mov x8, #SYS_WRITE
    svc #0
    
    // Print port number
    adrp x0, port_num
    add x0, x0, :lo12:port_num
    ldrh w0, [x0]
    adrp x1, port_str
    add x1, x1, :lo12:port_str
    bl int_to_str
    mov x2, x0              // length
    mov x0, #1
    adrp x1, port_str
    add x1, x1, :lo12:port_str
    mov x8, #SYS_WRITE
    svc #0
    
    // Print newline
    mov x0, #1
    adrp x1, newline
    add x1, x1, :lo12:newline
    mov x2, #1
    mov x8, #SYS_WRITE
    svc #0

accept_loop:
    // Accept connection
    adrp x0, client_addr_len
    add x0, x0, :lo12:client_addr_len
    mov w1, #16
    str w1, [x0]
    
    adrp x1, server_fd
    add x1, x1, :lo12:server_fd
    ldr w0, [x1]
    adrp x1, client_addr
    add x1, x1, :lo12:client_addr
    adrp x2, client_addr_len
    add x2, x2, :lo12:client_addr_len
    mov x8, #SYS_ACCEPT
    svc #0
    
    cmp x0, #0
    b.lt accept_loop
    
    adrp x1, client_fd
    add x1, x1, :lo12:client_fd
    str w0, [x1]
    
    // Read request
    ldr w0, [x1]
    adrp x1, request_buf
    add x1, x1, :lo12:request_buf
    mov x2, #4095
    mov x8, #SYS_READ
    svc #0
    
    cmp x0, #0
    b.le close_client
    
    // Extract HTTP method
    adrp x0, request_buf
    add x0, x0, :lo12:request_buf
    adrp x1, method_buf
    add x1, x1, :lo12:method_buf
    bl extract_method
    
    // Build response
    bl build_response
    mov x2, x0              // response length
    
    // Send response
    adrp x1, client_fd
    add x1, x1, :lo12:client_fd
    ldr w0, [x1]
    adrp x1, response_buf
    add x1, x1, :lo12:response_buf
    mov x8, #SYS_WRITE
    svc #0

close_client:
    adrp x1, client_fd
    add x1, x1, :lo12:client_fd
    ldr w0, [x1]
    mov x8, #SYS_CLOSE
    svc #0
    
    b accept_loop

exit_error:
    mov x0, #1
    mov x8, #SYS_EXIT
    svc #0

// Generate unique ID from PID
generate_unique_id:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Get PID
    mov x8, #SYS_GETPID
    svc #0
    
    adrp x1, pid_value
    add x1, x1, :lo12:pid_value
    str x0, [x1]
    
    // Convert to string in uuid_buf
    adrp x1, uuid_buf
    add x1, x1, :lo12:uuid_buf
    bl int_to_str
    
    ldp x29, x30, [sp], #16
    ret

// Parse port from string at x0, return in w0
parse_port:
    mov w1, #0              // result
parse_loop:
    ldrb w2, [x0], #1
    cbz w2, parse_done
    cmp w2, #'0'
    b.lt parse_done
    cmp w2, #'9'
    b.gt parse_done
    
    mov w3, #10
    mul w1, w1, w3
    sub w2, w2, #'0'
    add w1, w1, w2
    b parse_loop
    
parse_done:
    mov w0, w1
    ret

// Convert integer in w0 to string at x1, return length in x0
int_to_str:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    
    mov x19, x1             // save buffer pointer
    add x1, x1, #15         // end of buffer
    mov w2, #0
    strb w2, [x1]           // null terminator
    
    mov w3, #10
convert_loop:
    sub x1, x1, #1
    udiv w4, w0, w3
    msub w2, w4, w3, w0     // remainder
    add w2, w2, #'0'
    strb w2, [x1]
    mov w0, w4
    cbnz w0, convert_loop
    
    // Move to start of buffer
    mov x0, x19
copy_loop:
    ldrb w2, [x1], #1
    strb w2, [x0], #1
    cbnz w2, copy_loop
    
    // Calculate length
    sub x0, x0, x19
    sub x0, x0, #1
    
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Extract method from request at x0 into buffer at x1
extract_method:
    mov w2, #0
method_loop:
    ldrb w3, [x0, x2]
    cmp w3, #' '
    b.eq method_done
    cbz w3, method_done
    cmp w2, #15
    b.ge method_done
    strb w3, [x1, x2]
    add w2, w2, #1
    b method_loop
    
method_done:
    strb wzr, [x1, x2]
    ret

// Build HTTP response, return length in x0
build_response:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, response_buf
    add x0, x0, :lo12:response_buf
    mov x9, x0              // save start
    
    // Copy HTTP headers
    adrp x1, http_response
    add x1, x1, :lo12:http_response
    mov x2, #http_response_len
    bl memcpy
    add x0, x0, x2
    
    // JSON start
    adrp x1, json_start
    add x1, x1, :lo12:json_start
    mov x2, #json_start_len
    bl memcpy
    add x0, x0, x2
    
    // Port number
    mov x10, x0             // save position
    adrp x1, port_num
    add x1, x1, :lo12:port_num
    ldrh w0, [x1]
    mov x1, x10
    bl int_to_str
    add x0, x10, x0
    
    // JSON mid
    adrp x1, json_mid
    add x1, x1, :lo12:json_mid
    mov x2, #json_mid_len
    bl memcpy
    add x0, x0, x2
    
    // UUID
    adrp x1, uuid_buf
    add x1, x1, :lo12:uuid_buf
copy_uuid:
    ldrb w2, [x1], #1
    cbz w2, uuid_done
    strb w2, [x0], #1
    b copy_uuid
uuid_done:
    
    // JSON host
    adrp x1, json_host
    add x1, x1, :lo12:json_host
    mov x2, #json_host_len
    bl memcpy
    add x0, x0, x2
    
    // Method
    adrp x1, method_buf
    add x1, x1, :lo12:method_buf
copy_method:
    ldrb w2, [x1], #1
    cbz w2, method_copy_done
    strb w2, [x0], #1
    b copy_method
method_copy_done:
    
    // JSON end
    adrp x1, json_end
    add x1, x1, :lo12:json_end
    mov x2, #json_end_len
    bl memcpy
    add x0, x0, x2
    
    // Calculate length
    sub x0, x0, x9
    
    ldp x29, x30, [sp], #16
    ret

// Simple memcpy: x0=dest, x1=src, x2=len
memcpy:
    cbz x2, memcpy_done
memcpy_loop:
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne memcpy_loop
memcpy_done:
    ret
