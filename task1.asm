; DFA* readDfa(const char* filename)

; static char buf[65536];
;
; DFA* readDfa(const char* filename) {
;     int fd = open(filename, O_RDONLY); // open read only      // syscall 2, flags = 0
;     if (fd < 0) return NULL;
;     long len = read(fd, buf, sizeof(buf) - 1); // syscall 0
;     close(fd);                                 // syscall 3
;     buf[len] = '\0';
;     char* p = buf;
;
;     DFA* d = malloc(sizeof(DFA));              // 32
;
;     // line 1: numStates,numTransitions
;     d->numStates = parseInt(&p);  p++;         // skip ','
;     d->numTransitions = parseInt(&p);
;     skipEol(&p);
;
;     d->states      = malloc(d->numStates * sizeof(State));           // * 8
;     d->transitions = malloc(d->numTransitions * sizeof(Transition)); // * 12
;
;     // line 2: state ids
;     for (int i = 0; i < d->numStates; i++) {
;         d->states[i].id = parseInt(&p);
;         d->states[i].isAccepting = 0;
;         if (*p == ',') p++;
;     }
;     skipEol(&p);
;
;     // line 3: accepting ids (count unknown, may be empty)
;     while (*p >= '0' && *p <= '9') {
;         int id = parseInt(&p);
;         d->states[id].isAccepting = 1;
;         if (*p == ',') p++;
;     }
;     skipEol(&p);
;
;     // transitions: from,to,symbol
;     for (int i = 0; i < d->numTransitions; i++) {
;         d->transitions[i].from   = parseInt(&p);  p++;
;         d->transitions[i].to     = parseInt(&p);  p++;
;         d->transitions[i].symbol = *p;  p++;     // raw char
;         skipEol(&p);
;     }
;
;     d->startState = 0;
;     return d;
; }

global readDfa
extern malloc

BUFSIZE equ 65536

; structs 
struc State
  .id           resd 1      ; offset 0
  .isAccepting  resb 1      ; offset 4
  alignb 4                  ; pad to 8
endstruc                    ; State_size = 8

struc Transition
  .from         resd 1      ; offset 0
  .to           resd 1      ; offset 4
  .symbol       resb 1      ; offset 8
  alignb 4                  ; pad to 12
endstruc                    ; Transition_size = 12

struc DFA
  .states         resq 1    ; offset 0
  .transitions    resq 1    ; offset 8
  .numStates      resd 1    ; offset 16
  .numTransitions resd 1    ; offset 20
  .startState     resd 1    ; offset 24
  alignb 8                  ; pad to 32
endstruc                    ; DFA_size = 32

section .bss
  buf resb BUFSIZE

section .text

; Register plan for readDfa - saved by callee:
;   rbx = DFA* d
;   r12 = cursor p into buf (shared with the helpers below)
;   r13 = loop counter i
;   r14 = &transitions[i]
readDfa:
  push rbp ;push onto stack
  mov rbp, rsp
  push rbx 
  push r12
  push r13
  push r14
  ; entry rsp was 8 mod 16; 5 pushes (40 bytes) -> rsp is now 16-aligned

  ;  open(filename, O_RDONLY)
  mov rax, 2                ; open
                            ; rdi already holds filename
  xor rsi, rsi              ; flags 0 = read-only
  syscall
  cmp rax, 0
  jl .fail                  ; negative = could not open
  mov r12, rax              ; fd (temporarily in r12)

  ;  read(fd, buf, BUFSIZE-1)  
  mov rax, 0                ; read
  mov rdi, r12
  mov rsi, buf
  mov rdx, BUFSIZE - 1
  syscall
  mov r13, rax              ; bytes read

  ;  close(fd)  
  mov rax, 3                ; close
  mov rdi, r12
  syscall

  mov r12, buf              ; p = buf
  mov byte [r12 + r13], 0   ; buf[len] = '\0'

  ;  d = malloc(32)  
  mov rdi, DFA_size
  call malloc
  mov rbx, rax

  ;  line 1  numstates and numtransitions
  call parseInt
  mov [rbx + DFA.numStates], eax
  inc r12                   ; skip ','
  call parseInt
  mov [rbx + DFA.numTransitions], eax
  call skipEol

  ;  allocate the arrays  
  movsxd rdi, dword [rbx + DFA.numStates]
  imul rdi, rdi, State_size
  call malloc
  mov [rbx + DFA.states], rax

  movsxd rdi, dword [rbx + DFA.numTransitions]
  imul rdi, rdi, Transition_size
  call malloc
  mov [rbx + DFA.transitions], rax

  ;  line 2: state ids  
  xor r13, r13              ; i = 0
.stateLoop:
  cmp r13d, [rbx + DFA.numStates]
  jge .stateDone
  call parseInt             ; eax = id
  mov rdx, [rbx + DFA.states]
  imul rcx, r13, State_size ; i * 8
  mov [rdx + rcx + State.id], eax
  mov byte [rdx + rcx + State.isAccepting], 0
  cmp byte [r12], ','
  jne .stateNext
  inc r12
.stateNext:
  inc r13
  jmp .stateLoop
.stateDone:
  call skipEol

  ;  line 3: accepting ids  
.accLoop:
  movzx eax, byte [r12]
  cmp eax, '0'
  jb .accDone               ; not a digit -> end of line
  cmp eax, '9'
  ja .accDone
  call parseInt             ; eax = id (upper rax is zero)
  mov rdx, [rbx + DFA.states]
  imul rcx, rax, State_size
  mov byte [rdx + rcx + State.isAccepting], 1
  cmp byte [r12], ','
  jne .accLoop              ; next pass sees a non-digit and exits
  inc r12
  jmp .accLoop
.accDone:
  call skipEol

  ;  transitions  
  xor r13, r13              ; i = 0
.transLoop:
  cmp r13d, [rbx + DFA.numTransitions]
  jge .transDone
  mov r14, [rbx + DFA.transitions]
  imul rcx, r13, Transition_size  ; i * 12
  add r14, rcx              ; r14 = &transitions[i]

  call parseInt
  mov [r14 + Transition.from], eax
  inc r12                   ; skip ','
  call parseInt
  mov [r14 + Transition.to], eax
  inc r12                   ; skip ','
  mov al, [r12]             ; raw symbol character
  mov [r14 + Transition.symbol], al
  inc r12
  call skipEol

  inc r13
  jmp .transLoop
.transDone:

  mov dword [rbx + DFA.startState], 0
  mov rax, rbx              ; return d
  jmp .return

.fail:
  xor rax, rax              ; return NULL

.return:
  pop r14
  pop r13
  pop r12
  pop rbx
  pop rbp
  ret

; parseInt: reads decimal digits starting at [r12].
;   In:  r12 = cursor
;   Out: eax = value, r12 left ON the first non-digit
;   Uses: rax, rcx only (no calls, so no alignment concerns)
parseInt:
  xor eax, eax
.loop:
  movzx ecx, byte [r12]
  cmp ecx, '0'
  jb .done
  cmp ecx, '9'
  ja .done
  imul eax, eax, 10
  sub ecx, '0'
  add eax, ecx
  inc r12
  jmp .loop
.done:
  ret

; skipEol: skips the '\n' at [r12] if there is one.
;   Conditional because the last line may have no newline
skipEol:
  cmp byte [r12], 10
  jne .done
  inc r12
.done:
  xor rax, rax
  ret
